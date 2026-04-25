#include "util.h"

void c_trap_handler(unsigned int cause) {
  print_string("\r\n[TRAP]\r\n");
  while (1);
}

int main() {
  for (volatile int i = 0; i < 500000; i++); 

  print_string("\r\n--- STARTING RV32F FLOATING POINT TESTS ---\r\n");

  // Test 1: Basic Addition
  float a = 5.25f;
  float b = 3.5f;
  float res = a + b; // Expected: 8.75
  
  print_string("5.25 + 3.50 = ");
  unsigned int raw = *((unsigned int*)&res);
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
  raw = *((unsigned int*)&res);
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
  raw = *((unsigned int*)&res);
  if (raw == 0x40E00000) {
      print_string("7.0 [PASSED]\r\n");
  } else {
      print_string("FAILED (Hex: ");
      print_hex(raw);
      print_string(")\r\n");
  }

  // Test 4: Subtraction (Bonus)
  res = a - b; // Expected: 1.75
  print_string("5.25 - 3.50 = ");
  raw = *((unsigned int*)&res);
  if (raw == 0x3FE00000) {
      print_string("1.75 [PASSED]\r\n");
  } else {
      print_string("FAILED (Hex: ");
      print_hex(raw);
      print_string(")\r\n");
  }

  // Test 5: FPU Comparisons
  print_string("5.25 > 3.50 = ");
  int cmp = (a > b); // Expected: 1
  if (cmp == 1) {
      print_string("1 [PASSED]\r\n");
  } else {
      print_string("FAILED (Val: ");
      print_int(cmp);
      print_string(")\r\n");
  }

  // Test 6: Float to Int conversion
  print_string("(int)5.25 = ");
  int f2i = (int)a; // Expected: 5
  if (f2i == 5) {
      print_string("5 [PASSED]\r\n");
  } else {
      print_string("FAILED (Val: ");
      print_int(f2i);
      print_string(")\r\n");
  }

  // Test 7: Int to Float conversion
  int x = 12;
  float i2f = (float)x; // Expected: 12.0
  print_string("(float)12 = ");
  raw = *((unsigned int*)&i2f);
  if (raw == 0x41400000) {
      print_string("12.0 [PASSED]\r\n");
  } else {
      print_string("FAILED (Hex: ");
      print_hex(raw);
      print_string(")\r\n");
  }

  // Test 8: Float Negation
  float neg_a = -a; // Expected: -5.25
  print_string("-5.25 = ");
  raw = *((unsigned int*)&neg_a);
  if (raw == 0xC0A80000) {
      print_string("-5.25 [PASSED]\r\n");
  } else {
      print_string("FAILED (Hex: ");
      print_hex(raw);
      print_string(")\r\n");
  }

  print_string("\r\n--- FPU TEST COMPLETE ---\r\n");

  while(1) {
      // Halt
  }

  return 0;
}
