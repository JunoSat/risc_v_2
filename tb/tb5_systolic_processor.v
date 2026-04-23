`timescale 1ns/1ps
// =============================================================================
// TB5: Systolic Array via Processor
// Waits for sentinel 0x600D at DMEM[1024]. If reached, ALL C tests passed.
// =============================================================================
module tb5_systolic_processor;
    wire clk, reset_n;
    soc_harness SOC_H (.clk(clk), .reset_n(reset_n));

    integer fd, timeout;

    initial begin
        fd = $fopen("results/tb5_systolic_processor.txt", "w");
        $fwrite(fd, "=== TB5: Systolic Array via Processor ===\n");
        $fwrite(fd, "Tests: Identity*[10,20,30,40], All-2s*[1,1,1,1], Zeros*[5,10,15,20]\n\n");
        $display("=== TB5: Systolic Array via Processor ===");

        SOC_H.clk = 0; SOC_H.reset_n = 0;
        #100; SOC_H.reset_n = 1;
        force SOC_H.SOC.cpu_reset = SOC_H.reset_n;
        timeout = 0;

        while (timeout < 2000000) begin
            @(posedge clk);
            timeout = timeout + 1;

            if (SOC_H.SOC.DMEM.dmem[1024] == 32'h600D) begin
                $display("[PASS] All 3 systolic tests passed (cycle %0d)", timeout);
                $fwrite(fd, "[PASS] All 3 systolic tests passed (cycle %0d)\n", timeout);
                $fwrite(fd, "  - Identity * [10,20,30,40] = [10,20,30,40] OK\n");
                $fwrite(fd, "  - All-2s  * [1,1,1,1]      = [8,8,8,8]    OK\n");
                $fwrite(fd, "  - Zeros   * [5,10,15,20]   = [0,0,0,0]    OK\n");
                $fwrite(fd, "\n=== TB5 COMPLETE: ALL TESTS PASSED ===\n");
                $fclose(fd); $finish;
            end
        end
        $display("[FAIL] TB5 TIMEOUT - sentinel not reached");
        $fwrite(fd, "[FAIL] TIMEOUT - sentinel 0x600D not reached in %0d cycles\n", timeout);
        $fwrite(fd, "Last DMEM[1024] = 0x%h\n", SOC_H.SOC.DMEM.dmem[1024]);
        $fclose(fd); $finish;
    end
endmodule
