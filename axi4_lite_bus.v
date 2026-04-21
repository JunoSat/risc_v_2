`timescale 1ns / 1ps

// =====================================================================
// AXI4-Lite Master Bridge for CPU Data Memory Interface
// =====================================================================
module axi4_lite_master_bridge (
    input  wire        clk,
    input  wire        resetn,

    // CPU Side Interface
    input  wire [31:0] cpu_raddr,
    input  wire        cpu_rreq,
    output reg  [31:0] cpu_rdata,

    input  wire [31:0] cpu_waddr,
    input  wire        cpu_wreq,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,

    output wire        cpu_stall,

    // AXI4-Lite Side Interface
    // Write Address Channel
    output reg  [31:0] m_axi_awaddr,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,
    // Write Data Channel
    output reg  [31:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,
    // Write Response Channel
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output reg         m_axi_bready,
    // Read Address Channel
    output reg  [31:0] m_axi_araddr,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    // Read Data Channel
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready
);

    localparam STATE_IDLE  = 3'd0;
    localparam STATE_WADDR = 3'd1;
    localparam STATE_WRESP = 3'd3;
    localparam STATE_RADDR = 3'd4;
    localparam STATE_RDATA = 3'd5;
    localparam STATE_DONE  = 3'd6;

    reg [2:0] state;

    // Stall whenever a transaction is in flight
    assign cpu_stall = (state != STATE_IDLE && state != STATE_DONE);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state         <= STATE_IDLE;
            m_axi_awaddr  <= 0;
            m_axi_awvalid <= 0;
            m_axi_wdata   <= 0;
            m_axi_wstrb   <= 0;
            m_axi_wvalid  <= 0;
            m_axi_bready  <= 0;
            m_axi_araddr  <= 0;
            m_axi_arvalid <= 0;
            m_axi_rready  <= 0;
            cpu_rdata     <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (cpu_wreq) begin
                        m_axi_awaddr  <= cpu_waddr;
                        m_axi_awvalid <= 1;
                        m_axi_wdata   <= cpu_wdata;
                        m_axi_wstrb   <= cpu_wstrb;
                        m_axi_wvalid  <= 1;
                        m_axi_bready  <= 0; /* Wait until WRESP */
                        state         <= STATE_WADDR;
                    end else if (cpu_rreq) begin
                        m_axi_araddr  <= cpu_raddr;
                        m_axi_arvalid <= 1;
                        m_axi_rready  <= 0; /* Wait until RDATA */
                        state         <= STATE_RADDR;
                    end
                end

                STATE_WADDR: begin
                    // De-assert valids as they are accepted
                    if (m_axi_awready) m_axi_awvalid <= 0;
                    if (m_axi_wready)  m_axi_wvalid  <= 0;
                    // Both channels accepted -> wait for B response
                    if ((m_axi_awready || !m_axi_awvalid) && (m_axi_wready || !m_axi_wvalid)) begin
                        state <= STATE_WRESP;
                        m_axi_bready <= 1; // Assert ready for B response
                    end
                end

                STATE_WRESP: begin
                    // De-assert wvalid if wready came later than awready
                    if (m_axi_wready && m_axi_wvalid) m_axi_wvalid <= 0;
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 0;
                        state        <= STATE_DONE;
                    end
                end

                STATE_RADDR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 0;
                        state         <= STATE_RDATA;
                        m_axi_rready  <= 1; // Assert ready for R response
                    end
                end

                STATE_RDATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        cpu_rdata    <= m_axi_rdata;
                        m_axi_rready <= 0;
                        state        <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule


// =====================================================================
// AXI4-Lite Interconnect (1 Master, 3 Slaves)
// Slave 0: DMEM (0x0000_0000 - 0x0000_1FFF)
// Slave 1: UART (0x8000_0000 - 0x8000_00FF)
// Slave 2: SYSTOLIC (0x9000_0000 - 0x9000_0FFF)
// =====================================================================
module axi4_lite_interconnect (
    input  wire        clk,
    input  wire        resetn,

    // Master (CPU)
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // Slave 0 (DMEM)
    output wire [31:0] m0_axi_awaddr,
    output wire        m0_axi_awvalid,
    input  wire        m0_axi_awready,
    output wire [31:0] m0_axi_wdata,
    output wire [3:0]  m0_axi_wstrb,
    output wire        m0_axi_wvalid,
    input  wire        m0_axi_wready,
    input  wire [1:0]  m0_axi_bresp,
    input  wire        m0_axi_bvalid,
    output wire        m0_axi_bready,
    output wire [31:0] m0_axi_araddr,
    output wire        m0_axi_arvalid,
    input  wire        m0_axi_arready,
    input  wire [31:0] m0_axi_rdata,
    input  wire [1:0]  m0_axi_rresp,
    input  wire        m0_axi_rvalid,
    output wire        m0_axi_rready,

    // Slave 1 (UART)
    output wire [31:0] m1_axi_awaddr,
    output wire        m1_axi_awvalid,
    input  wire        m1_axi_awready,
    output wire [31:0] m1_axi_wdata,
    output wire [3:0]  m1_axi_wstrb,
    output wire        m1_axi_wvalid,
    input  wire        m1_axi_wready,
    input  wire [1:0]  m1_axi_bresp,
    input  wire        m1_axi_bvalid,
    output wire        m1_axi_bready,
    output wire [31:0] m1_axi_araddr,
    output wire        m1_axi_arvalid,
    input  wire        m1_axi_arready,
    input  wire [31:0] m1_axi_rdata,
    input  wire [1:0]  m1_axi_rresp,
    input  wire        m1_axi_rvalid,
    output wire        m1_axi_rready,

    // Slave 2 (SYSTOLIC)
    output wire [31:0] m2_axi_awaddr,
    output wire        m2_axi_awvalid,
    input  wire        m2_axi_awready,
    output wire [31:0] m2_axi_wdata,
    output wire [3:0]  m2_axi_wstrb,
    output wire        m2_axi_wvalid,
    input  wire        m2_axi_wready,
    input  wire [1:0]  m2_axi_bresp,
    input  wire        m2_axi_bvalid,
    output wire        m2_axi_bready,
    output wire [31:0] m2_axi_araddr,
    output wire        m2_axi_arvalid,
    input  wire        m2_axi_arready,
    input  wire [31:0] m2_axi_rdata,
    input  wire [1:0]  m2_axi_rresp,
    input  wire        m2_axi_rvalid,
    output wire        m2_axi_rready
);

    // Address Decoding
    wire aw_sel_m0 = (s_axi_awaddr[31:28] == 4'h0);
    wire aw_sel_m1 = (s_axi_awaddr[31:28] == 4'h8);
    wire aw_sel_m2 = (s_axi_awaddr[31:28] == 4'h9);

    wire ar_sel_m0 = (s_axi_araddr[31:28] == 4'h0);
    wire ar_sel_m1 = (s_axi_araddr[31:28] == 4'h8);
    wire ar_sel_m2 = (s_axi_araddr[31:28] == 4'h9);

    // We need to latch the active slave during a transaction to route W, B, R channels correctly.
    // Simplifying assumption: Master finishes one transaction before starting another.
    reg [2:0] slave_sel_wr;
    reg [2:0] slave_sel_rd;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            slave_sel_wr <= 0;
            slave_sel_rd <= 0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                slave_sel_wr <= {aw_sel_m2, aw_sel_m1, aw_sel_m0};
            end
            if (s_axi_arvalid && s_axi_arready) begin
                slave_sel_rd <= {ar_sel_m2, ar_sel_m1, ar_sel_m0};
            end
        end
    end

    wire [2:0] current_wr_sel = (s_axi_awvalid) ? {aw_sel_m2, aw_sel_m1, aw_sel_m0} : slave_sel_wr;
    wire [2:0] current_rd_sel = (s_axi_arvalid) ? {ar_sel_m2, ar_sel_m1, ar_sel_m0} : slave_sel_rd;

    // AW Channel Routing
    assign m0_axi_awaddr  = s_axi_awaddr;
    assign m0_axi_awvalid = s_axi_awvalid && current_wr_sel[0];
    assign m1_axi_awaddr  = s_axi_awaddr;
    assign m1_axi_awvalid = s_axi_awvalid && current_wr_sel[1];
    assign m2_axi_awaddr  = s_axi_awaddr;
    assign m2_axi_awvalid = s_axi_awvalid && current_wr_sel[2];
    
    assign s_axi_awready = (current_wr_sel[0]) ? m0_axi_awready :
                           (current_wr_sel[1]) ? m1_axi_awready :
                           (current_wr_sel[2]) ? m2_axi_awready : 1'b1; // Default ready for invalid addresses

    // W Channel Routing
    assign m0_axi_wdata  = s_axi_wdata;
    assign m0_axi_wstrb  = s_axi_wstrb;
    assign m0_axi_wvalid = s_axi_wvalid && current_wr_sel[0];
    assign m1_axi_wdata  = s_axi_wdata;
    assign m1_axi_wstrb  = s_axi_wstrb;
    assign m1_axi_wvalid = s_axi_wvalid && current_wr_sel[1];
    assign m2_axi_wdata  = s_axi_wdata;
    assign m2_axi_wstrb  = s_axi_wstrb;
    assign m2_axi_wvalid = s_axi_wvalid && current_wr_sel[2];
    
    assign s_axi_wready =  (current_wr_sel[0]) ? m0_axi_wready :
                           (current_wr_sel[1]) ? m1_axi_wready :
                           (current_wr_sel[2]) ? m2_axi_wready : 1'b1;

    // B Channel Routing
    assign s_axi_bresp  = (current_wr_sel[0]) ? m0_axi_bresp :
                          (current_wr_sel[1]) ? m1_axi_bresp :
                          (current_wr_sel[2]) ? m2_axi_bresp : 2'b00;
    assign s_axi_bvalid = (current_wr_sel[0]) ? m0_axi_bvalid :
                          (current_wr_sel[1]) ? m1_axi_bvalid :
                          (current_wr_sel[2]) ? m2_axi_bvalid : (s_axi_wvalid && s_axi_awvalid); // Quick ack for trash
    
    assign m0_axi_bready = s_axi_bready && current_wr_sel[0];
    assign m1_axi_bready = s_axi_bready && current_wr_sel[1];
    assign m2_axi_bready = s_axi_bready && current_wr_sel[2];

    // AR Channel Routing
    assign m0_axi_araddr  = s_axi_araddr;
    assign m0_axi_arvalid = s_axi_arvalid && current_rd_sel[0];
    assign m1_axi_araddr  = s_axi_araddr;
    assign m1_axi_arvalid = s_axi_arvalid && current_rd_sel[1];
    assign m2_axi_araddr  = s_axi_araddr;
    assign m2_axi_arvalid = s_axi_arvalid && current_rd_sel[2];
    
    assign s_axi_arready = (current_rd_sel[0]) ? m0_axi_arready :
                           (current_rd_sel[1]) ? m1_axi_arready :
                           (current_rd_sel[2]) ? m2_axi_arready : 1'b1;

    // R Channel Routing
    assign s_axi_rdata  = (current_rd_sel[0]) ? m0_axi_rdata :
                          (current_rd_sel[1]) ? m1_axi_rdata :
                          (current_rd_sel[2]) ? m2_axi_rdata : 32'hDEADBEEF;
    assign s_axi_rresp  = (current_rd_sel[0]) ? m0_axi_rresp :
                          (current_rd_sel[1]) ? m1_axi_rresp :
                          (current_rd_sel[2]) ? m2_axi_rresp : 2'b00;
    assign s_axi_rvalid = (current_rd_sel[0]) ? m0_axi_rvalid :
                          (current_rd_sel[1]) ? m1_axi_rvalid :
                          (current_rd_sel[2]) ? m2_axi_rvalid : s_axi_arvalid;
                          
    assign m0_axi_rready = s_axi_rready && current_rd_sel[0];
    assign m1_axi_rready = s_axi_rready && current_rd_sel[1];
    assign m2_axi_rready = s_axi_rready && current_rd_sel[2];

endmodule

// =====================================================================
// AXI4-Lite BRAM Controller (Wraps existing data_mem pins)
// Does NOT instantiate data_mem itself, just exposes native port.
// =====================================================================
module axi4_lite_bram_ctrl (
    input  wire        clk,
    input  wire        resetn,

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
    output wire [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // BRAM Native Interface (assumed 1-cycle latency pipeline)
    output reg  [31:0] bram_addr,
    output reg         bram_en,
    output reg  [3:0]  bram_we,
    output reg  [31:0] bram_wdata,
    input  wire [31:0] bram_rdata
);

    // States
    localparam ST_IDLE = 2'd0;
    localparam ST_WRITE = 2'd1;
    localparam ST_READ = 2'd2;

    reg [1:0] state;

    assign s_axi_rdata = bram_rdata; // the BRAM returns it 1 cycle after en. We will hold rvalid high.

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= ST_IDLE;
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            
            bram_en <= 0;
            bram_we <= 0;
        end else begin
            // Defaults
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_arready <= 0;
            bram_en <= 0;
            bram_we <= 0;

            case (state)
                ST_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        // Accept write immediately
                        s_axi_awready <= 1;
                        s_axi_wready  <= 1;
                        
                        bram_addr  <= s_axi_awaddr;
                        bram_wdata <= s_axi_wdata;
                        bram_we    <= s_axi_wstrb;
                        bram_en    <= 1;
                        
                        s_axi_bvalid <= 1;
                        s_axi_bresp  <= 2'b00;
                        state <= ST_WRITE;
                    end else if (s_axi_arvalid) begin
                        // Accept read
                        s_axi_arready <= 1;
                        
                        bram_addr <= s_axi_araddr;
                        bram_we   <= 4'h0;
                        bram_en   <= 1;
                        
                        state <= ST_READ;
                    end
                end

                ST_WRITE: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 0;
                        state <= ST_IDLE;
                    end
                end

                ST_READ: begin
                    // On this cycle, BRAM output is valid (since bram_en was 1 last cycle)
                    s_axi_rvalid <= 1;
                    s_axi_rresp  <= 2'b00;
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 0;
                        state <= ST_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
