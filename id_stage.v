`timescale 1ns/1ps

module id_stage (
    input  wire [31:0] instruction_i,
    
    output reg  [31:0] immediate,
    output wire        immediate_sel,
    output wire        alu,
    output wire        lui,
    output wire        jal,
    output wire        jalr,
    output wire        branch,
    output wire        mem_write,
    output wire        mem_read,
    output wire        mem_to_reg,
    output wire        arithsubtype,
    output wire [4:0]  src1_sel,
    output wire [4:0]  src2_sel,
    output wire [4:0]  dest_reg_sel,
    output wire [2:0]  alu_op,
    output reg         illegal_inst,
    
    // RV32M and CSR extensions
    output wire        mult_div_en,
    output wire        is_csr,
    output wire [11:0] csr_addr
);

    `include "opcode.vh"

    // Extract fields
    assign src1_sel     = instruction_i[`RS1];
    assign src2_sel     = instruction_i[`RS2];
    assign dest_reg_sel = instruction_i[`RD];
    assign alu_op       = instruction_i[`FUNC3];
    
    wire [6:0] opcode   = instruction_i[`OPCODE];

    // Control signals
    assign immediate_sel = (opcode == JALR) || (opcode == LOAD) || (opcode == ARITHI) || (opcode == SYSTEM);
    assign alu          = (opcode == ARITHI) || (opcode == ARITHR);
    assign lui          = (opcode == LUI);
    assign jal          = (opcode == JAL);
    assign jalr         = (opcode == JALR);
    assign branch       = (opcode == BRANCH);
    assign mem_write    = (opcode == STORE);
    assign mem_read     = (opcode == LOAD);
    assign mem_to_reg   = (opcode == LOAD);
    assign arithsubtype = instruction_i[`SUBTYPE] && !(opcode == ARITHI && alu_op == ADD);

    assign mult_div_en  = (opcode == ARITHR) && (instruction_i[31:25] == 7'b0000001);
    assign is_csr       = (opcode == SYSTEM) && (alu_op != PRIV);
    assign csr_addr     = instruction_i[31:20];

    always @(*) begin
        immediate    = 32'h0;
        illegal_inst = 1'b0;

        case (opcode)
            JALR:   immediate = {{20{instruction_i[31]}}, instruction_i[31:20]};
            BRANCH: immediate = {{20{instruction_i[31]}}, instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
            LOAD:   immediate = {{20{instruction_i[31]}}, instruction_i[31:20]};
            STORE:  immediate = {{20{instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
            ARITHI: immediate = (alu_op == SLL || alu_op == SR) ? {27'b0, instruction_i[24:20]} : {{20{instruction_i[31]}}, instruction_i[31:20]};
            ARITHR: immediate = 32'h0;
            LUI:    immediate = {instruction_i[31:12], 12'b0};
            JAL:    immediate = {{12{instruction_i[31]}}, instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
            SYSTEM: immediate = {27'b0, instruction_i[19:15]}; // zimm for CSRR*I
            default: illegal_inst = 1'b1;
        endcase
    end

endmodule
