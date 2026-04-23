`timescale 1ns/1ps
// =============================================================================
// TB2: Standalone CORDIC Testbench
// Tests the cordic_iterative module directly with known angles.
// No processor - just drives inputs and checks outputs.
// =============================================================================
module tb2_cordic_standalone;
    reg clk, reset, start;
    reg [31:0] target_angle;
    wire valid_out;
    wire [31:0] sin_out, cos_out;

    cordic_iterative UUT (
        .clk(clk), .reset(reset), .start(start),
        .target_angle(target_angle),
        .valid_out(valid_out), .sin_out(sin_out), .cos_out(cos_out)
    );

    always #5 clk = ~clk;

    integer pass_count, fail_count;
    integer fd;

    task run_test;
        input [31:0] angle;
        input [31:0] exp_sin;
        input [31:0] exp_cos;
        input [255:0] label;  // fixed-width string
        input [31:0] tolerance;
        reg [31:0] sin_err, cos_err;
        begin
            @(posedge clk);
            target_angle = angle;
            start = 1;
            @(posedge clk);
            start = 0;

            wait(valid_out == 1);
            @(posedge clk); // let it latch

            // Compute absolute error (unsigned)
            sin_err = (sin_out > exp_sin) ? (sin_out - exp_sin) : (exp_sin - sin_out);
            cos_err = (cos_out > exp_cos) ? (cos_out - exp_cos) : (exp_cos - cos_out);

            if (sin_err <= tolerance && cos_err <= tolerance) begin
                $display("[PASS] %0s | sin=%h (exp %h, err=%d) | cos=%h (exp %h, err=%d)",
                         label, sin_out, exp_sin, sin_err, cos_out, exp_cos, cos_err);
                $fwrite(fd, "[PASS] %0s | sin=%h (exp %h, err=%d) | cos=%h (exp %h, err=%d)\n",
                         label, sin_out, exp_sin, sin_err, cos_out, exp_cos, cos_err);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s | sin=%h (exp %h, err=%d) | cos=%h (exp %h, err=%d)",
                         label, sin_out, exp_sin, sin_err, cos_out, exp_cos, cos_err);
                $fwrite(fd, "[FAIL] %0s | sin=%h (exp %h, err=%d) | cos=%h (exp %h, err=%d)\n",
                         label, sin_out, exp_sin, sin_err, cos_out, exp_cos, cos_err);
                fail_count = fail_count + 1;
            end

            #40; // settle between tests
        end
    endtask

    initial begin
        fd = $fopen("results/tb2_cordic_standalone.txt", "w");
        $fwrite(fd, "=== TB2: Standalone CORDIC Testbench ===\n");
        $fwrite(fd, "Format: Q4.28 fixed-point. 1.0 = 0x10000000\n\n");
        $display("=== TB2: Standalone CORDIC Testbench ===");

        clk = 0; reset = 0; start = 0; target_angle = 0;
        pass_count = 0; fail_count = 0;
        #20 reset = 1;
        #20;

        // Tolerance: allow ±16 LSBs in Q4.28 (== ±6e-8 radians)
        //                     angle          exp_sin      exp_cos      label                      tol
        run_test(32'h00000000, 32'h00000000, 32'h10000000, "angle=0            (sin=0, cos=1)", 32'd16);
        run_test(32'h1921FB54, 32'h10000000, 32'h00000000, "angle=PI/2         (sin=1, cos=0)", 32'd16);
        run_test(32'h0C90FDAB, 32'h0B504F33, 32'h0B504F33, "angle=PI/4    (sin=cos=0.7071)   ", 32'd16);
        run_test(32'hE6DE04AC, 32'hF0000000, 32'h00000000, "angle=-PI/2      (sin=-1, cos=0) ", 32'd16);
        run_test(32'hF36F0255, 32'hF4AFB0CD, 32'h0B504F33, "angle=-PI/4  (sin=-0.707,cos=0.707)", 32'd16);
        // PI/6 = 0.5236 => Q4.28 = 0x0860A91C, sin=0.5 => 0x08000000, cos=0.866 => 0x0DDB3D74
        run_test(32'h0860A91C, 32'h08000000, 32'h0DDB3D74, "angle=PI/6        (sin=0.5,cos=0.866)", 32'd32);
        // PI = 3.14159 => Q4.28 = 0x3243F6A8, sin=0, cos=-1 => 0xF0000000
        run_test(32'h3243F6A8, 32'h00000000, 32'hF0000000, "angle=PI          (sin=0, cos=-1)     ", 32'd32);
        // Small angle: 0.01 rad => Q4.28 = 0x0028F5C2, sin~=0.01 => 0x0028F5C2, cos~=1.0 => 0x10000000
        run_test(32'h0028F5C2, 32'h0028F5C0, 32'h10000000, "angle=0.01rad (small angle)       ", 32'd16384);

        $display("\n=== Results: %0d PASS, %0d FAIL ===", pass_count, fail_count);
        $fwrite(fd, "\n=== Results: %0d PASS, %0d FAIL ===\n", pass_count, fail_count);
        $fclose(fd);
        #10 $finish;
    end
endmodule
