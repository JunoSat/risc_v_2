`timescale 1ns / 1ps

module tb_pipeline;

////////////////////////////////////////////////////////////
// CLOCK & RESET
////////////////////////////////////////////////////////////
reg clk;
reg reset;

// 100 MHz clock
initial begin
    
	clk = 0;
	forever #10 clk = ~clk;
end

// reset (active low in our CPU)
initial begin
	reset = 0;
	#365;
	reset = 1;
end


////////////////////////////////////////////////////////////
// PIPE ↔ MEMORY SIGNALS
////////////////////////////////////////////////////////////
wire [31:0] inst_mem_read_data;
wire    	inst_mem_is_valid;

wire [31:0] dmem_read_data;
wire    	dmem_write_valid;
wire    	dmem_read_valid;

// FIXED: Added missing wires to connect DUT to memory in testbench
wire [31:0] inst_mem_address;
wire        inst_mem_is_ready;
wire [31:0] dmem_read_address;
wire        dmem_read_ready;
wire [31:0] dmem_write_address;
wire        dmem_write_ready;
wire [31:0] dmem_write_data;
wire [3:0]  dmem_write_byte;
wire [31:0] pc_out;

assign inst_mem_is_valid = 1'b1;
assign dmem_write_valid  = 1'b1;
assign dmem_read_valid   = 1'b1;

wire exception;


////////////////////////////////////////////////////////////
// DUT : PIPELINE CPU
////////////////////////////////////////////////////////////
pipe DUT (
	.clk(clk),
	.reset(reset),
	.stall(1'b0),
	.exception(exception),
	.pc_out(pc_out), // FIXED

	.inst_mem_address(inst_mem_address), // FIXED: Connected port
	.inst_mem_is_valid(inst_mem_is_valid),
	.inst_mem_read_data(inst_mem_read_data),
	.inst_mem_is_ready(inst_mem_is_ready), // FIXED: Connected port

	.dmem_read_address(dmem_read_address), // FIXED: Connected port
	.dmem_read_ready(dmem_read_ready), // FIXED: Connected port
	.dmem_read_data_temp(dmem_read_data),
	.dmem_read_valid(dmem_read_valid),
	.dmem_write_address(dmem_write_address), // FIXED: Connected port
	.dmem_write_ready(dmem_write_ready), // FIXED: Connected port
	.dmem_write_data(dmem_write_data), // FIXED: Connected port
	.dmem_write_byte(dmem_write_byte), // FIXED: Connected port
	.dmem_write_valid(dmem_write_valid)
);


////////////////////////////////////////////////////////////
// INSTRUCTION MEMORY  (matches instr_mem.v)
////////////////////////////////////////////////////////////
instr_mem IMEM (
	.clk(clk),
	.pc(inst_mem_address), // FIXED: Connected inst_mem_address
	.instr(inst_mem_read_data)
);


////////////////////////////////////////////////////////////
// DATA MEMORY  (matches data_mem.v)
////////////////////////////////////////////////////////////
data_mem DMEM (
	.clk(clk),

	.re(dmem_read_ready), // FIXED: Connected dmem_read_ready
	.raddr(dmem_read_address), // FIXED: Connected dmem_read_address
	.rdata(dmem_read_data),

	.we(dmem_write_ready), // FIXED: Connected dmem_write_ready
	.waddr(dmem_write_address), // FIXED: Connected dmem_write_address
	.wdata(dmem_write_data), // FIXED: Connected dmem_write_data
	.wstrb(dmem_write_byte) // FIXED: Connected dmem_write_byte
);


////////////////////////////////////////////////////////////
// SIMULATION LOGGING
////////////////////////////////////////////////////////////
integer f;
reg [31:0] prev_result;
reg [31:0] current_result;
reg [31:0] prev_logged_pc;

initial begin
    f = $fopen("simulation_results.txt", "w");
    if (f == 0) begin
        $display("ERROR: Could not open simulation_results.txt");
    end else begin
        prev_result = 0;
        current_result = 0;
        prev_logged_pc = 32'hFFFFFFFF;

        $fwrite(f, "time:%16d ,result = %8d\n", 0, 0);
    end
end

always @(negedge clk) begin
    if (reset && f != 0) begin
        current_result = DUT.regs[15];

        // Log result
        if (current_result != prev_result) begin
            $fwrite(f, "time:%16t ,result = %8d\n", $time, current_result);
            prev_result = current_result;
        end

        // Log PC
        if (pc_out != prev_logged_pc) begin
            $fwrite(f, "next_pc = %08h\n", pc_out);
            prev_logged_pc = pc_out;
        end

        $fflush(f);
    end
end

////////////////////////////////////////////////////////////
// SIMULATION CONTROL
////////////////////////////////////////////////////////////
always @(negedge clk) begin
    if (inst_mem_read_data == 32'h00008067) begin
        #30;
        if (f != 0) begin
            $fwrite(f, "All instructions are Fetched\n");
            $fwrite(f, "next_pc = 00000000\n");
            $fclose(f);
        end
        $finish;
    end
end

// Fail-safe timeout
initial begin
    #500000;
    $display("TIMEOUT");
    if (f != 0) $fclose(f);
    $finish;
end

// Waveform dump
initial begin
    $dumpfile("./pipeline.vcd");
    $dumpvars(0, tb_pipeline);
end

endmodule
