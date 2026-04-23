// =============================================================================
// TB result communication header
// The testbench Verilog monitors DMEM word at address 0x1000 (word index 1024)
// Write test results here for the Verilog harness to observe.
// =============================================================================
#ifndef TB_COMMON_H
#define TB_COMMON_H

#include <stdint.h>

// Fixed sentinel address in DMEM, known to the Verilog testbench
// Placed at 0x1000 (word index 1024) - safely below stack (0x2000 downward)
#define TB_RESULT ((volatile int32_t*) 0x00001000)
#define TB_SENTINEL_PASS  0x600D

static inline void tb_pass(int test_id) {
    *TB_RESULT = test_id;
}

static inline void tb_fail(int test_id) {
    *TB_RESULT = -(test_id);
}

static inline void tb_done(void) {
    *TB_RESULT = TB_SENTINEL_PASS;
}

void c_trap_handler(unsigned int cause) {
    *TB_RESULT = -((int32_t)cause + 10000);
    while(1);
}

#endif
