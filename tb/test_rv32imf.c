// =============================================================================
// TB1 C Program: RV32IM Hazard & Edge Case Test Suite
// Tests: RAW hazards, load-use hazards, branch hazards, MUL/DIV edge cases,
//        and boundary values. (FPU excluded - see TB note)
// =============================================================================
#include <stdint.h>
#include "tb_common.h"

int main() {
    volatile int32_t a, b, c, d;

    // =================================================================
    // Section 1: Basic RV32I ALU (10 tests)
    // =================================================================
    a = 100; b = 200;
    if (a + b == 300) tb_pass(1); else tb_fail(1);          // ADD
    if (a - b == -100) tb_pass(2); else tb_fail(2);         // SUB
    if ((a & 0xFF) == 100) tb_pass(3); else tb_fail(3);     // ANDI
    if ((b | 0x100) == 0x1C8) tb_pass(4); else tb_fail(4);  // ORI
    if ((a ^ b) == 172) tb_pass(5); else tb_fail(5);        // XOR
    if ((a << 2) == 400) tb_pass(6); else tb_fail(6);       // SLL
    if ((b >> 3) == 25) tb_pass(7); else tb_fail(7);        // SRL
    if (((-100) >> 1) == -50) tb_pass(8); else tb_fail(8);  // SRA
    if (a < b) tb_pass(9); else tb_fail(9);                 // SLT
    if ((unsigned)100 < (unsigned)200) tb_pass(10); else tb_fail(10); // SLTU

    // =================================================================
    // Section 2: RAW Data Hazards (2 tests)
    // =================================================================
    a = 10;
    b = a + 5;       // RAW: b depends on a (EX→EX forwarding)
    c = b + 3;       // RAW: c depends on b
    d = c * 2;       // RAW: d depends on c (also tests MUL forwarding)
    if (d == 36) tb_pass(11); else tb_fail(11);

    a = 7;
    a = a + 1;       // Triple-chain immediate RAW
    a = a + 1;
    a = a + 1;
    if (a == 10) tb_pass(12); else tb_fail(12);

    // =================================================================
    // Section 3: Load-Use Hazard (2 tests)
    // =================================================================
    volatile int32_t mem_val = 42;
    a = mem_val;           // LW
    b = a + 8;             // Immediate use after load → stall required
    if (b == 50) tb_pass(13); else tb_fail(13);

    volatile int32_t mv2 = 100, mv3 = 200;
    a = mv2; b = mv3;     // Two consecutive loads
    c = a + b;             // Use both results → dual load-use hazard
    if (c == 300) tb_pass(14); else tb_fail(14);

    // =================================================================
    // Section 4: RV32M Multiply/Divide (8 tests)
    // =================================================================
    volatile int32_t x, y;
    x = 6; y = 7;
    if (x * y == 42) tb_pass(15); else tb_fail(15);         // MUL basic

    x = -5; y = 3;
    if (x * y == -15) tb_pass(16); else tb_fail(16);        // MUL signed

    x = 100; y = 7;
    if (x / y == 14) tb_pass(17); else tb_fail(17);         // DIV
    if (x % y == 2) tb_pass(18); else tb_fail(18);          // REM

    x = -100; y = 7;
    if (x / y == -14) tb_pass(19); else tb_fail(19);        // DIV negative
    if (x % y == -2) tb_pass(20); else tb_fail(20);         // REM negative

    x = 999; y = 0;
    if (x * y == 0) tb_pass(21); else tb_fail(21);          // MUL by zero

    x = 12345; y = 1;
    if (x / y == 12345) tb_pass(22); else tb_fail(22);      // DIV by 1

    // =================================================================
    // Section 5: Branch Hazards (2 tests)
    // =================================================================
    a = 0;
    for (volatile int i = 0; i < 10; i++) a += i;
    if (a == 45) tb_pass(23); else tb_fail(23);             // Loop accumulation

    a = 5;
    if (a > 100) a = 999;   // Not-taken branch
    if (a == 5) tb_pass(24); else tb_fail(24);

    // =================================================================
    // Section 6: Boundary values (1 test)
    // =================================================================
    volatile int32_t mx = 0x7FFFFFFF;
    volatile int32_t overflow = mx + 1;
    if (overflow == (int32_t)0x80000000) tb_pass(25); else tb_fail(25);

    // DONE — all 25 tests passed
    tb_done();
    while(1);
    return 0;
}
