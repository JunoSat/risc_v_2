// =============================================================================
// TB4 C Program: CORDIC via processor
// =============================================================================
#include <stdint.h>
#include "tb_common.h"

#define CORDIC_ANGLE  ((volatile int32_t*) 0x40000000)
#define CORDIC_STATUS ((volatile int32_t*) 0x40000004)
#define CORDIC_SINE   ((volatile int32_t*) 0x40000008)
#define CORDIC_COSINE ((volatile int32_t*) 0x4000000C)

void test_cordic(int32_t angle, int32_t exp_sin, int32_t exp_cos, int32_t tol, int test_id) {
    *CORDIC_ANGLE = angle;
    while (*CORDIC_STATUS == 0);
    int32_t s = *CORDIC_SINE;
    int32_t c = *CORDIC_COSINE;
    int32_t serr = (s > exp_sin) ? (s - exp_sin) : (exp_sin - s);
    int32_t cerr = (c > exp_cos) ? (c - exp_cos) : (exp_cos - c);
    if (serr <= tol && cerr <= tol) tb_pass(test_id);
    else tb_fail(test_id);
}

int main() {
    test_cordic(0x00000000, 0x00000000, 0x10000000, 16, 1);  // angle=0
    test_cordic(0x1921FB54, 0x10000000, 0x00000000, 16, 2);  // PI/2
    test_cordic(0x0C90FDAB, 0x0B504F33, 0x0B504F33, 16, 3);  // PI/4
    test_cordic(0xE6DE04AC, 0xF0000000, 0x00000000, 16, 4);  // -PI/2
    test_cordic(0x0860A91C, 0x08000000, 0x0DDB3D74, 32, 5);  // PI/6
    tb_done();
    while(1);
    return 0;
}
