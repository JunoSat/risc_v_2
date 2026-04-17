`timescale 1ns / 1ps

module fpu(
    input wire clk,
    input wire reset,
    
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [4:0]  funct5, // from Instruction[31:27]
    input wire fp_en,         // 1 if the instruction is an OP-FP instruction
    
    output wire [31:0] result,
    output wire stall_fpu,    // Active HIGH to stall the pipeline
    output wire fpu_exception // Active HIGH for hardware exceptions (Zero division)
);
    
    `include "opcode.vh"
    
    wire add_done, mult_done, div_done, sqrt_done;
    wire [31:0] add_res, mult_res, div_res, sqrt_res;
    wire fpu_div_zero;
    
    reg start_add, start_mult, start_div, start_sqrt, is_sub;
    
    // Tracks if the FPU is currently performing a multi-cycle computation
    reg computing;
    reg [31:0] saved_result;
    reg saved_exception;
    
    reg [31:0] locked_a;
    reg [31:0] locked_b;
    
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            computing <= 0;
            start_add <= 0;
            start_mult <= 0;
            start_div <= 0;
            start_sqrt <= 0;
            is_sub <= 0;
            saved_result <= 0;
            saved_exception <= 0;
            locked_a <= 0;
            locked_b <= 0;
        end else begin
            // Automatically clear start pulses
            start_add <= 0;
            start_mult <= 0;
            start_div <= 0;
            start_sqrt <= 0;
            
            if (fp_en && !computing) begin
                locked_a <= a;
                locked_b <= b;
                if (funct5 == FADD_S) begin
                    start_add <= 1;
                    is_sub <= 0;
                    computing <= 1;
                end else if (funct5 == FSUB_S) begin
                    start_add <= 1;
                    is_sub <= 1;
                    computing <= 1;
                end else if (funct5 == FMUL_S) begin
                    start_mult <= 1;
                    computing <= 1;
                end else if (funct5 == FDIV_S) begin
                    start_div <= 1;
                    computing <= 1;
                end else if (funct5 == FSQRT_S) begin
                    start_sqrt <= 1;
                    computing <= 1;
                end
            end
            
            if (computing) begin
                if (add_done) begin
                    saved_result <= add_res;
                    saved_exception <= 0;
                    computing <= 0;
                end else if (mult_done) begin
                    saved_result <= mult_res;
                    saved_exception <= 0;
                    computing <= 0;
                end else if (div_done) begin
                    saved_result <= div_res;
                    saved_exception <= fpu_div_zero;
                    computing <= 0;
                end else if (sqrt_done) begin
                    saved_result <= sqrt_res;
                    saved_exception <= 0;
                    computing <= 0;
                end
            end
        end
    end
    
    // Combinatorial bypass so the EX stage reads the immediate result EXACTLY on the cycle stall drops.
    assign result = (computing && add_done) ? add_res :
                    (computing && mult_done) ? mult_res :
                    (computing && div_done) ? div_res :
                    (computing && sqrt_done) ? sqrt_res : saved_result;
                    
    assign fpu_exception = (computing && div_done) ? fpu_div_zero : saved_exception;
    
    // stall_fpu logic: 
    // Stall the pipeline when an FP math operation is encountered (fp_en is high and funct5 matches) 
    // and we are either just starting (!computing) or we haven't finished yet (computing but no done signal)
    assign stall_fpu = (fp_en && (funct5 == FADD_S || funct5 == FSUB_S || funct5 == FMUL_S || funct5 == FDIV_S || funct5 == FSQRT_S)) ? 
                       (!computing || (computing && !add_done && !mult_done && !div_done && !sqrt_done)) : 1'b0;

    fpu_add_sub u_add_sub (
        .clk(clk),
        .reset(reset),
        .start(start_add),
        .is_sub(is_sub),
        .a(locked_a),
        .b(locked_b),
        .result(add_res),
        .done(add_done)
    );
    
    fpu_mult u_mult (
        .clk(clk),
        .reset(reset),
        .start(start_mult),
        .a(locked_a),
        .b(locked_b),
        .result(mult_res),
        .done(mult_done)
    );

    fpu_div u_div (
        .clk(clk),
        .reset(reset),
        .start(start_div),
        .a(locked_a),
        .b(locked_b),
        .result(div_res),
        .done(div_done),
        .div_zero_fault(fpu_div_zero)
    );
    
    fpu_sqrt u_sqrt (
        .clk(clk),
        .reset(reset),
        .start(start_sqrt),
        .a(locked_a),
        .result(sqrt_res),
        .done(sqrt_done)
    );

endmodule
