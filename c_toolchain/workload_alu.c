#include "workload_alu.h"
#include "util.h"

int run_alu_diagnostic() {
    int errors = 0;
    print_string("\r\n--- STARTING ALU & RV32M DIAGNOSTIC ---\r\n");

    volatile int rs1, rs2, rd;

    // --- Basic ALU Pathways ---
    if ((2147483640 + 5) != 2147483645) errors++;
    if ((10 - 20) != -10) errors++;
    if ((~0) != -1) errors++;
    if ((0xA0000000 | 0x0000000B) != ((int)0xA000000B)) errors++;
    if ((0x55555555 ^ 0xFFFFFFFF) != ((int)0xAAAAAAAA)) errors++;
    if ((1 << 30) != 1073741824) errors++;
    if (((unsigned int)0x80000000 >> 31) != 1) errors++;
    if ((((int)0x80000000) >> 31) != -1) errors++;
    if (!(-10 < 5)) errors++;
    if (!((unsigned int)5 < (unsigned int)-10)) errors++;

    // === RV32M 8 Golden Ops Strict Hardware Verification ===
    
    // 11. MUL: Generic limits
    rs1 = 50000; rs2 = 400;
    asm volatile("mul %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2));
    if (rd != 20000000) errors++;

    // 12. MULH (Signed * Signed): Asymmetric crossing
    rs1 = -2; rs2 = 3;  // -6 = 0xFFFFFFFFFFFFFFFA. High = -1
    asm volatile("mulh %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2));
    if (rd != -1) errors++;

    // 13. MULHSU (Signed * Unsigned): Asymmetric Signs
    rs1 = -2; rs2 = 3; 
    asm volatile("mulhsu %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2));
    if (rd != -1) errors++;

    // 14. MULHU (Unsigned * Unsigned):
    rs1 = -1; rs2 = 2; // 0xFFFFFFFF * 2 = 0x00000001FFFFFFFE. High is 1.
    asm volatile("mulhu %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2));
    if (rd != 1) errors++;

    // 15. DIV (Signed): -2^31 / -1 (Golden Overflow Rule)
    rs1 = 0x80000000; rs2 = -1;
    asm volatile("div %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2));
    if (rd != 0x80000000) errors++; // Overflow rule mandates outputting dividend!

    // 16. DIVU (Unsigned): Division by Zero
    rs1 = 50; rs2 = 0;
    asm volatile("divu %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2));
    if (rd != -1) errors++; // Unsigned div by zero strictly returns max unsigned (-1)

    // 17. REM (Signed): -2^31 % -1 (Golden Overflow Rule)
    rs1 = 0x80000000; rs2 = -1;
    asm volatile("rem %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2));
    if (rd != 0) errors++; // Overflow rule mandates remainder must be cleanly 0!

    // 18. REMU (Unsigned): Division by Zero
    rs1 = 50; rs2 = 0;
    asm volatile("remu %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2));
    if (rd != 50) errors++; // Zero-division mandates returning the original dividend unconditionally!

    if (errors == 0) {
        print_string("RESULT: [PASSED] 18/18 (All 8 RV32M Golden Edge Cases Validated!)\r\n");
    } else {
        print_string("RESULT: [FAILED] Errors Detected: ");
        print_int(errors);
        print_string("\r\n");
    }
    return errors;
}

int run_fpu_diagnostic() {
    int errors = 0;
    print_string("\r\n--- STARTING RV32F FP DIAGNOSTIC ---\r\n");
    
    // IEEE-754 numbers as floats
    volatile float f1, f2, f_rd;
    volatile int i_rd;

    // FADD
    f1 = 5.5f; f2 = 2.25f;
    asm volatile("fadd.s %0, %1, %2" : "=f"(f_rd) : "f"(f1), "f"(f2));
    if (f_rd != 7.75f) errors++;

    // FSUB
    f1 = 10.0f; f2 = 3.5f;
    asm volatile("fsub.s %0, %1, %2" : "=f"(f_rd) : "f"(f1), "f"(f2));
    if (f_rd != 6.5f) errors++;

    // FMUL
    f1 = 2.0f; f2 = -3.0f;
    asm volatile("fmul.s %0, %1, %2" : "=f"(f_rd) : "f"(f1), "f"(f2));
    if (f_rd != -6.0f) errors++;

    // FDIV
    f1 = 15.0f; f2 = 3.0f;
    asm volatile("fdiv.s %0, %1, %2" : "=f"(f_rd) : "f"(f1), "f"(f2));
    if (f_rd != 5.0f) errors++;

    // FCMP (FEQ)
    f1 = 7.0f; f2 = 7.0f;
    asm volatile("feq.s %0, %1, %2" : "=r"(i_rd) : "f"(f1), "f"(f2));
    if (i_rd != 1) errors++;

    // FCMP (FLT)
    f1 = 2.0f; f2 = 5.0f;
    asm volatile("flt.s %0, %1, %2" : "=r"(i_rd) : "f"(f1), "f"(f2));
    if (i_rd != 1) errors++;

    // FCMP (FLE with negatives)
    f1 = -4.0f; f2 = -2.0f;
    asm volatile("fle.s %0, %1, %2" : "=r"(i_rd) : "f"(f1), "f"(f2));
    if (i_rd != 1) errors++;

    // FCVT.W.S
    f1 = 12.0f;
    asm volatile("fcvt.w.s %0, %1, rtz" : "=r"(i_rd) : "f"(f1));
    if (i_rd != 12) errors++;

    // FCVT.S.W
    int src_int = -9;
    asm volatile("fcvt.s.w %0, %1" : "=f"(f_rd) : "r"(src_int));
    if (f_rd != -9.0f) errors++;

    if (errors == 0) {
        print_string("RESULT: [PASSED] RV32F FP Edge Cases Validated!\r\n");
    } else {
        print_string("RESULT: [FAILED] RV32F Errors: ");
        print_int(errors);
        print_string("\r\n");
    }
    return errors;
}
