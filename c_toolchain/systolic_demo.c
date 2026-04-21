#include "systolic_demo.h"
#include "util.h"

// ============================================================
// Systolic Accelerator MMIO Registers  (base 0x9000_0000)
// ============================================================
#define SYS_CTRL ((volatile int *)0x90000000)   // [W] bit 0 = start
#define SYS_STATUS ((volatile int *)0x90000004) // [R] bit0=done, bit1=busy
#define SYS_DIM ((volatile int *)0x90000008)    // [RW] dimension N (1-4)
#define SYS_MAT_A ((volatile int *)0x90000100)  // [W] A elements (row-major)
#define SYS_MAT_B ((volatile int *)0x90000200)  // [W] B elements (row-major)
#define SYS_MAT_C ((volatile int *)0x90000300)  // [R] C results  (row-major)

// ============================================================
// Interactive Matrix Multiply Demo
// ============================================================
void run_systolic_demo(void) {
  print_string("\r\n========================================\r\n");
  print_string("  SYSTOLIC ARRAY MATRIX MULTIPLIER\r\n");
  print_string("  Hardware: 4x4 PE Grid @ 50 MHz\r\n");
  print_string("  Values: 16-bit signed (-32768..32767)\r\n");
  print_string("========================================\r\n");

  while (1) {
    // ---- Get dimension ----
    print_string("\r\nEnter N (1-4, 0=exit): ");
    int n = get_int();

    if (n == 0) {
      print_string("Exiting systolic demo.\r\n");
      return;
    }
    if (n < 1 || n > 4) {
      print_string("Invalid! N must be 1-4.\r\n");
      continue;
    }

    // Write dimension to hardware
    *SYS_DIM = n;

    // ---- Input Matrix A ----
    print_string("\r\nMatrix A (");
    print_int(n);
    print_string("x");
    print_int(n);
    print_string("):\r\n");

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        print_string("  A[");
        print_int(i);
        print_string("][");
        print_int(j);
        print_string("] = ");
        int val = get_int();
        // Hardware stores rows with stride 4 (max N)
        SYS_MAT_A[i * 4 + j] = val;
      }
    }

    // ---- Input Matrix B ----
    print_string("\r\nMatrix B (");
    print_int(n);
    print_string("x");
    print_int(n);
    print_string("):\r\n");

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        print_string("  B[");
        print_int(i);
        print_string("][");
        print_int(j);
        print_string("] = ");
        int val = get_int();
        SYS_MAT_B[i * 4 + j] = val;
      }
    }

    // ---- Start hardware computation ----
    print_string("\r\nComputing C = A x B on systolic array...");
    *SYS_CTRL = 1; // pulse start

    // Poll until done (typically < 12 clock cycles!)
    while (!(*SYS_STATUS & 1))
      ;

    print_string(" Done!\r\n\r\n");

    // ---- Print Result ----
    print_string("Result Matrix C:\r\n");
    for (int i = 0; i < n; i++) {
      print_string("  | ");
      for (int j = 0; j < n; j++) {
        int val = SYS_MAT_C[i * 4 + j];
        print_int(val);
        if (j < n - 1)
          print_string("\t");
      }
      print_string(" |\r\n");
    }
  }
}
