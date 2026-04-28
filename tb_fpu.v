`timescale 1ns/1ps

module tb_fpu;
    reg clk;
    reg reset;
    
    reg [31:0] a;
    reg [31:0] b;
    reg [4:0]  funct5;
    reg [2:0]  funct3;
    reg [4:0]  rs2_sel;
    reg        fp_en;
    
    wire [31:0] result;
    wire        stall_fpu;
    wire        fpu_exception;
    
    fpu uut (
        .clk(clk),
        .reset(reset),
        .a(a),
        .b(b),
        .funct5(funct5),
        .funct3(funct3),
        .rs2_sel(rs2_sel),
        .fp_en(fp_en),
        .result(result),
        .stall_fpu(stall_fpu),
        .fpu_exception(fpu_exception)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test procedure
    initial begin
        $dumpfile("fpu_wave.vcd");
        $dumpvars(0, tb_fpu);
        
        reset = 0;
        fp_en = 0;
        a = 0;
        b = 0;
        funct5 = 0;
        funct3 = 0;
        rs2_sel = 0;
        
        #20;
        reset = 1;
        #20;
        
        $monitor("Time=%0t state=%0d iter_count=%0d iter_acc=%x div_upper=%x div_shifted=%x sub_ok=%b mant_res=%x exp_res=%0d", 
                 $time, uut.state, uut.iter_count, uut.iter_acc, uut.div_upper, uut.div_shifted, uut.div_sub_ok, uut.mant_res, uut.exp_res);
        
        $display("\n--- Testing FCVT.W.S (Float to Int) ---");
        // Float 5.25 is 0x40A80000. Expected Int: 5
        a = 32'h40A80000;
        funct5 = 5'b11000;
        fp_en = 1;
        #10;
        $display("Float: 0x%h -> Int: %0d (0x%h)", a, $signed(result), result);
        
        // Float -5.25 is 0xC0A80000. Expected Int: -5
        a = 32'hC0A80000;
        #10;
        $display("Float: 0x%h -> Int: %0d (0x%h)", a, $signed(result), result);
        
        $display("\n--- Testing FCVT.S.W (Int to Float) ---");
        // Int 12. Expected Float 12.0 = 0x41400000
        a = 32'd12;
        funct5 = 5'b11010;
        rs2_sel = 5'b00000; // Signed int
        #10;
        $display("Int: %0d -> Float: 0x%h", $signed(a), result);

        // Int -12. Expected Float -12.0 = 0xC1400000
        a = -32'sd12;
        funct5 = 5'b11010;
        rs2_sel = 5'b00000; // Signed int
        #10;
        $display("Int: %0d -> Float: 0x%h", $signed(a), result);
        
        $display("\n--- Testing FSGNJN.S (Float Negate) ---");
        // a = 5.25 (0x40A80000), b = 5.25. Expected -5.25 = 0xC0A80000
        a = 32'h40A80000;
        b = 32'h40A80000;
        funct5 = 5'b00100;
        funct3 = 3'b001; // FSGNJN.S
        #10;
        $display("Negate: 0x%h -> 0x%h", a, result);
        
        $display("\n--- Testing FDIV.S (Float Division) ---");
        // a = 3.50 (0x40600000), b = 0.50 (0x3F000000). Expected 7.0 = 0x40E00000
        a = 32'h40600000;
        b = 32'h3F000000;
        funct5 = 5'b00011; // FDIV_S
        fp_en = 1;
        #5; // Wait a half cycle for stall to assert
        wait(!stall_fpu);
        #5; // Wait for result to settle on DONE_STATE
        $display("3.50 / 0.50 = 0x%h", result);
        fp_en = 0;
        #10;
        
        $display("\n--- Testing FDIV.S (Divide by Zero) ---");
        // a = 3.50, b = 0.0. Expected Infinity = 0x7F800000
        a = 32'h40600000;
        b = 32'h00000000;
        fp_en = 1;
        #5;
        wait(!stall_fpu);
        #5;
        $display("3.50 / 0.00 = 0x%h", result);
        fp_en = 0;
        
        $finish;
    end
endmodule
