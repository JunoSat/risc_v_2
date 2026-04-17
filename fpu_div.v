`timescale 1ns / 1ps

// Multi-cycle IEEE 754 Single-Precision Floating-Point Divider
module fpu_div(
    input wire clk,
    input wire reset,
    
    input wire start,
    input wire [31:0] a,
    input wire [31:0] b,
    
    output reg [31:0] result,
    output reg done,
    output reg div_zero_fault
);

    localparam IDLE=0, DIVIDE=1, NORMALIZE=2, PACK=3;
    reg [1:0] state;

    reg sign_res;
    reg [8:0] exp_res;
    
    reg [51:0] accumulator;
    reg [25:0] divisor;
    reg [5:0] count;
    
    wire [51:0] div_shifted = accumulator << 1;
    wire [25:0] div_upper   = div_shifted[51:26];
    wire        div_sub_ok  = (div_upper >= divisor);
    wire [25:0] div_sub_val = div_upper - divisor;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            div_zero_fault <= 0;
            sign_res <= 0;
            exp_res <= 0;
            accumulator <= 0;
            divisor <= 0;
            count <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    div_zero_fault <= 0;
                    if (start) begin
                        if (b[30:0] == 0) begin // divide by zero
                            div_zero_fault <= 1;
                            result <= {a[31] ^ b[31], 8'hFF, 23'b0};
                            done <= 1;
                        end else if (a[30:0] == 0) begin // zero dividend
                            result <= {a[31] ^ b[31], 31'b0};
                            done <= 1;
                        end else begin
                            sign_res <= a[31] ^ b[31];
                            exp_res  <= a[30:23] - b[30:23] + 127;
                            
                            divisor <= {2'b0, 1'b1, b[22:0]};
                            // shift right by 1, so div_shifted[51:26] equals MantA on first cycle
                            accumulator <= {3'b0, 1'b1, a[22:0], 25'b0};
                            count <= 26;
                            state <= DIVIDE;
                        end
                    end
                end
                
                DIVIDE: begin
                    if (count > 0) begin
                        if (div_sub_ok)
                            accumulator <= { div_sub_val, div_shifted[25:1], 1'b1 };
                        else
                            accumulator <= { div_upper, div_shifted[25:1], 1'b0 };
                        
                        count <= count - 1;
                    end else begin
                        state <= NORMALIZE;
                    end
                end
                
                NORMALIZE: begin
                    // Quotient is in accumulator[25:0]
                    // If >= 1.0, bit 25 is 1. If [0.5, 1.0), bit 24 is 1.
                    if (accumulator[25]) begin
                        // It is 1.xxxxxxxxxxxxxxxxx
                        // We need to pack the lower 23 bits
                        state <= PACK;
                    end else if (accumulator[24]) begin
                        // It is 0.1xxxxxxxxxxxxxxxx
                        accumulator[25:0] <= accumulator[25:0] << 1;
                        exp_res <= exp_res - 1;
                        state <= PACK;
                    end else begin
                        // Should not happen unless dividend is zero, handled in IDLE
                        state <= PACK;
                    end
                end
                
                PACK: begin
                    // accumulator[25] is the implicit 1
                    // accumulator[24:2] are the 23 mantissa bits
                    // accumulator[1:0] are guard/round bits
                    if ($signed(exp_res) <= 0) begin // underflow
                        result <= {sign_res, 31'b0};
                    end else if (exp_res >= 255) begin // overflow
                        result <= {sign_res, 8'hFF, 23'b0};
                    end else begin
                        result <= {sign_res, exp_res[7:0], accumulator[24:2]};
                    end
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
