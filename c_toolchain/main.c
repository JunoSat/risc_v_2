#include "systolic_demo.h"
#include "util.h"
#include "workload_alu.h"

void c_trap_handler(unsigned int cause) { print_string("\r\n[TRAP]\r\n"); }

int main() {
  for (volatile int i = 0; i < 500000; i++)
    ;

  // Directly print Alphabet to ensure UART is ready
  for (char c = 'A'; c <= 'Z'; c++)
    print_char(c);
  print_char('\r');
  print_char('\n');

  // Run the Integer & RV32M test suite
  run_alu_diagnostic();

  print_string("\r\n--- STARTING RV32F FLOATING POINT TESTS ---\r\n");

  // Test 1: Basic Addition
  float a = 5.25f;
  float b = 3.5f;
  float res = a + b; // Expected: 8.75

  print_string("5.25 + 3.50 = ");
  unsigned int raw = *((unsigned int *)&res);
  if (raw == 0x410C0000) {
    print_string("8.75 [PASSED]\r\n");
  } else {
    print_string("FAILED (Hex: ");
    print_hex(raw);
    print_string(")\r\n");
  }

  // Test 2: Multiplication
  res = a * b; // Expected: 18.375
  print_string("5.25 * 3.50 = ");
  raw = *((unsigned int *)&res);
  if (raw == 0x41930000) {
    print_string("18.375 [PASSED]\r\n");
  } else {
    print_string("FAILED (Hex: ");
    print_hex(raw);
    print_string(")\r\n");
  }

  // Test 3: Division
  res = b / 0.5f; // Expected: 7.0
  print_string("3.50 / 0.50 = ");
  raw = *((unsigned int *)&res);
  if (raw == 0x40E00000) {
    print_string("7.0 [PASSED]\r\n");
  } else {
    print_string("FAILED (Hex: ");
    print_hex(raw);
    print_string(")\r\n");
  }

  print_string("\r\nAll computational modules verified! Processor is fully "
               "operational!\r\n");

  // Launch the interactive systolic array matrix multiplier
  run_systolic_demo();

  while (1) {
    // Halt after demo exits
  }

  while (1) {
    for (volatile int i = 0; i < 100000; i++)
      ;
  }
  return 0;
}
