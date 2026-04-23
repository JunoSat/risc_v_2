// =============================================================================
// TB6 C Program: Full Integration Test (RV32IM + CORDIC + Systolic)
// NOTE: FPU excluded due to known FCVT pipeline stall issue
// =============================================================================
#include <stdint.h>
#include "tb_common.h"

#define CORDIC_ANGLE  ((volatile int32_t*) 0x40000000)
#define CORDIC_STATUS ((volatile int32_t*) 0x40000004)
#define CORDIC_SINE   ((volatile int32_t*) 0x40000008)
#define CORDIC_COSINE ((volatile int32_t*) 0x4000000C)

#define SYS_WEIGHT_BASE ((volatile int32_t*) 0x50000000)
#define SYS_ACT_BASE    ((volatile int32_t*) 0x50000040)
#define SYS_STEP        ((volatile int32_t*) 0x50000050)
#define SYS_OUT_BASE    ((volatile int32_t*) 0x50000060)

int main() {
    // Phase 1: CPU health (RV32IM)
    volatile int a = 15, b = 25;
    volatile int sum = a + b;
    volatile int prod = a * b;
    volatile int quot = prod / sum;
    if (sum != 40 || prod != 375 || quot != 9) { tb_fail(100); while(1); }
    tb_pass(1);

    // Phase 2: CORDIC - sin(PI/4) ≈ 0.7071
    *CORDIC_ANGLE = 0x0C90FDAB;
    while (*CORDIC_STATUS == 0);
    int32_t sin_val = *CORDIC_SINE;
    int32_t sin_err = (sin_val > 0x0B504F33) ? (sin_val - 0x0B504F33) : (0x0B504F33 - sin_val);
    if (sin_err > 16) { tb_fail(200); while(1); }
    tb_pass(2);

    // Phase 3: Systolic - Identity × [3,6,9,12]
    for (int r = 0; r < 4; r++)
        for (int c = 0; c < 4; c++)
            SYS_WEIGHT_BASE[r*4 + c] = (r == c) ? 1 : 0;
    SYS_ACT_BASE[0] = 3;  SYS_ACT_BASE[1] = 6;
    SYS_ACT_BASE[2] = 9;  SYS_ACT_BASE[3] = 12;
    *SYS_STEP = 1;
    SYS_ACT_BASE[0] = 0; SYS_ACT_BASE[1] = 0;
    SYS_ACT_BASE[2] = 0; SYS_ACT_BASE[3] = 0;
    for (int i = 0; i < 6; i++) *SYS_STEP = 1;
    if (SYS_OUT_BASE[0] != 3 || SYS_OUT_BASE[1] != 6 ||
        SYS_OUT_BASE[2] != 9 || SYS_OUT_BASE[3] != 12) { tb_fail(300); while(1); }
    tb_pass(3);

    // Phase 4: Second CORDIC to verify back-to-back
    *CORDIC_ANGLE = 0x1921FB54; // PI/2
    while (*CORDIC_STATUS == 0);
    sin_val = *CORDIC_SINE;
    sin_err = (sin_val > 0x10000000) ? (sin_val - 0x10000000) : (0x10000000 - sin_val);
    if (sin_err > 16) { tb_fail(400); while(1); }
    tb_pass(4);

    // ALL PASS
    tb_done();
    while(1);
    return 0;
}
