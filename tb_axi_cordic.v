`timescale 1ns/1ps

module tb_axi_cordic;

    // Clock and Reset
    reg clk;
    reg reset;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // AXI4-Lite Signals
    reg  [31:0] s_axi_awaddr;
    reg  [2:0]  s_axi_awprot;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;
    
    reg  [31:0] s_axi_araddr;
    reg  [2:0]  s_axi_arprot;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // DUT Instantiation
    axi_cordic_slave uut (
        .clk(clk),
        .reset(reset),
        
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    // AXI Write Task
    task axi_write(input [31:0] addr, input [31:0] data);
        reg hw_done, hb_done;
        begin
            @(posedge clk);
            #1;
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1;
            s_axi_wdata   = data;
            s_axi_wstrb   = 4'hF;
            s_axi_wvalid  = 1;
            s_axi_bready  = 1;

            hw_done = 0;
            while (!hw_done) begin
                @(posedge clk);
                if (s_axi_awready && s_axi_wready && s_axi_awvalid && s_axi_wvalid) hw_done = 1;
            end
            
            #1;
            s_axi_awvalid = 0;
            s_axi_wvalid  = 0;

            hb_done = 0;
            while (!hb_done) begin
                @(posedge clk);
                if (s_axi_bvalid && s_axi_bready) hb_done = 1;
            end
            
            #1;
            s_axi_bready = 0;
        end
    endtask

    // AXI Read Task
    task axi_read(input [31:0] addr, output [31:0] data);
        reg hr_done, hrd_done;
        begin
            @(posedge clk);
            #1;
            s_axi_araddr  = addr;
            s_axi_arvalid = 1;
            s_axi_rready  = 1;

            hr_done = 0;
            while (!hr_done) begin
                @(posedge clk);
                if (s_axi_arready && s_axi_arvalid) hr_done = 1;
            end
            
            #1;
            s_axi_arvalid = 0;

            hrd_done = 0;
            while (!hrd_done) begin
                @(posedge clk);
                if (s_axi_rvalid && s_axi_rready) hrd_done = 1;
            end
            
            data = s_axi_rdata;
            #1;
            s_axi_rready = 0;
        end
    endtask

    reg [31:0] read_val;

    initial begin
        $dumpfile("tb_axi_cordic.vcd");
        $dumpvars(0, tb_axi_cordic);
        
        // Initialize AXI signals
        s_axi_awaddr  = 0;
        s_axi_awprot  = 0;
        s_axi_awvalid = 0;
        s_axi_wdata   = 0;
        s_axi_wstrb   = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0;
        s_axi_arprot  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;

        reset = 0;
        #20 reset = 1;

        $display("Starting AXI CORDIC Test...");

        // Write target angle = pi/2 (0x1921FB54 in Q4.28)
        $display("Writing target angle (pi/2) to 0x00...");
        axi_write(32'h0000_0000, 32'h1921FB54);

        // Poll valid bit (offset 0x04)
        $display("Polling valid bit at 0x04...");
        read_val = 0;
        while (read_val[0] == 0) begin
            axi_read(32'h0000_0004, read_val);
        end
        $display("CORDIC computation valid.");

        // Read Sine (offset 0x08)
        axi_read(32'h0000_0008, read_val);
        $display("Sine   = %h (Expected ~1.0 in Q4.28 = 10000000)", read_val);

        // Read Cosine (offset 0x0C)
        axi_read(32'h0000_000C, read_val);
        $display("Cosine = %h (Expected ~0.0)", read_val);

        // Test 2: Angle = pi/4 (0x0C90FDAB)
        $display("\nWriting target angle (pi/4) to 0x00...");
        axi_write(32'h0000_0000, 32'h0C90FDAB);

        // Poll valid bit
        read_val = 0;
        while (read_val[0] == 0) begin
            axi_read(32'h0000_0004, read_val);
        end

        // Read Sine
        axi_read(32'h0000_0008, read_val);
        $display("Sine   = %h (Expected ~0.707 => 0x0B504F33)", read_val);

        // Read Cosine
        axi_read(32'h0000_000C, read_val);
        $display("Cosine = %h (Expected ~0.707 => 0x0B504F33)", read_val);

        $display("\nAXI CORDIC Test Complete.");
        $finish;
    end

    // Timeout
    initial begin
        #100000;
        $display("Simulation Timeout");
        $finish;
    end

endmodule
