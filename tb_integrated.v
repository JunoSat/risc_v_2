`timescale 1ns / 1ps

module tb_integrated;

    reg clk;
    reg reset;

    // 100 MHz clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // reset (active low in our CPU)
    initial begin
        reset = 0;
        #105;
        reset = 1;
    end

    // Instantiate Hardware Top Level
    top_fpga #(
        .IMEMSIZE(8192),
        .DMEMSIZE(8192),
        .BAUD_RATE(115200)
    ) DUT (
        .clk(clk),
        .reset(reset),
        .uart_rx(1'b1),
        .uart_tx(),
        .led()
    );

    wire cpu_clk = DUT.cpu_clk;
    wire cpu_reset = DUT.cpu_reset;

    // Force removed

    // Direct access to pipeline stages for visibility
    wire [4:0]  wb_rd          = DUT.pipe_u.u_mem_wb_reg.dest_reg_sel_o;
    wire [31:0] wb_result      = DUT.pipe_u.u_wb_stage.wb_result_o;
    wire        wb_alu_to_reg  = DUT.pipe_u.u_mem_wb_reg.alu_to_reg_o;
    wire        wb_fp_reg_write= DUT.pipe_u.u_mem_wb_reg.fp_reg_write_o;
    wire [31:0] if_pc          = DUT.pipe_u.if_pc_out;
    wire        stall          = DUT.pipe_u.stall_if_haz | DUT.pipe_u.stall_id_haz | DUT.pipe_u.stall_ex_haz | DUT.pipe_u.stall;
    wire        flush_ex       = DUT.pipe_u.flush_ex_haz;

    // Removed manual IMEM seeding to permit memory module $readmemh functionality.

    reg [31:0] print_pc = 32'hFFFFFFFF;
    reg stall_prev = 1'b0;
    always @(posedge cpu_clk) begin
        if (cpu_reset) begin
            if (if_pc != print_pc) begin
                // $display("[Time %0t] Fetching PC 0x%08h", $time, if_pc);
                print_pc <= if_pc;
            end
            if (stall != stall_prev) begin
                // $display("[Time %0t] Stall changed to %0b (PC: 0x%08h)", $time, stall, if_pc);
                stall_prev <= stall;
            end
        end
    end

    reg [31:0] cycle_count = 0;
    always @(posedge cpu_clk) begin
        if (cpu_reset) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count % 10000 == 0) begin
                $display("[Time %0t] Alive, PC: 0x%08h", $time, if_pc);
            end
            
            if (DUT.axi_uart_inst.UART_INST.tx_start) begin
                $write("%c", DUT.axi_uart_inst.UART_INST.tx_data);
            end
        end
    end

    initial begin
        #2000000000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
