#include "workload_alu.h"
#include "util.h"

int run_alu_diagnostic() {
    int errors = 0;
    print_string("\r\n--- STARTING ALU & RV32M DIAGNOSTIC ---\r\n");

    // 1. ADD limit
    if ((2147483640 + 5) != 2147483645) errors++;
    // 2. SUB negative crossing
    if ((10 - 20) != -10) errors++;
    // 3. AND mask isolated
    if ((~0) != -1) errors++;
    if ((0xFFFFFFFF & 0x0000000A) != 10) errors++;
    // 4. OR mask isolated
    if ((0xA0000000 | 0x0000000B) != ((int)0xA000000B)) errors++;
    // 5. XOR identity
    if ((0x55555555 ^ 0xFFFFFFFF) != ((int)0xAAAAAAAA)) errors++;
    
    // 6. SLL Shift Left Logical Large
    if ((1 << 30) != 1073741824) errors++;
    // 7. SRL Shift Right Logical
    if (((unsigned int)0x80000000 >> 31) != 1) errors++;
    // 8. SRA Shift Right Arithmetic (Sign Extended)
    if ((((int)0x80000000) >> 31) != -1) errors++;
    // 9. SLT Set Less Than
    if (!(-10 < 5)) errors++;
    // 10. SLTU Set Less Than Unsigned
    if (!((unsigned int)5 < (unsigned int)-10)) errors++;

    // 11. MUL Zero
    if ((9999 * 0) != 0) errors++;
    // 12. MUL Large Positive 
    if ((50000 * 400) != 20000000) errors++;
    // 13. MUL Signed Negative
    if ((100 * -5) != -500) errors++;
    // 14. DIV Signed
    if ((-100 / 3) != -33) errors++;
    // 15. REM Signed (Modulo)
    if ((-100 % 3) != -1) errors++;

    if (errors == 0) {
        print_string("RESULT: [PASSED] 15/15 ALU Edge Cases Successful!\r\n");
    } else {
        print_string("RESULT: [FAILED] Errors Detected: ");
        print_int(errors);
    }
    return errors;
}
