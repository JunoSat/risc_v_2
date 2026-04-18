`timescale 1ns / 1ps

module top_fpga #(
	parameter IMEMSIZE = 8192,
	parameter DMEMSIZE = 8192,
	parameter BAUD_RATE = 115200
)(
	input  wire clk,    	// fast board clock (e.g. 100 MHz)
	input  wire reset,  	// active-low reset
	input  wire uart_rx,    // UART Receive line
	output wire uart_tx,    // UART Transmit line
	output [15:0] led       // Diagnostic LEDs
);

	wire [31:0] current_pc;
	wire exception;

    // --- CLOCK DIVIDER TO 50MHz ---
    // Safely resolves the -1.765ns Setup Timing Violation on the long 
    // Is_uart_read_r -> mem_read_data -> FW -> EX -> Branch -> Flush -> Pipeline_CE path.
    reg clk_50 = 0;
    always @(posedge clk or negedge reset) begin
        if (!reset) clk_50 <= 1'b0;
        else clk_50 <= ~clk_50;
    end
    
    wire cpu_clk;
    BUFG bufg_inst (
        .I(clk_50),
        .O(cpu_clk)
    );

	////////////////////////////////////////////////////////////
	// PIPE ↔ MEMORY WIRES
	////////////////////////////////////////////////////////////
	wire [31:0] inst_mem_read_data;
	wire    	inst_mem_is_valid = 1'b1;

	wire [31:0] inst_mem_address;
	wire        inst_mem_is_ready;
	wire [31:0] dmem_read_address;
	wire        dmem_read_ready;
	wire [31:0] dmem_write_address;
	wire        dmem_write_ready;
	wire [31:0] dmem_write_data;
	wire [3:0]  dmem_write_byte;
    wire        dmem_read_valid = 1'b1;
    wire        dmem_write_valid = 1'b1;

	wire [31:0] dmem_read_data_bram;
	wire [31:0] dmem_read_data_pipe;

	////////////////////////////////////////////////////////////
	// MEMORY MAPPED I/O (UART) at 0x8000_0000
	////////////////////////////////////////////////////////////
    // Intercept RAM accesses if address starts with 8 (0x8000...)
    wire is_uart_addr  = (dmem_read_address[31:28] == 4'h8) || (dmem_write_address[31:28] == 4'h8);
    wire uart_we       = is_uart_addr && dmem_write_ready;
    wire uart_re       = is_uart_addr && dmem_read_ready;
    
    // UART hardware wires
    wire [7:0] uart_rx_data;
    wire       uart_rx_ready;
    wire       uart_tx_full;
    
    // Write registers (0x8000_0000 = TX Data transfer)
    wire uart_tx_start = uart_we && (dmem_write_address[7:0] == 8'h00);
    
    // Read registers (0x8000_0004 = RX Data fetch)
    wire uart_rx_ack = (!cpu_reset) ? uart_rx_ready : (uart_re && (dmem_read_address[7:0] == 8'h04));
    
    // Read Multiplexer (Synchronized to exactly match BRAM's 1-cycle latency)
    reg [31:0] uart_read_data_r;
    reg        is_uart_read_r;
    
    always @(posedge cpu_clk) begin
        // Carry the UART-read state into the Write-Back stage cycle
        is_uart_read_r <= uart_re;
        
        // Sample the UART Hardware wires dynamically exactly when a Read is requested
        if (uart_re) begin
            uart_read_data_r <= (dmem_read_address[7:0] == 8'h08) ? {30'b0, uart_rx_ready, uart_tx_full} : 
                                (dmem_read_address[7:0] == 8'h04) ? {24'b0, uart_rx_data} : 32'h0;
        end
    end
    
    // During the pipeline WB stage, output either the safely latched UART data, or native BRAM data.
    assign dmem_read_data_pipe = is_uart_read_r ? uart_read_data_r : dmem_read_data_bram;

    // LED mappings! Top 8 bits = Most recently received character. Bottom 8 bits = Current PC.
    reg [7:0] led_upper;
    always @(posedge clk) begin
        if (uart_rx_ready)
            led_upper <= uart_rx_data;
    end
    assign led = {led_upper, current_pc[7:0]};

	////////////////////////////////////////////////////////////
	// UART CONTROLLER INTERFACING
	////////////////////////////////////////////////////////////
    uart #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(BAUD_RATE)
    ) UART_INST (
        .clk        (cpu_clk),
        .reset      (reset),
        .rx         (uart_rx),
        .tx         (uart_tx),
        .tx_data    (dmem_write_data[7:0]),
        .tx_start   (uart_tx_start),
        .tx_full    (uart_tx_full),
        .rx_data    (uart_rx_data),
        .rx_ready   (uart_rx_ready),
        .rx_ack     (uart_rx_ack)
    );

	////////////////////////////////////////////////////////////
	// HARDWARE BOOTLOADER
	////////////////////////////////////////////////////////////
	wire boot_we;
	wire [31:0] boot_addr;
	wire [31:0] boot_wdata;
	wire cpu_reset;

	bootloader boot_inst (
		.clk(cpu_clk),
		.reset(reset),
		.uart_rx_ready(uart_rx_ready),
		.uart_rx_data(uart_rx_data),
		.cpu_reset(cpu_reset),
		.boot_we(boot_we),
		.boot_addr(boot_addr),
		.boot_wdata(boot_wdata)
	);

	////////////////////////////////////////////////////////////
	// PIPELINE CPU
	////////////////////////////////////////////////////////////
	pipe pipe_u (
		.clk               (cpu_clk), // Now properly running 50MHz to easily clear timing bounds!
		.reset             (cpu_reset),
		.stall             (1'b0),
		.exception         (exception),
		.pc_out            (current_pc), 
		.inst_mem_address  (inst_mem_address),
		.inst_mem_is_valid (inst_mem_is_valid),
		.inst_mem_read_data(inst_mem_read_data),
		.inst_mem_is_ready (inst_mem_is_ready),

		.dmem_read_address (dmem_read_address),
		.dmem_read_ready   (dmem_read_ready),
		// Connect the multiplexed BRAM/UART data bus back into the pipeline
		.dmem_read_data_temp(dmem_read_data_pipe), 
		.dmem_read_valid   (dmem_read_valid),
		.dmem_write_address(dmem_write_address),
		.dmem_write_ready  (dmem_write_ready),
		.dmem_write_data   (dmem_write_data),
		.dmem_write_byte   (dmem_write_byte),
		.dmem_write_valid  (dmem_write_valid)
	);


	////////////////////////////////////////////////////////////
	// INSTRUCTION MEMORY
	////////////////////////////////////////////////////////////
	instr_mem IMEM (
		.clk  (cpu_clk),
		.pc   (inst_mem_address),
		.instr(inst_mem_read_data),
		.boot_we(boot_we),
		.boot_addr(boot_addr),
		.boot_wdata(boot_wdata)
	);


////////////////////////////////////////////////////////////
	// DATA MEMORY
	////////////////////////////////////////////////////////////
	// Fix: Removed boot_we override so bootloader doesn't corrupt DMEM
    wire bram_we = (dmem_write_ready && !is_uart_addr); 
    wire [31:0] bram_waddr = dmem_write_address;
    wire [31:0] bram_wdata = dmem_write_data;
    wire [3:0]  bram_wstrb = dmem_write_byte;

	data_mem DMEM (
		.clk   (cpu_clk),
		.re    (dmem_read_ready && !is_uart_addr), 
		.raddr (dmem_read_address),
		.rdata (dmem_read_data_bram), 
		.we    (bram_we),
		.waddr (bram_waddr),
		.wdata (bram_wdata),
		.wstrb (bram_wstrb)
	);

endmodule
