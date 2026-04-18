`timescale 1ns / 1ps

module fpu(
    input wire clk,
    input wire reset,
    
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [4:0]  funct5,
    input wire [2:0]  funct3,
    input wire [4:0]  rs2_sel,
    input wire        fp_en,
    
    output wire [31:0] result,
    output wire        stall_fpu,
    output wire        fpu_exception
);
    `include "opcode.vh"
    
    // --- State Machine ---
    localparam IDLE=0, ALIGN=1, ADD=2, ITERATE=3, NORMALIZE=4, PACK=5;
    reg [2:0] state;
    
    reg [31:0] final_res;
    reg        final_exc;
    reg        computing;

    // --- Shared Pipeline Registers ---
    reg sign_res;
    reg signed [9:0] exp_res;
    reg [47:0] mant_res; // Large enough for 24x24 multiply
    
    // Unpacked inputs
    wire sign_a = a[31];
    wire sign_b = funct5 == FSUB_S ? ~b[31] : b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [24:0] mant_a = (a[30:23] == 0) ? {2'b00, a[22:0]} : {2'b01, a[22:0]};
    wire [24:0] mant_b = (b[30:23] == 0) ? {2'b00, b[22:0]} : {2'b01, b[22:0]};

    // --- Iterative Engine (Div & Sqrt) ---
    reg [51:0] iter_acc;
    reg [25:0] iter_div;
    reg [5:0]  iter_count;
    
    wire [51:0] div_shifted = iter_acc << 1;
    wire [25:0] div_upper   = div_shifted[51:26];
    wire        div_sub_ok  = (div_upper >= iter_div);

    // --- Combinational Fast-Paths (CVT & CMP) ---
    reg [31:0] cvt_cmp_res;
    reg        cvt_cmp_done;
    
    always @(*) begin
        cvt_cmp_res = 32'h0;
        cvt_cmp_done = 1'b0;
        if (fp_en && (funct5 == FCVT_S_W || funct5 == FCMP_S)) begin
            cvt_cmp_done = 1'b1;
            if (funct5 == FCMP_S) begin
                // Simplified FEQ, FLT, FLE (Assumes a, b valid)
                if (funct3 == 3'b010) cvt_cmp_res = {31'b0, (a == b)}; // FEQ
                else if (funct3 == 3'b001) cvt_cmp_res = {31'b0, ($signed(a) < $signed(b))}; // FLT (approximate)
                else cvt_cmp_res = {31'b0, ($signed(a) <= $signed(b))}; // FLE
            end else begin
                // Basic FCVT.S.W bypass (rely on compiler integers for now)
                cvt_cmp_res = a; 
            end
        end
    end

    // --- Main FSM ---
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            computing <= 0;
            final_res <= 0;
            final_exc <= 0;
        end else begin
            case(state)
                IDLE: begin
                    if (fp_en && !computing && !cvt_cmp_done) begin
                        computing <= 1;
                        if (funct5 == FADD_S || funct5 == FSUB_S) begin
                            // Handle Zero shortcut
                            if (a[30:0] == 0) begin final_res <= {sign_b, b[30:0]}; computing <= 0; end
                            else if (b[30:0] == 0) begin final_res <= a; computing <= 0; end
                            else begin
                                exp_res <= exp_a; mant_res <= {23'b0, mant_a}; // Load A
                                iter_div <= mant_b; // Borrow div register for mant_b
                                state <= ALIGN;
                            end
                        end 
                        else if (funct5 == FMUL_S) begin
                            sign_res <= sign_a ^ b[31];
                            exp_res  <= exp_a + exp_b - 127;
                            mant_res <= {1'b1, a[22:0]} * {1'b1, b[22:0]}; // 24x24
                            state <= NORMALIZE;
                        end
                        else if (funct5 == FDIV_S) begin
                            if (b[30:0] == 0) begin final_res <= 32'h7F800000; final_exc <= 1; computing <= 0; end // Div Zero
                            else begin
                                sign_res <= sign_a ^ b[31];
                                exp_res  <= exp_a - exp_b + 127;
                                iter_div <= {2'b0, 1'b1, b[22:0]};
                                iter_acc <= {3'b0, 1'b1, a[22:0], 25'b0};
                                iter_count <= 26;
                                state <= ITERATE;
                            end
                        end
                        // SQRT could be added here following the same ITERATE pattern
                    end
                end
                
                ALIGN: begin
                    // Add/Sub Alignment
                    if (exp_res > exp_b) begin
                        iter_div <= iter_div >> 1; // Shift B
                    end else if (exp_res < exp_b) begin
                        exp_res <= exp_res + 1;
                        mant_res <= mant_res >> 1; // Shift A
                    end else state <= ADD;
                end
                
                ADD: begin
                    if (sign_a == sign_b) begin
                        mant_res <= mant_res[24:0] + iter_div;
                        sign_res <= sign_a;
                    end else begin
                        if (mant_res[24:0] >= iter_div) begin mant_res <= mant_res[24:0] - iter_div; sign_res <= sign_a; end
                        else begin mant_res <= iter_div - mant_res[24:0]; sign_res <= sign_b; end
                    end
                    // Align to 48-bit normalizer format (shift up by 23)
                    mant_res <= mant_res << 23;
                    state <= NORMALIZE;
                end
                
                ITERATE: begin
                    if (iter_count > 0) begin
                        if (div_sub_ok) iter_acc <= { (div_upper - iter_div), div_shifted[25:1], 1'b1 };
                        else iter_acc <= { div_upper, div_shifted[25:1], 1'b0 };
                        iter_count <= iter_count - 1;
                    end else begin
                        mant_res <= {iter_acc[25:0], 22'b0}; // Align to 48-bit normalizer
                        state <= NORMALIZE;
                    end
                end
                
                NORMALIZE: begin
                    // Shared Normalizer for ALL operations
                    if (mant_res[47]) begin
                        mant_res <= mant_res >> 1;
                        exp_res <= exp_res + 1;
                        state <= PACK;
                    end else if (mant_res[46] == 0 && mant_res != 0) begin
                        mant_res <= mant_res << 1;
                        exp_res <= exp_res - 1;
                    end else state <= PACK;
                end
                
                PACK: begin
                    if (mant_res == 0 || $signed(exp_res) <= 0) final_res <= {sign_res, 31'b0};
                    else if (exp_res >= 255) final_res <= {sign_res, 8'hFF, 23'b0};
                    else final_res <= {sign_res, exp_res[7:0], mant_res[45:23]};
                    
                    state <= IDLE;
                    computing <= 0;
                end
            endcase
            
            // Clear start pulses
            if (!computing) final_exc <= 0;
        end
    end

    // --- Output Routing ---
    wire is_multi_cycle = (funct5 == FADD_S || funct5 == FSUB_S || funct5 == FMUL_S || funct5 == FDIV_S || funct5 == FSQRT_S);
    
    assign stall_fpu = (fp_en && is_multi_cycle && computing) || (fp_en && is_multi_cycle && state == IDLE);
    assign result = cvt_cmp_done ? cvt_cmp_res : final_res;
    assign fpu_exception = final_exc;

endmodule