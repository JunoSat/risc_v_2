`timescale 1ns/1ps

module id_ex_reg (
    input  wire        clk,
    input  wire        reset,
    
    // Hazard control
    input  wire        stall,
    input  wire        flush,

    // Inputs from ID
    input  wire [31:0] pc_i,
    input  wire [31:0] immediate_i,
    input  wire [31:0] reg_rdata1_i,
    input  wire [31:0] reg_rdata2_i,
    input  wire [4:0]  src1_sel_i,
    input  wire [4:0]  src2_sel_i,
    input  wire [4:0]  dest_reg_sel_i,
    input  wire [2:0]  alu_op_i,

    input  wire        immediate_sel_i,
    input  wire        alu_i,
    input  wire        lui_i,
    input  wire        jal_i,
    input  wire        jalr_i,
    input  wire        branch_i,
    input  wire        mem_write_i,
    input  wire        mem_read_i,
    input  wire        mem_to_reg_i,
    input  wire        arithsubtype_i,
    input  wire        illegal_inst_i,

    // RV32M and CSRs
    input  wire        mult_div_en_i,
    input  wire        is_csr_i,
    input  wire [11:0] csr_addr_i,

    // Outputs to EX
    output reg  [31:0] pc_o,
    output reg  [31:0] immediate_o,
    output reg  [31:0] reg_rdata1_o,
    output reg  [31:0] reg_rdata2_o,
    output reg  [4:0]  src1_sel_o,
    output reg  [4:0]  src2_sel_o,
    output reg  [4:0]  dest_reg_sel_o,
    output reg  [2:0]  alu_op_o,

    output reg         immediate_sel_o,
    output reg         alu_o,
    output reg         lui_o,
    output reg         jal_o,
    output reg         jalr_o,
    output reg         branch_o,
    output reg         mem_write_o,
    output reg         mem_read_o,
    output reg         mem_to_reg_o,
    output reg         arithsubtype_o,
    output reg         illegal_inst_o,

    output reg         mult_div_en_o,
    output reg         is_csr_o,
    output reg  [11:0] csr_addr_o
);

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            pc_o            <= 32'h0;
            immediate_o     <= 32'h0;
            reg_rdata1_o    <= 32'h0;
            reg_rdata2_o    <= 32'h0;
            src1_sel_o      <= 5'h0;
            src2_sel_o      <= 5'h0;
            dest_reg_sel_o  <= 5'h0;
            alu_op_o        <= 3'h0;

            immediate_sel_o <= 1'b0;
            alu_o           <= 1'b0;
            lui_o           <= 1'b0;
            jal_o           <= 1'b0;
            jalr_o          <= 1'b0;
            branch_o        <= 1'b0;
            mem_write_o     <= 1'b0;
            mem_read_o      <= 1'b0;
            mem_to_reg_o    <= 1'b0;
            arithsubtype_o  <= 1'b0;
            illegal_inst_o  <= 1'b0;
            
            mult_div_en_o   <= 1'b0;
            is_csr_o        <= 1'b0;
            csr_addr_o      <= 12'h0;
        end
        else if (flush) begin
            pc_o            <= 32'h0;
            immediate_o     <= 32'h0;
            reg_rdata1_o    <= 32'h0;
            reg_rdata2_o    <= 32'h0;
            src1_sel_o      <= 5'h0;
            src2_sel_o      <= 5'h0;
            dest_reg_sel_o  <= 5'h0;
            alu_op_o        <= 3'h0;

            immediate_sel_o <= 1'b0;
            alu_o           <= 1'b0;
            lui_o           <= 1'b0;
            jal_o           <= 1'b0;
            jalr_o          <= 1'b0;
            branch_o        <= 1'b0;
            mem_write_o     <= 1'b0;
            mem_read_o      <= 1'b0;
            mem_to_reg_o    <= 1'b0;
            arithsubtype_o  <= 1'b0;
            illegal_inst_o  <= 1'b0;
            
            mult_div_en_o   <= 1'b0;
            is_csr_o        <= 1'b0;
            csr_addr_o      <= 12'h0;
        end
        else if (!stall) begin
            pc_o            <= pc_i;
            immediate_o     <= immediate_i;
            reg_rdata1_o    <= reg_rdata1_i;
            reg_rdata2_o    <= reg_rdata2_i;
            src1_sel_o      <= src1_sel_i;
            src2_sel_o      <= src2_sel_i;
            dest_reg_sel_o  <= dest_reg_sel_i;
            alu_op_o        <= alu_op_i;

            immediate_sel_o <= immediate_sel_i;
            alu_o           <= alu_i;
            lui_o           <= lui_i;
            jal_o           <= jal_i;
            jalr_o          <= jalr_i;
            branch_o        <= branch_i;
            mem_write_o     <= mem_write_i;
            mem_read_o      <= mem_read_i;
            mem_to_reg_o    <= mem_to_reg_i;
            arithsubtype_o  <= arithsubtype_i;
            illegal_inst_o  <= illegal_inst_i;
            
            mult_div_en_o   <= mult_div_en_i;
            is_csr_o        <= is_csr_i;
            csr_addr_o      <= csr_addr_i;
        end
    end

endmodule
