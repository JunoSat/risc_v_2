#include <stdint.h>

// --- CORDIC MAP ---
#define CORDIC_ANGLE ((volatile int32_t *)0x40000000)
#define CORDIC_STATUS ((volatile int32_t *)0x40000004)
#define CORDIC_SINE ((volatile int32_t *)0x40000008)
#define CORDIC_COSINE ((volatile int32_t *)0x4000000C)

// --- SYSTOLIC MAP ---
#define SYS_WEIGHT_BASE ((volatile int32_t *)0x50000000)
#define SYS_ACT_BASE ((volatile int32_t *)0x50000040)
#define SYS_STEP ((volatile int32_t *)0x50000050)
#define SYS_OUT_BASE ((volatile int32_t *)0x50000060)

void c_trap_handler(unsigned int cause) {
  while (1);
}

void test_cordic(int32_t angle_q28) {
  *CORDIC_ANGLE = angle_q28;
  
  // Dummy read to force AXI write to flush before polling status.
  volatile int32_t dummy_sync = *CORDIC_ANGLE;
  (void)dummy_sync;

  while (*CORDIC_STATUS == 0);

  volatile int32_t s = *CORDIC_SINE;
  volatile int32_t c = *CORDIC_COSINE;
  (void)s;
  (void)c;
}

void test_systolic_identity() {
  // 1. Load Identity Matrix
  for (int i = 0; i < 16; i++) {
    SYS_WEIGHT_BASE[i] = (i % 5 == 0) ? 1 : 0;
  }

  // 2. Load Vector [10, 20, 30, 40]
  for (int i = 0; i < 4; i++) {
    SYS_ACT_BASE[i] = (i + 1) * 10;
  }

  // 3. Pulse steps and read intermediate results
  for (int i = 0; i < 7; i++) {
    *SYS_STEP = 1;
    volatile int32_t out0 = SYS_OUT_BASE[0];
    volatile int32_t out1 = SYS_OUT_BASE[1];
    volatile int32_t out2 = SYS_OUT_BASE[2];
    volatile int32_t out3 = SYS_OUT_BASE[3];
    (void)out0; (void)out1; (void)out2; (void)out3;
  }
}

int main() {
  // 1. CORDIC TESTS
  test_cordic(0x1921FB54); // PI/2
  test_cordic(0x0C90FDAB); // PI/4

  // 2. SYSTOLIC ARRAY TESTS
  test_systolic_identity();

  while (1);
  return 0;
}
