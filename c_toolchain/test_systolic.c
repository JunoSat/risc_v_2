#include <stdint.h>

#define SYS_WEIGHT_BASE ((volatile int32_t*) 0x50000000)
#define SYS_ACT_BASE    ((volatile int32_t*) 0x50000040)
#define SYS_STEP        ((volatile int32_t*) 0x50000050)
#define SYS_OUT_BASE    ((volatile int32_t*) 0x50000060)

void c_trap_handler(unsigned int cause) { }

int main() {
    // ----------------------------------------------------
    // SYSTOLIC ARRAY AXI SUBSYSTEM TEST
    // ----------------------------------------------------
    
    // 1. Load the 16 weights (Identity Matrix)
    // 1 0 0 0
    // 0 1 0 0
    // 0 0 1 0
    // 0 0 0 1
    for (int row = 0; row < 4; row++) {
        for (int col = 0; col < 4; col++) {
            int idx = row * 4 + col;
            SYS_WEIGHT_BASE[idx] = (row == col) ? 1 : 0;
        }
    }

    // 2. We want to push 4 rows of Activations into the Array.
    // In a systolic array, to compute a 4x4 times 4x4 matrix, 
    // it requires 4x4 inputs, but they must be fed sequentially column by column.
    // For simplicity, let's just push one single column vector:
    // [10, 20, 30, 40]^T
    SYS_ACT_BASE[0] = 10;
    SYS_ACT_BASE[1] = 20;
    SYS_ACT_BASE[2] = 30;
    SYS_ACT_BASE[3] = 40;
    
    // 3. Step the array!
    // Since it's a 4x4 wavefront array, it takes exactly 4 steps for the 
    // bottom right element to see the data entering from the top-left!
    // Wait, the latency of a 4x4 systolic array is actually 2N - 1 = 7 steps!
    // So we Step it 7 times!
    for (int i = 0; i < 7; i++) {
        *SYS_STEP = 1; 
        
        // Let's clear the inputs to 0 after the first step so we don't bleed extra data in
        SYS_ACT_BASE[0] = 0;
        SYS_ACT_BASE[1] = 0;
        SYS_ACT_BASE[2] = 0;
        SYS_ACT_BASE[3] = 0;
    }
    
    // 4. Read the Output Matrix Results!
    volatile int32_t res0 = SYS_OUT_BASE[0];
    volatile int32_t res1 = SYS_OUT_BASE[1];
    volatile int32_t res2 = SYS_OUT_BASE[2];
    volatile int32_t res3 = SYS_OUT_BASE[3];

    // Read to global to prevent optimizer stripping
    volatile int32_t sum = res0 + res1 + res2 + res3;
    
    while(1);
    return 0;
}
