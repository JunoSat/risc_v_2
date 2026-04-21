`timescale 1ns / 1ps

// =====================================================================
// AXI4-Lite UART Control Wrapper
// memory map:
// 0x00: Write: TX_DATA, Read: RX_DATA
// 0x04: Read: Status (bit 0 = rx_ready, bit 1 = tx_full)
// =====================================================================
module axi4_lite_uart #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire        clk,
    input  wire        resetn,

    // UART Physical pins
    input  wire        rx,
    output wire        tx,

    // AXI4-Lite Interface
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // Expose for Bootloader
    output wire [7:0]  rx_data_out,
    output wire        rx_ready_out
);

    // UART Internal Wires
    wire [7:0] tx_data_int;
    reg        tx_start_int;
    wire       tx_full_int;
    wire [7:0] rx_data_int;
    wire       rx_ready_int;
    reg        rx_ack_int;

    // Instantiate existing UART IP
    uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) UART_INST (
        .clk        (clk),
        .reset      (resetn), // UART IP uses "reset" but looks like it might depend on active low inside? No, uart.v uses negedge reset
        .rx         (rx),
        .tx         (tx),
        .tx_data    (tx_data_int),
        .tx_start   (tx_start_int),
        .tx_full    (tx_full_int),
        .rx_data    (rx_data_int),
        .rx_ready   (rx_ready_int),
        .rx_ack     (rx_ack_int)
    );

    assign tx_data_int = s_axi_wdata[7:0];
    assign rx_data_out = rx_data_int;
    assign rx_ready_out = rx_ready_int;

    // States
    localparam ST_IDLE = 2'd0;
    localparam ST_WRITE_RESP = 2'd1;
    localparam ST_READ_RESP = 2'd2;

    reg [1:0] state;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= ST_IDLE;
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            s_axi_rdata   <= 0;
            tx_start_int  <= 0;
            rx_ack_int    <= 0;
        end else begin
            // Defaults
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_arready <= 0;
            tx_start_int  <= 0;
            rx_ack_int    <= 0;

            case (state)
                ST_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1;
                        s_axi_wready  <= 1;
                        
                        // Write to 0x00 triggers TX
                        if (s_axi_awaddr[7:0] == 8'h00) begin
                            tx_start_int <= 1'b1;
                        end

                        s_axi_bvalid <= 1;
                        s_axi_bresp  <= 2'b00;
                        state <= ST_WRITE_RESP;
                    end else if (s_axi_arvalid) begin
                        s_axi_arready <= 1;
                        
                        s_axi_rvalid <= 1;
                        s_axi_rresp  <= 2'b00;
                        
                        if (s_axi_araddr[7:0] == 8'h00) begin
                            s_axi_rdata <= {24'b0, rx_data_int};
                            // Optional: ack rx here if reading data natively means we consume it?
                            // In original code, reading 0x04 reads data.
                            // Let's adhere to original: reading 0x04 was data? 
                            // Wait, in top_fpga.v:
                            // Read registers (0x8000_0004 = RX Data fetch) -> 8'h04 returns {24'b0, rx_data}
                            // 0x8000_0008 = Status -> returns rx_ready, tx_full
                            // Oh I need to fix the memory map to match top_fpga exactly to avoid C code breakage!
                        end

                        if (s_axi_araddr[7:0] == 8'h04) begin
                            s_axi_rdata <= {24'b0, rx_data_int};
                            rx_ack_int  <= 1'b1; // Consuming the byte
                        end else if (s_axi_araddr[7:0] == 8'h08) begin
                            s_axi_rdata <= {30'b0, rx_ready_int, tx_full_int};
                        end else begin
                            s_axi_rdata <= 32'h0;
                        end
                        
                        state <= ST_READ_RESP;
                    end
                end

                ST_WRITE_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 0;
                        state <= ST_IDLE;
                    end
                end

                ST_READ_RESP: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 0;
                        state <= ST_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
