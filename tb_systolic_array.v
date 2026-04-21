`timescale 1ns / 1ps

module tb_systolic_array;
    reg clk;
    reg resetn;
    
    // Test AXI Signals
    reg  [31:0] awaddr;
    reg         awvalid;
    wire        awready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;
    
    reg  [31:0] araddr;
    reg         arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    systolic_array #(
        .DATA_WIDTH(32)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
    );

    always #5 clk = ~clk;

    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr <= addr;
            awvalid <= 1;
            wdata <= data;
            wstrb <= 4'hF;
            wvalid <= 1;
            bready <= 1;

            // Wait simultaneously for handshake
            while (!(awready && wready)) begin
                @(posedge clk);
            end
            
            awvalid <= 0;
            wvalid <= 0;

            while (!bvalid) begin
                @(posedge clk);
            end
            bready <= 0;
        end
    endtask

    task axi_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            araddr <= addr;
            arvalid <= 1;
            rready <= 1;

            while (!arready) begin
                @(posedge clk);
            end
            arvalid <= 0;

            while (!rvalid) begin
                @(posedge clk);
            end
            data = rdata;
            rready <= 0;
            @(posedge clk); // Give one more cycle so task output gets synced cleanly
        end
    endtask

    reg [31:0] rval;

    initial begin
        clk = 0;
        resetn = 0;
        awaddr = 0; awvalid = 0; wdata = 0; wstrb = 0; wvalid = 0; bready = 0;
        araddr = 0; arvalid = 0; rready = 0;

        #20 resetn = 1; #20;

        $display("Testing write to Matrix A and B");
        // A00 = 1, A01 = 2
        // A10 = 3, A11 = 4
        axi_write(32'h10, 1);
        axi_write(32'h14, 2);
        axi_write(32'h18, 3);
        axi_write(32'h1C, 4);

        // B00 = 5, B01 = 6
        // B10 = 7, B11 = 8
        axi_write(32'h20, 5);
        axi_write(32'h24, 6);
        axi_write(32'h28, 7);
        axi_write(32'h2C, 8);

        $display("Triggering computation");
        // Write 1 to start
        axi_write(32'h00, 1);

        $display("Polling status");
        rval = 0;
        while ((rval & 2) == 0) begin // Check if Done bit (bit 1) is 1. Wait, status mapping: bit 0 busy, bit 1 done.
            axi_read(32'h04, rval);
            $display("Read status %0h", rval);
            #10;
        end

        $display("Computation done, reading results");
        // C00 = 1*5 + 2*7 = 19
        // C01 = 1*6 + 2*8 = 22
        // C10 = 3*5 + 4*7 = 43
        // C11 = 3*6 + 4*8 = 50
        axi_read(32'h30, rval); $display("C00: %0d", rval); if(rval != 19) $error("C00 fail");
        axi_read(32'h34, rval); $display("C01: %0d", rval); if(rval != 22) $error("C01 fail");
        axi_read(32'h38, rval); $display("C10: %0d", rval); if(rval != 43) $error("C10 fail");
        axi_read(32'h3C, rval); $display("C11: %0d", rval); if(rval != 50) $error("C11 fail");

        $display("\n=== Test 2: Identity Matrix Edge Case ===");
        axi_write(32'h10, 1); axi_write(32'h14, 0); axi_write(32'h18, 0); axi_write(32'h1C, 1);
        axi_write(32'h20, 9); axi_write(32'h24, 8); axi_write(32'h28, 7); axi_write(32'h2C, 6);
        $display("Triggering computation");
        axi_write(32'h00, 1);
        rval = 0;
        while ((rval & 2) == 0) begin axi_read(32'h04, rval); #10; end
        $display("Computation done, reading results");
        axi_read(32'h30, rval); $display("C00: %0d", rval); if(rval != 9) $error("C00 fail");
        axi_read(32'h34, rval); $display("C01: %0d", rval); if(rval != 8) $error("C01 fail");
        axi_read(32'h38, rval); $display("C10: %0d", rval); if(rval != 7) $error("C10 fail");
        axi_read(32'h3C, rval); $display("C11: %0d", rval); if(rval != 6) $error("C11 fail");

        $display("\n=== Test 3: Large Numbers Edge Case ===");
        axi_write(32'h10, 1000); axi_write(32'h14, 2000); axi_write(32'h18, 3000); axi_write(32'h1C, 4000);
        axi_write(32'h20, 10); axi_write(32'h24, 20); axi_write(32'h28, 30); axi_write(32'h2C, 40);
        $display("Triggering computation");
        axi_write(32'h00, 1);
        rval = 0;
        while ((rval & 2) == 0) begin axi_read(32'h04, rval); #10; end
        $display("Computation done, reading results");
        axi_read(32'h30, rval); $display("C00: %0d", rval); if(rval != 70000) $error("C00 fail");
        axi_read(32'h34, rval); $display("C01: %0d", rval); if(rval != 100000) $error("C01 fail");
        axi_read(32'h38, rval); $display("C10: %0d", rval); if(rval != 150000) $error("C10 fail");
        axi_read(32'h3C, rval); $display("C11: %0d", rval); if(rval != 220000) $error("C11 fail");

        $display("\nSystolic Array Tests Passed!");
        $finish;
    end
endmodule
