`timescale 1ns/1ps

module axi_cordic_slave (
    input clk, reset,

    // AXI4-Lite Slave Interface 
    input  wire [31:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
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
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    reg cordic_start;
    reg [31:0]  cordic_target_angle;
    wire        cordic_valid_out;
    wire [31:0] cordic_sin_out;
    wire [31:0] cordic_cos_out;

    // Result latches: capture sin/cos the moment valid_out fires,
    // so the CPU can read them any time afterwards without racing the CORDIC state machine.
    reg [31:0] sin_latch;
    reg [31:0] cos_latch;

    reg [31:0] read_addr_buf;
    
    cordic_iterative CORDIC_CORE (
        .clk(clk),
        .reset(reset),
        .start(cordic_start),
        .target_angle(cordic_target_angle),
        .valid_out(cordic_valid_out),
        .sin_out(cordic_sin_out),
        .cos_out(cordic_cos_out)
    );

    // latched_valid: cleared by cordic_start (new angle written), set when CORDIC finishes.
    // cordic_start MUST have priority - otherwise a new angle write while DONE state is active
    // would leave latched_valid=1 and the CPU would incorrectly read the OLD result immediately.
    reg latched_valid;
    always @(posedge clk) begin
        if (!reset) begin
            latched_valid <= 0;
            sin_latch     <= 0;
            cos_latch     <= 0;
        end else if (cordic_start) begin
            // New computation requested - clear stale valid flag
            latched_valid <= 0;
        end else if (cordic_valid_out) begin
            // CORDIC finished - latch the stable results NOW before CORDIC goes back to IDLE
            latched_valid <= 1;
            sin_latch     <= cordic_sin_out;
            cos_latch     <= cordic_cos_out;
        end
    end

    // AXI WRITE logic
    always @(posedge clk) begin
        cordic_start <= 0;
        if (!reset) begin
            s_axi_awready <= 0;
            s_axi_wready <= 0;
            s_axi_bvalid <= 0;
        end else begin
            if (s_axi_awvalid && !s_axi_awready) s_axi_awready <= 1;
            else s_axi_awready <= 0;

            if (s_axi_wvalid && !s_axi_wready) s_axi_wready <= 1;
            else s_axi_wready <= 0;
            
            // Check for actual Write
            if (s_axi_wvalid && s_axi_wready && s_axi_awvalid && s_axi_awready) begin
                if (s_axi_awaddr[7:0] == 8'h00) begin
                    cordic_target_angle <= s_axi_wdata;
                    cordic_start <= 1;
                end
                s_axi_bvalid <= 1;
                s_axi_bresp <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 0;
            end
        end
    end

    // AXI READ logic
    always @(posedge clk) begin
        if (!reset) begin
            s_axi_arready <= 0;
            s_axi_rvalid <= 0;
        end else begin
            if (s_axi_arvalid && !s_axi_arready) begin
                s_axi_arready <= 1;
                read_addr_buf <= s_axi_araddr;
            end else begin
                s_axi_arready <= 0;
            end
            
            if (s_axi_arready && s_axi_arvalid) begin
                s_axi_rvalid <= 1;
                s_axi_rresp <= 2'b00;
                
                case (s_axi_araddr[7:0])
                    8'h04: s_axi_rdata <= {31'b0, latched_valid};
                    8'h08: s_axi_rdata <= sin_latch;   // Stable latched result
                    8'h0C: s_axi_rdata <= cos_latch;   // Stable latched result
                    default: s_axi_rdata <= 32'h0;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 0;
            end
        end
    end

endmodule
