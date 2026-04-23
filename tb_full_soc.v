`timescale 1ns/1ps

module tb_full_soc;
    reg clk;
    reg reset;

    wire uart_tx;
    wire [15:0] led;

    // AXI Bus interface wires
    wire [31:0] m_axi_awaddr;
    wire [2:0]  m_axi_awprot;
    wire        m_axi_awvalid;
    wire        m_axi_awready;
    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wvalid;
    wire        m_axi_wready;
    wire [1:0]  m_axi_bresp;
    wire        m_axi_bvalid;
    wire        m_axi_bready;
    
    wire [31:0] m_axi_araddr;
    wire [2:0]  m_axi_arprot;
    wire        m_axi_arvalid;
    wire        m_axi_arready;
    wire [31:0] m_axi_rdata;
    wire [1:0]  m_axi_rresp;
    wire        m_axi_rvalid;
    wire        m_axi_rready;

    // Instance of our RISC-V Multi-Cored SoC Architecture
    top_fpga SOC_CORE (
        .clk(clk),
        .reset(reset),
        .uart_rx(1'b1), // Keep UART Rx idle natively so bootloader exits or waits safely
        .uart_tx(uart_tx),
        .led(led)
    );

    // Instance of our AXI CORDIC Math Accelerator Node
    axi_cordic_slave HW_ACCEL (
        .clk(clk),
        .reset(reset),
        
        .s_axi_awaddr(m_axi_awaddr),
        .s_axi_awprot(m_axi_awprot),
        .s_axi_awvalid(m_axi_awvalid),
        .s_axi_awready(m_axi_awready),
        .s_axi_wdata(m_axi_wdata),
        .s_axi_wstrb(m_axi_wstrb),
        .s_axi_wvalid(m_axi_wvalid),
        .s_axi_wready(m_axi_wready),
        .s_axi_bresp(m_axi_bresp),
        .s_axi_bvalid(m_axi_bvalid),
        .s_axi_bready(m_axi_bready),
        
        .s_axi_araddr(m_axi_araddr),
        .s_axi_arprot(m_axi_arprot),
        .s_axi_arvalid(m_axi_arvalid),
        .s_axi_arready(m_axi_arready),
        .s_axi_rdata(m_axi_rdata),
        .s_axi_rresp(m_axi_rresp),
        .s_axi_rvalid(m_axi_rvalid),
        .s_axi_rready(m_axi_rready)
    );

    always #5 clk = ~clk;

    // --- SIMULATION UART RECEIVER ---
    // Decodes the uart_tx pin and prints to the terminal
    reg [7:0] rx_byte;
    reg [31:0] baud_count;
    reg [3:0] bit_count;
    reg rx_active = 0;
    
    always @(posedge clk) begin
        if (reset) begin 
            // Wait for start bit (tx drops to 0)
            if (!rx_active && uart_tx == 0) begin
                rx_active <= 1;
                baud_count <= 434; // Wait half a bit period to sample center (868 / 2)
                bit_count <= 0;
            end else if (rx_active) begin
                if (baud_count == 0) begin
                    baud_count <= 868; // Reset for next full bit period
                    if (bit_count == 8) begin
                        rx_active <= 0;
                        $write("%c", rx_byte); // Print the character!
                    end else begin
                        rx_byte <= {uart_tx, rx_byte[7:1]}; // Shift in data
                        bit_count <= bit_count + 1;
                    end
                end else begin
                    baud_count <= baud_count - 1;
                end
            end
        end
    end

    // PC Monitor - print PC every 10000 ns (1000 cycles)
    always @(posedge clk) begin
        if ($time % 100000 == 5000)
            $display("[PC] Time %t | PC=%h | cordic_busy=%b systolic_busy=%b | CORDIC_state=%0d SYS_state=%0d",
                $time,
                SOC_CORE.current_pc,
                SOC_CORE.cordic_busy,
                SOC_CORE.systolic_busy,
                SOC_CORE.axi_master_inst.state,
                SOC_CORE.axi_master_systolic_inst.state);
    end

    // Monitor CORDIC slave to detect when it starts/completes
    always @(posedge clk) begin
        if (SOC_CORE.axi_master_inst.state == 1 && SOC_CORE.axi_master_inst.m_axi_awvalid)
            $display("[CORDIC-WRITE] Time %t | Addr=%h Data=%h", $time, 
                SOC_CORE.axi_master_inst.m_axi_awaddr, SOC_CORE.axi_master_inst.m_axi_wdata);
        if (SOC_CORE.axi_master_inst.state == 3 && SOC_CORE.axi_master_inst.m_axi_arvalid)
            $display("[CORDIC-READ]  Time %t | Addr=%h", $time, SOC_CORE.axi_master_inst.m_axi_araddr);
        if (SOC_CORE.axi_master_inst.state == 4 && SOC_CORE.m_axi_rvalid)
            $display("[CORDIC-RDATA] Time %t | Data=%h", $time, SOC_CORE.m_axi_rdata);
    end

    // Monitor logic to cleanly print when internal Systolic AXI traffic is happening
    always @(posedge clk) begin
        if (SOC_CORE.sys_awvalid && SOC_CORE.sys_awready) begin
            $display("[SYS-WRITE Req] Time %t | Addr: %h, Data: %d", $time, SOC_CORE.sys_awaddr, SOC_CORE.sys_wdata);
        end
        if (SOC_CORE.sys_arvalid && SOC_CORE.sys_arready) begin
            $display("[SYS-READ Req]  Time %t | Addr: %h", $time, SOC_CORE.sys_araddr);
        end
        if (SOC_CORE.sys_rvalid && SOC_CORE.sys_rready) begin
            $display("[SYS-READ Done] Time %t | Returning Data: %d", $time, SOC_CORE.sys_rdata_in);
        end
    end

    // Cycle counter for monitoring
    integer cycle_cnt;
    always @(posedge clk) begin
        if (!reset) cycle_cnt <= 0;
        else cycle_cnt <= cycle_cnt + 1;
    end

    // PC Monitor - print every 200,000 cycles
    always @(posedge clk) begin
        if (reset && (cycle_cnt % 200000 == 0))
            $display("[PC] cycle=%0d | PC=%h | cordic_busy=%b sys_busy=%b | CORDIC_st=%0d SYS_st=%0d",
                cycle_cnt,
                SOC_CORE.current_pc,
                SOC_CORE.cordic_busy,
                SOC_CORE.systolic_busy,
                SOC_CORE.axi_master_inst.state,
                SOC_CORE.axi_master_systolic_inst.state);
    end

    // Monitor CORDIC slave to detect when it starts/completes
    always @(posedge clk) begin
        if (SOC_CORE.axi_master_inst.state == 1 && SOC_CORE.axi_master_inst.m_axi_awvalid)
            $display("[CORDIC-WRITE] cycle=%0d | Addr=%h Data=%h", cycle_cnt,
                SOC_CORE.axi_master_inst.m_axi_awaddr, SOC_CORE.axi_master_inst.m_axi_wdata);
        if (SOC_CORE.axi_master_inst.state == 3 && SOC_CORE.axi_master_inst.m_axi_arvalid)
            $display("[CORDIC-READ]  cycle=%0d | Addr=%h", cycle_cnt, SOC_CORE.axi_master_inst.m_axi_araddr);
        if (SOC_CORE.axi_master_inst.state == 4 && SOC_CORE.m_axi_rvalid)
            $display("[CORDIC-RDATA] cycle=%0d | Data=%h", cycle_cnt, SOC_CORE.m_axi_rdata);
    end

    // Monitor logic to cleanly print when internal Systolic AXI traffic is happening
    always @(posedge clk) begin
        if (SOC_CORE.sys_awvalid && SOC_CORE.sys_awready)
            $display("[SYS-WRITE] cycle=%0d | Addr=%h Data=%d", cycle_cnt, SOC_CORE.sys_awaddr, SOC_CORE.sys_wdata);
        if (SOC_CORE.sys_rvalid && SOC_CORE.sys_rready)
            $display("[SYS-READ]  cycle=%0d | Addr=%h Data=%d", cycle_cnt, SOC_CORE.sys_araddr, SOC_CORE.sys_rdata_in);
    end

    initial begin
        clk = 0;
        reset = 0;
        cycle_cnt = 0;
        
        // Assert Reset
        #50 reset = 1;
        
        // Bypass bootloader wait state for pure Verilog testbenches (since imem.hex is pre-loaded by the synth)
        force SOC_CORE.cpu_reset = reset;
        
        // UART delay is 15000 cycles/char. First string is ~32 chars = 480,000 cycles.
        // 4 CORDIC tests + Systolic = ~2M cycles total. 30ms @ 10ns/clk = 3,000,000 cycles.
        #30000000;
        $display("Sim ended at cycle=%0d", cycle_cnt);
        $finish;
    end
endmodule

