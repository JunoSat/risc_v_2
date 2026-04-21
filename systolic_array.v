`timescale 1ns / 1ps

// =====================================================================
// AXI4-Lite Systolic Array Accelerator (2x2 Matrix Multiplication) 
// Memory Map:
// 0x00 : CTRL_REG (Bit 0: Start, Bit 1: Reset)
// 0x04 : STATUS_REG (Bit 0: Busy, Bit 1: Done)
// 0x10-0x1C : Matrix A (row-major)
// 0x20-0x2C : Matrix B (row-major)
// 0x30-0x3C : Matrix C (row-major) outputs
// =====================================================================
module systolic_array #(
    parameter DATA_WIDTH = 32
)(
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
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    // Accelerator Registers
    reg ctrl_start;
    reg ctrl_reset;
    reg status_busy;
    reg status_done;

    reg signed [DATA_WIDTH-1:0] matrix_a [0:3];
    reg signed [DATA_WIDTH-1:0] matrix_b [0:3];
    reg signed [DATA_WIDTH-1:0] matrix_c [0:3];

    // Compute FSM
    localparam COMP_IDLE = 3'd0;
    localparam COMP_CALC1 = 3'd1;
    localparam COMP_CALC2 = 3'd2;
    localparam COMP_DONE = 3'd3;

    reg [2:0] comp_state;

    // AXI Logic States
    localparam ST_AXI_IDLE = 2'd0;
    localparam ST_AXI_WRITE = 2'd1;
    localparam ST_AXI_READ = 2'd2;
    reg [1:0] axi_state;

    integer i;

    // ----------------------------------------------------
    // Compute Logic
    // ----------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            comp_state <= COMP_IDLE;
            status_busy <= 0;
            status_done <= 0;
            for (i=0; i<4; i=i+1) matrix_c[i] <= 0;
        end else begin
            if (ctrl_reset) begin
                comp_state <= COMP_IDLE;
                status_busy <= 0;
                status_done <= 0;
                for (i=0; i<4; i=i+1) matrix_c[i] <= 0;
            end else begin
                case (comp_state)
                    COMP_IDLE: begin
                        if (ctrl_start) begin
                            status_busy <= 1;
                            status_done <= 0;
                            comp_state <= COMP_CALC1;
                        end
                    end
                    COMP_CALC1: begin
                        // For 2x2, C00 = A00*B00 + A01*B10
                        // C01 = A00*B01 + A01*B11
                        // C10 = A10*B00 + A11*B10
                        // C11 = A10*B01 + A11*B11
                        // Taking 1 cycle for multiplication and addition since modern FPGA DSP slices can easily handle 32-bit MAC at 50MHz.
                        // We will just do it in one cycle for simplicity, though a true systolic array would take 2N-1 cycles.
                        // To simulate latency, we add dummy states.
                        matrix_c[0] <= matrix_a[0]*matrix_b[0] + matrix_a[1]*matrix_b[2];
                        matrix_c[1] <= matrix_a[0]*matrix_b[1] + matrix_a[1]*matrix_b[3];
                        comp_state <= COMP_CALC2;
                    end
                    COMP_CALC2: begin
                        matrix_c[2] <= matrix_a[2]*matrix_b[0] + matrix_a[3]*matrix_b[2];
                        matrix_c[3] <= matrix_a[2]*matrix_b[1] + matrix_a[3]*matrix_b[3];
                        comp_state <= COMP_DONE;
                    end
                    COMP_DONE: begin
                        status_busy <= 0;
                        status_done <= 1;
                        if (!ctrl_start) begin // Ensure start is deasserted before returning
                            comp_state <= COMP_IDLE;
                        end
                    end
                endcase
            end
        end
    end

    // ----------------------------------------------------
    // AXI-Lite Slave Interface Logic
    // ----------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            axi_state <= ST_AXI_IDLE;
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            s_axi_rdata   <= 0;
            ctrl_start <= 0;
            ctrl_reset <= 0;
            for (i=0; i<4; i=i+1) begin
                matrix_a[i] <= 0;
                matrix_b[i] <= 0;
            end
        end else begin
            // Defaults
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_arready <= 0;
            
            // Auto-clear start pulse to allow re-triggering safely
            if (comp_state != COMP_IDLE) begin
                ctrl_start <= 0; 
                ctrl_reset <= 0;
            end

            case (axi_state)
                ST_AXI_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1;
                        s_axi_wready  <= 1;
                        
                        // Address Decode for Write
                        case (s_axi_awaddr[7:0])
                            8'h00: begin
                                ctrl_start <= s_axi_wdata[0];
                                ctrl_reset <= s_axi_wdata[1];
                            end
                            8'h10: matrix_a[0] <= s_axi_wdata;
                            8'h14: matrix_a[1] <= s_axi_wdata;
                            8'h18: matrix_a[2] <= s_axi_wdata;
                            8'h1C: matrix_a[3] <= s_axi_wdata;
                            8'h20: matrix_b[0] <= s_axi_wdata;
                            8'h24: matrix_b[1] <= s_axi_wdata;
                            8'h28: matrix_b[2] <= s_axi_wdata;
                            8'h2C: matrix_b[3] <= s_axi_wdata;
                        endcase
                        
                        s_axi_bvalid <= 1;
                        s_axi_bresp  <= 2'b00;
                        axi_state <= ST_AXI_WRITE;
                    end else if (s_axi_arvalid) begin
                        s_axi_arready <= 1;
                        s_axi_rvalid <= 1;
                        s_axi_rresp <= 2'b00;

                        // Address Decode for Read
                        case (s_axi_araddr[7:0])
                            8'h00: s_axi_rdata <= {30'b0, ctrl_reset, ctrl_start};
                            8'h04: s_axi_rdata <= {30'b0, status_done, status_busy};
                            8'h10: s_axi_rdata <= matrix_a[0];
                            8'h14: s_axi_rdata <= matrix_a[1];
                            8'h18: s_axi_rdata <= matrix_a[2];
                            8'h1C: s_axi_rdata <= matrix_a[3];
                            8'h20: s_axi_rdata <= matrix_b[0];
                            8'h24: s_axi_rdata <= matrix_b[1];
                            8'h28: s_axi_rdata <= matrix_b[2];
                            8'h2C: s_axi_rdata <= matrix_b[3];
                            8'h30: s_axi_rdata <= matrix_c[0];
                            8'h34: s_axi_rdata <= matrix_c[1];
                            8'h38: s_axi_rdata <= matrix_c[2];
                            8'h3C: s_axi_rdata <= matrix_c[3];
                            default: s_axi_rdata <= 32'h00000000;
                        endcase

                        axi_state <= ST_AXI_READ;
                    end
                end

                ST_AXI_WRITE: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 0;
                        axi_state <= ST_AXI_IDLE;
                    end
                end

                ST_AXI_READ: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 0;
                        axi_state <= ST_AXI_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
