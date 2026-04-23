`timescale 1ns/1ps
// =============================================================================
// Shared SoC Testbench Harness
// Instantiates top_fpga + axi_cordic_slave + axi_systolic_4x4 and monitors
// the g_result sentinel in DMEM to determine PASS/FAIL.
//
// The C program writes 0x600D to g_result on success, or a negative value on
// failure. g_result lives at address 0x0 in .bss which maps to DMEM word 0.
// =============================================================================
module soc_harness (
    output reg clk,
    output reg reset_n
);

    wire uart_tx;
    wire [15:0] led;

    // AXI Master ↔ CORDIC Slave bus
    wire [31:0] m_axi_awaddr, m_axi_araddr, m_axi_wdata, m_axi_rdata;
    wire [2:0]  m_axi_awprot, m_axi_arprot;
    wire [3:0]  m_axi_wstrb;
    wire [1:0]  m_axi_bresp, m_axi_rresp;
    wire        m_axi_awvalid, m_axi_awready, m_axi_wvalid, m_axi_wready;
    wire        m_axi_bvalid, m_axi_bready;
    wire        m_axi_arvalid, m_axi_arready, m_axi_rvalid, m_axi_rready;

    top_fpga SOC (
        .clk(clk), .reset(reset_n),
        .uart_rx(1'b1), .uart_tx(uart_tx), .led(led),
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr), .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready)
    );

    // External CORDIC slave connected to the external AXI master port
    axi_cordic_slave HW_CORDIC (
        .clk(clk), .reset(reset_n),
        .s_axi_awaddr(m_axi_awaddr), .s_axi_awprot(m_axi_awprot),
        .s_axi_awvalid(m_axi_awvalid), .s_axi_awready(m_axi_awready),
        .s_axi_wdata(m_axi_wdata), .s_axi_wstrb(m_axi_wstrb),
        .s_axi_wvalid(m_axi_wvalid), .s_axi_wready(m_axi_wready),
        .s_axi_bresp(m_axi_bresp), .s_axi_bvalid(m_axi_bvalid),
        .s_axi_bready(m_axi_bready),
        .s_axi_araddr(m_axi_araddr), .s_axi_arprot(m_axi_arprot),
        .s_axi_arvalid(m_axi_arvalid), .s_axi_arready(m_axi_arready),
        .s_axi_rdata(m_axi_rdata), .s_axi_rresp(m_axi_rresp),
        .s_axi_rvalid(m_axi_rvalid), .s_axi_rready(m_axi_rready)
    );

    // (Systolic slave is instantiated internally inside top_fpga.v)

    always #10 clk = ~clk;  // 50 MHz

endmodule
