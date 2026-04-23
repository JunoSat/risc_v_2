`timescale 1ns/1ps
// =============================================================================
// TB3: Standalone Systolic Array Testbench
// Tests the axi_systolic_4x4 module directly via AXI-Lite slave handshakes.
// No processor - we manually drive AXI signals.
// =============================================================================
module tb3_systolic_standalone;
    reg clk, reset;

    // AXI Slave signals
    reg  [31:0] awaddr;  reg [2:0] awprot; reg awvalid;  wire awready;
    reg  [31:0] wdata;   reg [3:0] wstrb;  reg wvalid;   wire wready;
    wire [1:0]  bresp;   wire bvalid;      reg bready;
    reg  [31:0] araddr;  reg [2:0] arprot; reg arvalid;  wire arready;
    wire [31:0] rdata;   wire [1:0] rresp; wire rvalid;  reg rready;

    axi_systolic_4x4 UUT (
        .clk(clk), .reset(reset),
        .s_axi_awaddr(awaddr), .s_axi_awprot(awprot), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(arprot), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
    );

    always #5 clk = ~clk;
    integer fd, pass_count, fail_count;

    // AXI Write Task - Properly synchronous
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            awaddr  <= addr;
            awvalid <= 1;
            wdata   <= data;
            wvalid  <= 1;
            wstrb   <= 4'hF;
            bready  <= 1;

            // Wait for BOTH address and data channels to handshake
            @(posedge clk);   // slave sets ready here
            while (!(awready && wready)) @(posedge clk);

            // Deassert after handshake
            @(posedge clk);
            awvalid <= 0;
            wvalid  <= 0;

            // Wait for write response
            while (!bvalid) @(posedge clk);
            @(posedge clk);
            bready <= 0;
            @(posedge clk); // settle
        end
    endtask

    // AXI Read Task - Properly synchronous
    task axi_read;
        input  [31:0] addr;
        output [31:0] data_out;
        begin
            @(posedge clk);
            araddr  <= addr;
            arvalid <= 1;
            rready  <= 1;

            @(posedge clk);
            while (!arready) @(posedge clk);

            @(posedge clk);
            arvalid <= 0;

            while (!rvalid) @(posedge clk);
            data_out = rdata;
            @(posedge clk);
            rready <= 0;
            @(posedge clk); // settle
        end
    endtask

    // Step trigger
    task step_array;
        begin
            axi_write(32'h50000050, 32'd1);
        end
    endtask

    // Check one output
    task check_output;
        input integer col;
        input [31:0] expected;
        reg [31:0] actual;
        begin
            axi_read(32'h50000060 + (col * 4), actual);
            if (actual == expected) begin
                pass_count = pass_count + 1;
                $display("[PASS] Output[%0d] = %0d (expected %0d)", col, actual, expected);
                $fwrite(fd, "[PASS] Output[%0d] = %0d (expected %0d)\n", col, actual, expected);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] Output[%0d] = %0d (expected %0d)", col, actual, expected);
                $fwrite(fd, "[FAIL] Output[%0d] = %0d (expected %0d)\n", col, actual, expected);
            end
        end
    endtask

    integer i, r, c;

    initial begin
        fd = $fopen("results/tb3_systolic_standalone.txt", "w");
        $fwrite(fd, "=== TB3: Standalone Systolic Array Testbench ===\n\n");
        $display("=== TB3: Standalone Systolic Array Testbench ===");

        clk = 0; reset = 0;
        awaddr = 0; awprot = 0; awvalid = 0;
        wdata = 0; wstrb = 0; wvalid = 0; bready = 0;
        araddr = 0; arprot = 0; arvalid = 0; rready = 0;
        pass_count = 0; fail_count = 0;

        #20 reset = 1;
        #40;

        // =====================================================================
        // Test 1: Identity Matrix × Vector [10, 20, 30, 40] = [10, 20, 30, 40]
        // =====================================================================
        $display("\n--- Test 1: Identity * [10,20,30,40] ---");
        $fwrite(fd, "--- Test 1: Identity * [10,20,30,40] ---\n");

        // Load identity weights
        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                axi_write(32'h50000000 + (r*4+c)*4, (r == c) ? 32'd1 : 32'd0);
            end
        end

        // Load activations
        axi_write(32'h50000040, 32'd10);
        axi_write(32'h50000044, 32'd20);
        axi_write(32'h50000048, 32'd30);
        axi_write(32'h5000004C, 32'd40);

        // Step once with real data
        step_array();
        // Zero the activations and step 6 more times (flush)
        axi_write(32'h50000040, 32'd0); axi_write(32'h50000044, 32'd0);
        axi_write(32'h50000048, 32'd0); axi_write(32'h5000004C, 32'd0);
        for (i = 0; i < 6; i = i + 1) step_array();

        check_output(0, 32'd10);
        check_output(1, 32'd20);
        check_output(2, 32'd30);
        check_output(3, 32'd40);

        // =====================================================================
        // Test 2: Scalar Matrix (all 2s) × Vector [1,1,1,1] = [8,8,8,8]
        // =====================================================================
        $display("\n--- Test 2: Scalar(2) * [1,1,1,1] = [8,8,8,8] ---");
        $fwrite(fd, "\n--- Test 2: Scalar(2) * [1,1,1,1] = [8,8,8,8] ---\n");

        for (r = 0; r < 4; r = r + 1)
            for (c = 0; c < 4; c = c + 1)
                axi_write(32'h50000000 + (r*4+c)*4, 32'd2);

        axi_write(32'h50000040, 32'd1); axi_write(32'h50000044, 32'd1);
        axi_write(32'h50000048, 32'd1); axi_write(32'h5000004C, 32'd1);
        step_array();
        axi_write(32'h50000040, 32'd0); axi_write(32'h50000044, 32'd0);
        axi_write(32'h50000048, 32'd0); axi_write(32'h5000004C, 32'd0);
        for (i = 0; i < 6; i = i + 1) step_array();

        check_output(0, 32'd8);
        check_output(1, 32'd8);
        check_output(2, 32'd8);
        check_output(3, 32'd8);

        // =====================================================================
        // Test 3: Zero weights × any vector = [0,0,0,0]
        // =====================================================================
        $display("\n--- Test 3: Zero * [5,10,15,20] = [0,0,0,0] ---");
        $fwrite(fd, "\n--- Test 3: Zero * [5,10,15,20] = [0,0,0,0] ---\n");

        for (r = 0; r < 16; r = r + 1)
            axi_write(32'h50000000 + r*4, 32'd0);

        axi_write(32'h50000040, 32'd5);  axi_write(32'h50000044, 32'd10);
        axi_write(32'h50000048, 32'd15); axi_write(32'h5000004C, 32'd20);
        step_array();
        axi_write(32'h50000040, 32'd0); axi_write(32'h50000044, 32'd0);
        axi_write(32'h50000048, 32'd0); axi_write(32'h5000004C, 32'd0);
        for (i = 0; i < 6; i = i + 1) step_array();

        check_output(0, 32'd0);
        check_output(1, 32'd0);
        check_output(2, 32'd0);
        check_output(3, 32'd0);

        $display("\n=== Results: %0d PASS, %0d FAIL ===", pass_count, fail_count);
        $fwrite(fd, "\n=== Results: %0d PASS, %0d FAIL ===\n", pass_count, fail_count);
        $fclose(fd);
        #10 $finish;
    end

    // Safety timeout
    initial begin
        #5000000;
        $display("=== TIMEOUT ===");
        $finish;
    end
endmodule
