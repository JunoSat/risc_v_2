`timescale 1ns/1ps
// =============================================================================
// TB4: CORDIC via Processor
// Waits for sentinel 0x600D at DMEM[1024]. If reached, ALL C tests passed.
// =============================================================================
module tb4_cordic_processor;
    wire clk, reset_n;
    soc_harness SOC_H (.clk(clk), .reset_n(reset_n));

    integer fd, timeout;

    initial begin
        fd = $fopen("results/tb4_cordic_processor.txt", "w");
        $fwrite(fd, "=== TB4: CORDIC via Processor ===\n");
        $fwrite(fd, "Tests: angle=0, PI/2, PI/4, -PI/2, PI/6 (Q4.28 fixed-point)\n\n");
        $display("=== TB4: CORDIC via Processor ===");

        SOC_H.clk = 0; SOC_H.reset_n = 0;
        #100; SOC_H.reset_n = 1;
        force SOC_H.SOC.cpu_reset = SOC_H.reset_n;
        timeout = 0;

        while (timeout < 2000000) begin
            @(posedge clk);
            timeout = timeout + 1;

            if (SOC_H.SOC.DMEM.dmem[1024] == 32'h600D) begin
                $display("[PASS] All 5 CORDIC angle tests passed (cycle %0d)", timeout);
                $fwrite(fd, "[PASS] All 5 CORDIC angle tests passed (cycle %0d)\n", timeout);
                $fwrite(fd, "  - angle=0:     sin=0, cos=1       OK\n");
                $fwrite(fd, "  - angle=PI/2:  sin=1, cos=0       OK\n");
                $fwrite(fd, "  - angle=PI/4:  sin=cos=0.7071     OK\n");
                $fwrite(fd, "  - angle=-PI/2: sin=-1, cos=0      OK\n");
                $fwrite(fd, "  - angle=PI/6:  sin=0.5, cos=0.866 OK\n");
                $fwrite(fd, "\n=== TB4 COMPLETE: ALL TESTS PASSED ===\n");
                $fclose(fd); $finish;
            end
        end
        $display("[FAIL] TB4 TIMEOUT - sentinel not reached");
        $fwrite(fd, "[FAIL] TIMEOUT - sentinel 0x600D not reached in %0d cycles\n", timeout);
        $fwrite(fd, "Last DMEM[1024] = 0x%h\n", SOC_H.SOC.DMEM.dmem[1024]);
        $fclose(fd); $finish;
    end
endmodule
