#include <stdint.h>
#include "util.h"

#define SYS_WEIGHT_BASE ((volatile int32_t*) 0x50000000)
#define SYS_ACT_BASE    ((volatile int32_t*) 0x50000040)
#define SYS_STEP        ((volatile int32_t*) 0x50000050)
#define SYS_OUT_BASE    ((volatile int32_t*) 0x50000060)

void c_trap_handler(unsigned int cause) { 
    print_string("\r\nTRAP TRIGGERED! Cause: ");
    print_int(cause);
    print_string("\r\n");
    while(1);
}

// Load a 4x4 weight matrix (row-major order)
void load_weights(int32_t W[4][4]) {
    for (int r = 0; r < 4; r++)
        for (int c = 0; c < 4; c++)
            SYS_WEIGHT_BASE[r*4 + c] = W[r][c];
}

// Feed one input column and advance the wavefront
void feed_column(int32_t col[4]) {
    SYS_ACT_BASE[0] = col[0];
    SYS_ACT_BASE[1] = col[1];
    SYS_ACT_BASE[2] = col[2];
    SYS_ACT_BASE[3] = col[3];
    *SYS_STEP = 1;   // Advance the array by one cycle
}

// Feed zeros to flush the pipeline
void flush_step() {
    SYS_ACT_BASE[0] = 0; SYS_ACT_BASE[1] = 0;
    SYS_ACT_BASE[2] = 0; SYS_ACT_BASE[3] = 0;
    *SYS_STEP = 1;
}

int main() {
    print_string("\r\n==============================================\r\n");
    print_string(" RISC-V SoC Validation: SYSTOLIC\r\n");
    print_string("==============================================\r\n");

    print_string("\r\n--- Starting Systolic Array Test ---\r\n");

    // Step 1: Load weights (identity matrix)
    print_string("1. Loading Identity Matrix into Weights (4x4)...\r\n");
    int32_t identity[4][4] = {
        {1, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 0, 1, 0},
        {0, 0, 0, 1}
    };
    load_weights(identity);

    // Step 2: Feed the input vector as the first column
    print_string("2. Feeding input activations: [10, 20, 30, 40]...\r\n");
    int32_t input_col[4] = {10, 20, 30, 40};
    feed_column(input_col);

    // Step 3: Flush with zeros for 2N-2 = 6 more steps
    // (Total pipeline latency = 2N-1 = 7 steps for 4x4 array)
    print_string("3. Pulsing the SYS_STEP 6 more times (Flushing pipeline)...\r\n");
    for (int i = 0; i < 6; i++) {
        flush_step();
    }

    // Step 4: Read output column results
    print_string("4. Reading hardware output matrix results...\r\n");
    int32_t out0 = SYS_OUT_BASE[0]; 
    int32_t out1 = SYS_OUT_BASE[1]; 
    int32_t out2 = SYS_OUT_BASE[2]; 
    int32_t out3 = SYS_OUT_BASE[3]; 

    print_string("Result [0] = "); print_int(out0); print_string("\r\n");
    print_string("Result [1] = "); print_int(out1); print_string("\r\n");
    print_string("Result [2] = "); print_int(out2); print_string("\r\n");
    print_string("Result [3] = "); print_int(out3); print_string("\r\n");

    if (out0 == 10 && out1 == 20 && out2 == 30 && out3 == 40) {
        print_string("==> SYSTOLIC HARDWARE MATCHES EXPECTED OUTPUT! <==\r\n");
    } else {
        print_string("==> SYSTOLIC HARDWARE MISMATCH! <==\r\n");
    }

    print_string("\r\n==============================================\r\n");
    print_string("               ALL TESTS DONE\r\n");
    print_string("==============================================\r\n");

    while (1);
    return 0;
}