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

	// Declare bootloader control nets up front so later logic (uart_rx_ack
	// in particular) can reference cpu_reset without triggering a
	// "used-before-declaration" Synth 8-6901 warning.
	wire        cpu_reset;
	wire        boot_we;
	wire [31:0] boot_addr;
	wire [31:0] boot_wdata;

    // --- CLOCK DIVIDER TO 50MHz ---
    // Safely resolves the -1.765ns Setup Timing Violation on the long 
    // Is_uart_read_r -> mem_read_data -> FW -> EX -> Branch -> Flush -> Pipeline_CE path.
    reg clk_50 = 0;
    always @(posedge clk) begin
        clk_50 <= ~clk_50;
    end
    
    assign cpu_clk = clk_50;

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

    wire [31:0] dmem_read_data_pipe;
    wire        axi_dmem_stall;

    // AXI4-Lite Main Bus Wires
    wire [31:0] s_axi_awaddr, s_axi_wdata, s_axi_araddr, s_axi_rdata;
    wire [3:0]  s_axi_wstrb;
    wire [1:0]  s_axi_bresp, s_axi_rresp;
    wire        s_axi_awvalid, s_axi_awready, s_axi_wvalid, s_axi_wready;
    wire        s_axi_bvalid, s_axi_bready, s_axi_arvalid, s_axi_arready;
    wire        s_axi_rvalid, s_axi_rready;

    wire [31:0] m0_axi_awaddr, m0_axi_wdata, m0_axi_araddr, m0_axi_rdata;
    wire [3:0]  m0_axi_wstrb;
    wire [1:0]  m0_axi_bresp, m0_axi_rresp;
    wire        m0_axi_awvalid, m0_axi_awready, m0_axi_wvalid, m0_axi_wready;
    wire        m0_axi_bvalid, m0_axi_bready, m0_axi_arvalid, m0_axi_arready;
    wire        m0_axi_rvalid, m0_axi_rready;

    wire [31:0] m1_axi_awaddr, m1_axi_wdata, m1_axi_araddr, m1_axi_rdata;
    wire [3:0]  m1_axi_wstrb;
    wire [1:0]  m1_axi_bresp, m1_axi_rresp;
    wire        m1_axi_awvalid, m1_axi_awready, m1_axi_wvalid, m1_axi_wready;
    wire        m1_axi_bvalid, m1_axi_bready, m1_axi_arvalid, m1_axi_arready;
    wire        m1_axi_rvalid, m1_axi_rready;

    wire [31:0] m2_axi_awaddr, m2_axi_wdata, m2_axi_araddr, m2_axi_rdata;
    wire [3:0]  m2_axi_wstrb;
    wire [1:0]  m2_axi_bresp, m2_axi_rresp;
    wire        m2_axi_awvalid, m2_axi_awready, m2_axi_wvalid, m2_axi_wready;
    wire        m2_axi_bvalid, m2_axi_bready, m2_axi_arvalid, m2_axi_arready;
    wire        m2_axi_rvalid, m2_axi_rready;

	////////////////////////////////////////////////////////////
	// AXI4-LITE CPU MASTER BRIDGE
	////////////////////////////////////////////////////////////
    axi4_lite_master_bridge cpu_axi_bridge (
        .clk           (cpu_clk),
        .resetn        (cpu_reset), // Active low reset for AXI
        .cpu_raddr     (dmem_read_address),
        .cpu_rreq      (dmem_read_ready),
        .cpu_rdata     (dmem_read_data_pipe),
        .cpu_waddr     (dmem_write_address),
        .cpu_wreq      (dmem_write_ready),
        .cpu_wdata     (dmem_write_data),
        .cpu_wstrb     (dmem_write_byte),
        .cpu_stall     (axi_dmem_stall),
        
        .m_axi_awaddr  (s_axi_awaddr),
        .m_axi_awvalid (s_axi_awvalid),
        .m_axi_awready (s_axi_awready),
        .m_axi_wdata   (s_axi_wdata),
        .m_axi_wstrb   (s_axi_wstrb),
        .m_axi_wvalid  (s_axi_wvalid),
        .m_axi_wready  (s_axi_wready),
        .m_axi_bresp   (s_axi_bresp),
        .m_axi_bvalid  (s_axi_bvalid),
        .m_axi_bready  (s_axi_bready),
        .m_axi_araddr  (s_axi_araddr),
        .m_axi_arvalid (s_axi_arvalid),
        .m_axi_arready (s_axi_arready),
        .m_axi_rdata   (s_axi_rdata),
        .m_axi_rresp   (s_axi_rresp),
        .m_axi_rvalid  (s_axi_rvalid),
        .m_axi_rready  (s_axi_rready)
    );

	////////////////////////////////////////////////////////////
	// AXI4-LITE INTERCONNECT
	////////////////////////////////////////////////////////////
    axi4_lite_interconnect axi_ic (
        .clk           (cpu_clk),
        .resetn        (cpu_reset),
        
        .s_axi_awaddr  (s_axi_awaddr),  .s_axi_awvalid (s_axi_awvalid), .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),   .s_axi_wstrb   (s_axi_wstrb),   .s_axi_wvalid  (s_axi_wvalid),  .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),   .s_axi_bvalid  (s_axi_bvalid),  .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),  .s_axi_arvalid (s_axi_arvalid), .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),   .s_axi_rresp   (s_axi_rresp),   .s_axi_rvalid  (s_axi_rvalid),  .s_axi_rready  (s_axi_rready),

        .m0_axi_awaddr (m0_axi_awaddr), .m0_axi_awvalid(m0_axi_awvalid),.m0_axi_awready(m0_axi_awready),
        .m0_axi_wdata  (m0_axi_wdata),  .m0_axi_wstrb  (m0_axi_wstrb),  .m0_axi_wvalid (m0_axi_wvalid), .m0_axi_wready (m0_axi_wready),
        .m0_axi_bresp  (m0_axi_bresp),  .m0_axi_bvalid (m0_axi_bvalid), .m0_axi_bready (m0_axi_bready),
        .m0_axi_araddr (m0_axi_araddr), .m0_axi_arvalid(m0_axi_arvalid),.m0_axi_arready(m0_axi_arready),
        .m0_axi_rdata  (m0_axi_rdata),  .m0_axi_rresp  (m0_axi_rresp),  .m0_axi_rvalid (m0_axi_rvalid), .m0_axi_rready (m0_axi_rready),

        .m1_axi_awaddr (m1_axi_awaddr), .m1_axi_awvalid(m1_axi_awvalid),.m1_axi_awready(m1_axi_awready),
        .m1_axi_wdata  (m1_axi_wdata),  .m1_axi_wstrb  (m1_axi_wstrb),  .m1_axi_wvalid (m1_axi_wvalid), .m1_axi_wready (m1_axi_wready),
        .m1_axi_bresp  (m1_axi_bresp),  .m1_axi_bvalid (m1_axi_bvalid), .m1_axi_bready (m1_axi_bready),
        .m1_axi_araddr (m1_axi_araddr), .m1_axi_arvalid(m1_axi_arvalid),.m1_axi_arready(m1_axi_arready),
        .m1_axi_rdata  (m1_axi_rdata),  .m1_axi_rresp  (m1_axi_rresp),  .m1_axi_rvalid (m1_axi_rvalid), .m1_axi_rready (m1_axi_rready),

        .m2_axi_awaddr (m2_axi_awaddr), .m2_axi_awvalid(m2_axi_awvalid),.m2_axi_awready(m2_axi_awready),
        .m2_axi_wdata  (m2_axi_wdata),  .m2_axi_wstrb  (m2_axi_wstrb),  .m2_axi_wvalid (m2_axi_wvalid), .m2_axi_wready (m2_axi_wready),
        .m2_axi_bresp  (m2_axi_bresp),  .m2_axi_bvalid (m2_axi_bvalid), .m2_axi_bready (m2_axi_bready),
        .m2_axi_araddr (m2_axi_araddr), .m2_axi_arvalid(m2_axi_arvalid),.m2_axi_arready(m2_axi_arready),
        .m2_axi_rdata  (m2_axi_rdata),  .m2_axi_rresp  (m2_axi_rresp),  .m2_axi_rvalid (m2_axi_rvalid), .m2_axi_rready (m2_axi_rready)
    );

    wire [7:0] uart_rx_data;
    wire       uart_rx_ready;
    
    // LED mappings! Top 8 bits = Most recently received character. Bottom 8 bits = Current PC.
    reg [7:0] led_upper;
    always @(posedge clk) begin
        if (uart_rx_ready)
            led_upper <= uart_rx_data;
    end
    assign led = {led_upper, current_pc[7:0]};

	////////////////////////////////////////////////////////////
	// AXI4-LITE UART SLAVE (M1)
	////////////////////////////////////////////////////////////
    axi4_lite_uart #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(BAUD_RATE)
    ) axi_uart_inst (
        .clk           (cpu_clk),
        .resetn        (reset),   // active low board reset for UART component
        .rx            (uart_rx),
        .tx            (uart_tx),
        .s_axi_awaddr  (m1_axi_awaddr),  .s_axi_awvalid (m1_axi_awvalid), .s_axi_awready (m1_axi_awready),
        .s_axi_wdata   (m1_axi_wdata),   .s_axi_wstrb   (m1_axi_wstrb),   .s_axi_wvalid  (m1_axi_wvalid),  .s_axi_wready  (m1_axi_wready),
        .s_axi_bresp   (m1_axi_bresp),   .s_axi_bvalid  (m1_axi_bvalid),  .s_axi_bready  (m1_axi_bready),
        .s_axi_araddr  (m1_axi_araddr),  .s_axi_arvalid (m1_axi_arvalid), .s_axi_arready (m1_axi_arready),
        .s_axi_rdata   (m1_axi_rdata),   .s_axi_rresp   (m1_axi_rresp),   .s_axi_rvalid  (m1_axi_rvalid),  .s_axi_rready  (m1_axi_rready),
        .rx_data_out   (uart_rx_data),
        .rx_ready_out  (uart_rx_ready)
    );

	////////////////////////////////////////////////////////////
	// AXI4-LITE SYSTOLIC ARRAY SLAVE (M2) 
	////////////////////////////////////////////////////////////
    systolic_array #(
        .DATA_WIDTH(32)
    ) axi_systolic_inst (
        .clk           (cpu_clk),
        .resetn        (cpu_reset),
        .s_axi_awaddr  (m2_axi_awaddr),  .s_axi_awvalid (m2_axi_awvalid), .s_axi_awready (m2_axi_awready),
        .s_axi_wdata   (m2_axi_wdata),   .s_axi_wstrb   (m2_axi_wstrb),   .s_axi_wvalid  (m2_axi_wvalid),  .s_axi_wready  (m2_axi_wready),
        .s_axi_bresp   (m2_axi_bresp),   .s_axi_bvalid  (m2_axi_bvalid),  .s_axi_bready  (m2_axi_bready),
        .s_axi_araddr  (m2_axi_araddr),  .s_axi_arvalid (m2_axi_arvalid), .s_axi_arready (m2_axi_arready),
        .s_axi_rdata   (m2_axi_rdata),   .s_axi_rresp   (m2_axi_rresp),   .s_axi_rvalid  (m2_axi_rvalid),  .s_axi_rready  (m2_axi_rready)
    );

	////////////////////////////////////////////////////////////
	// HARDWARE BOOTLOADER
	////////////////////////////////////////////////////////////
    assign cpu_reset = reset; // active low 
    assign boot_we = 0;
    assign boot_addr = 0;
    assign boot_wdata = 0;

	////////////////////////////////////////////////////////////
	// PIPELINE CPU
	////////////////////////////////////////////////////////////
	pipe pipe_u (
		.clk               (cpu_clk),
		.reset             (cpu_reset),
		.stall             (axi_dmem_stall), // Hooked to AXI bridge stall
		.exception         (exception),
		.pc_out            (current_pc), 
		.inst_mem_address  (inst_mem_address),
		.inst_mem_is_valid (inst_mem_is_valid),
		.inst_mem_read_data(inst_mem_read_data),
		.inst_mem_is_ready (inst_mem_is_ready),

		.dmem_read_address (dmem_read_address),
		.dmem_read_ready   (dmem_read_ready),
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
		.clk  (clk),
		.pc   (inst_mem_address),
		.instr(inst_mem_read_data),
		.boot_we(boot_we),
		.boot_addr(boot_addr),
		.boot_wdata(boot_wdata)
	);

	////////////////////////////////////////////////////////////
	// DATA MEMORY (BRAM) & AXI WRAPPER (M0)
	////////////////////////////////////////////////////////////
    // Bootloader writes bypass AXI completely to make resetting robust
    wire [31:0] bram_axi_addr;
    wire        bram_axi_en;
    wire [3:0]  bram_axi_we;
    wire [31:0] bram_axi_wdata;
    wire [31:0] bram_axi_rdata;

    axi4_lite_bram_ctrl axi_bram_inst (
        .clk           (cpu_clk),
        .resetn        (cpu_reset),
        .s_axi_awaddr  (m0_axi_awaddr),  .s_axi_awvalid (m0_axi_awvalid), .s_axi_awready (m0_axi_awready),
        .s_axi_wdata   (m0_axi_wdata),   .s_axi_wstrb   (m0_axi_wstrb),   .s_axi_wvalid  (m0_axi_wvalid),  .s_axi_wready  (m0_axi_wready),
        .s_axi_bresp   (m0_axi_bresp),   .s_axi_bvalid  (m0_axi_bvalid),  .s_axi_bready  (m0_axi_bready),
        .s_axi_araddr  (m0_axi_araddr),  .s_axi_arvalid (m0_axi_arvalid), .s_axi_arready (m0_axi_arready),
        .s_axi_rdata   (m0_axi_rdata),   .s_axi_rresp   (m0_axi_rresp),   .s_axi_rvalid  (m0_axi_rvalid),  .s_axi_rready  (m0_axi_rready),
        
        .bram_addr     (bram_axi_addr),
        .bram_en       (bram_axi_en),
        .bram_we       (bram_axi_we),
        .bram_wdata    (bram_axi_wdata),
        .bram_rdata    (bram_axi_rdata)
    );

    wire bram_we           = boot_we || (|bram_axi_we);
    wire [31:0] bram_waddr = boot_we ? boot_addr  : bram_axi_addr;
    wire [31:0] bram_wdata = boot_we ? boot_wdata : bram_axi_wdata;
    wire [3:0]  bram_wstrb = boot_we ? 4'b1111    : bram_axi_we;

	data_mem DMEM (
		.clk   (cpu_clk), 
		.re    (bram_axi_en && (bram_axi_we == 4'h0)), 
		.raddr (bram_axi_addr), // Re-use the AXI address
		.rdata (bram_axi_rdata), 
		.we    (bram_we),
		.waddr (bram_waddr),
		.wdata (bram_wdata),
		.wstrb (bram_wstrb)
	);

endmodule
