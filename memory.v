`timescale 1ns / 1ps
module instr_mem (
	input  wire    	clk,
	input  wire [31:0] pc, 	// byte address
	output reg  [31:0] instr,

	// Bootloader write port
	input  wire        boot_we,
	input  wire [31:0] boot_addr,
	input  wire [31:0] boot_wdata
);

	// 2048 words = 8 KB
	// Declare instruction memory array (word-addressable, 8 KB total)
	(* ram_style = "block" *)
	reg [31:0] imem [0:2047];

	// FPGA ROM initialization
	// Initialize instruction memory from hex file (simulation / FPGA)
	initial begin
    	$readmemh("imem.hex", imem);
	end

	// Synchronous instruction fetch
	// Use word-aligned PC (pc[11:2]) to index memory
	always @(posedge clk) begin
    	instr <= imem[pc[12:2]];	// word address
	end

	// Bootloader Write Port
	always @(posedge clk) begin
		if (boot_we) begin
			imem[boot_addr[12:2]] <= boot_wdata;
		end
	end

endmodule



//====================================
// Data Memory (DMEM) - FPGA-safe BRAM
//====================================
module data_mem (
    input       clk,
    input       re,
    input  [31:0] raddr,
    output wire [31:0] rdata, // Changed to wire
    input       we,
    input  [31:0] waddr,
    input  [31:0] wdata,
    input  [3:0]  wstrb
);
    (* ram_style = "block" *)
    reg [31:0] dmem [0:2047];

    wire [10:0] rindex = raddr[12:2];
    wire [10:0] windex = waddr[12:2];

    initial begin
        $readmemh("dmem.hex", dmem);
    end

    reg [31:0] rdata_bram; // Internal sync register

    // Purely Synchronous Block (Guarantees BRAM inference)
    always @(posedge clk) begin
        if (we) begin
            if (wstrb[0]) dmem[windex][7:0]   <= wdata[7:0];
            if (wstrb[1]) dmem[windex][15:8]  <= wdata[15:8];
            if (wstrb[2]) dmem[windex][23:16] <= wdata[23:16];
            if (wstrb[3]) dmem[windex][31:24] <= wdata[31:24];
        end
        if (re) begin
            rdata_bram <= dmem[rindex];
        end
    end

    // Combinational RAW Forwarding (Outside the BRAM block)
    assign rdata[7:0]   = (we && (rindex == windex) && wstrb[0]) ? wdata[7:0]   : rdata_bram[7:0];
    assign rdata[15:8]  = (we && (rindex == windex) && wstrb[1]) ? wdata[15:8]  : rdata_bram[15:8];
    assign rdata[23:16] = (we && (rindex == windex) && wstrb[2]) ? wdata[23:16] : rdata_bram[23:16];
    assign rdata[31:24] = (we && (rindex == windex) && wstrb[3]) ? wdata[31:24] : rdata_bram[31:24];

endmodule
