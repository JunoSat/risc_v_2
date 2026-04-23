// =============================================================================
// TB5 C Program: Systolic Array via processor
// =============================================================================
#include <stdint.h>
#include "tb_common.h"

#define SYS_WEIGHT_BASE ((volatile int32_t*) 0x50000000)
#define SYS_ACT_BASE    ((volatile int32_t*) 0x50000040)
#define SYS_STEP        ((volatile int32_t*) 0x50000050)
#define SYS_OUT_BASE    ((volatile int32_t*) 0x50000060)

void load_weights_identity() {
    for (int r = 0; r < 4; r++)
        for (int c = 0; c < 4; c++)
            SYS_WEIGHT_BASE[r*4 + c] = (r == c) ? 1 : 0;
}

void load_weights_scalar(int32_t val) {
    for (int i = 0; i < 16; i++) SYS_WEIGHT_BASE[i] = val;
}

void feed_and_step(int32_t a0, int32_t a1, int32_t a2, int32_t a3) {
    SYS_ACT_BASE[0] = a0; SYS_ACT_BASE[1] = a1;
    SYS_ACT_BASE[2] = a2; SYS_ACT_BASE[3] = a3;
    *SYS_STEP = 1;
    SYS_ACT_BASE[0] = 0; SYS_ACT_BASE[1] = 0;
    SYS_ACT_BASE[2] = 0; SYS_ACT_BASE[3] = 0;
    for (int i = 0; i < 6; i++) *SYS_STEP = 1;
}

int check4(int32_t e0, int32_t e1, int32_t e2, int32_t e3, int test_id) {
    int32_t o0 = SYS_OUT_BASE[0], o1 = SYS_OUT_BASE[1];
    int32_t o2 = SYS_OUT_BASE[2], o3 = SYS_OUT_BASE[3];
    if (o0 == e0 && o1 == e1 && o2 == e2 && o3 == e3) {
        tb_pass(test_id); return 1;
    } else {
        tb_fail(test_id); return 0;
    }
}

int main() {
    load_weights_identity();
    feed_and_step(10, 20, 30, 40);
    check4(10, 20, 30, 40, 1);

    load_weights_scalar(2);
    feed_and_step(1, 1, 1, 1);
    check4(8, 8, 8, 8, 2);

    load_weights_scalar(0);
    feed_and_step(5, 10, 15, 20);
    check4(0, 0, 0, 0, 3);

    tb_done();
    while(1);
    return 0;
}
