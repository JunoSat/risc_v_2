`timescale 1ns/1ps
// =============================================================================
// TB1: RV32IM Hazard & Edge Case Test via Processor
// Loads test_rv32imf.c hex, runs the CPU, monitors TB_RESULT in DMEM.
// =============================================================================
module tb1_rv32imf_hazards;
    wire clk, reset_n;

    soc_harness SOC_H (.clk(clk), .reset_n(reset_n));

    integer fd;
    integer timeout;
    integer highest_pass;
    reg [31:0] last_val;

    initial begin
        fd = $fopen("results/tb1_rv32imf_hazards.txt", "w");
        $fwrite(fd, "=== TB1: RV32IM Hazard & Edge Case via Processor ===\n\n");
        $display("=== TB1: RV32IM Hazard & Edge Case via Processor ===");

        SOC_H.clk = 0;
        SOC_H.reset_n = 0;
        #100;
        SOC_H.reset_n = 1;
        force SOC_H.SOC.cpu_reset = SOC_H.reset_n;

        highest_pass = 0;
        last_val = 0;
        timeout = 0;

        while (timeout < 2000000) begin
            @(posedge clk);
            timeout = timeout + 1;

            // TB_RESULT at DMEM[1024] (address 0x1000)
            if (SOC_H.SOC.DMEM.dmem[1024] !== last_val) begin
                last_val = SOC_H.SOC.DMEM.dmem[1024];

                if (last_val == 32'h600D) begin
                    $display("[PASS] All tests completed (sentinel 0x600D at cycle %0d)", timeout);
                    $fwrite(fd, "[PASS] All tests completed (sentinel 0x600D at cycle %0d)\n", timeout);
                    $fwrite(fd, "\nHighest sequential test passed: %0d\n", highest_pass);
                    $fwrite(fd, "\n=== TB1 COMPLETE: ALL TESTS PASSED ===\n");
                    $display("=== TB1 COMPLETE (highest pass: %0d) ===", highest_pass);
                    $fclose(fd);
                    $finish;
                end else if (last_val > 0 && last_val < 100 && !last_val[31]) begin
                    // Valid positive test ID (1-99)
                    $display("[PASS] Test %0d", last_val);
                    $fwrite(fd, "[PASS] Test %0d\n", last_val);
                    if (last_val > highest_pass) highest_pass = last_val;
                end else if (last_val[31] && $signed(last_val) > -100) begin
                    // Valid negative test ID (FAIL)
                    $display("[FAIL] Test %0d", -$signed(last_val));
                    $fwrite(fd, "[FAIL] Test %0d\n", -$signed(last_val));
                end
                // Anything else (compiler spill) is silently ignored
            end
        end

        $display("=== TB1 TIMEOUT (last=0x%h, highest_pass=%0d) ===", last_val, highest_pass);
        $fwrite(fd, "\n=== TB1 TIMEOUT (last=0x%h, highest_pass=%0d) ===\n", last_val, highest_pass);
        $fclose(fd);
        $finish;
    end
endmodule
