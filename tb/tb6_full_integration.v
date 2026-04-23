`timescale 1ns/1ps
// =============================================================================
// TB6: Full Integration (CPU + CORDIC + Systolic)
// Waits for sentinel 0x600D at DMEM[1024]. If reached, ALL phases passed.
// =============================================================================
module tb6_full_integration;
    wire clk, reset_n;
    soc_harness SOC_H (.clk(clk), .reset_n(reset_n));

    integer fd, timeout;

    initial begin
        fd = $fopen("results/tb6_full_integration.txt", "w");
        $fwrite(fd, "=== TB6: Full Integration (CPU + CORDIC + Systolic) ===\n");
        $fwrite(fd, "Phases: 1=RV32IM CPU, 2=FPU, 3=CORDIC, 4=Systolic\n\n");
        $display("=== TB6: Full Integration ===");

        SOC_H.clk = 0; SOC_H.reset_n = 0;
        #100; SOC_H.reset_n = 1;
        force SOC_H.SOC.cpu_reset = SOC_H.reset_n;
        timeout = 0;

        while (timeout < 2000000) begin
            @(posedge clk);
            timeout = timeout + 1;

            if (SOC_H.SOC.DMEM.dmem[1024] == 32'h600D) begin
                $display("[PASS] ALL PHASES PASSED (cycle %0d)", timeout);
                $fwrite(fd, "[PASS] ALL 4 PHASES PASSED (cycle %0d)\n", timeout);
                $fwrite(fd, "  Phase 1: RV32IM arithmetic (add/mul/div)   OK\n");
                $fwrite(fd, "  Phase 2: FPU (float multiply)              OK\n");
                $fwrite(fd, "  Phase 3: CORDIC sin(PI/4) = 0.7071         OK\n");
                $fwrite(fd, "  Phase 4: Systolic Identity*[3,6,9,12]      OK\n");
                $fwrite(fd, "\n=== TB6 COMPLETE: FULL INTEGRATION PASSED ===\n");
                $fclose(fd); $finish;
            end
        end
        $display("[FAIL] TB6 TIMEOUT - sentinel not reached");
        $fwrite(fd, "[FAIL] TIMEOUT - sentinel 0x600D not reached in %0d cycles\n", timeout);
        $fwrite(fd, "Last DMEM[1024] = 0x%h\n", SOC_H.SOC.DMEM.dmem[1024]);
        $fclose(fd); $finish;
    end
endmodule
