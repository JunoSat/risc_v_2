#include "util.h"
#include <stdint.h>

void c_trap_handler(unsigned int cause) {
  print_string("\r\n[TRAP] Cause: ");
  print_int(cause);
  while (1);
}

int main() {
  for (volatile int i = 0; i < 500000; i++); 

  print_string("--- MULT/DIV EXCEPTION TEST ---\n");
  
  volatile int32_t a = 15;
  volatile int32_t b = 0;
  
  print_string("Dividing by zero...\n");
  
  int32_t res_div = a / b;
  int32_t res_rem = a % b;
  
  // According to RISC-V spec, divide by zero does not trap.
  // DIV by zero returns -1.
  // REM by zero returns numerator.
  
  print_string("15 / 0 = "); print_int(res_div); print_string("\n");
  print_string("15 % 0 = "); print_int(res_rem); print_string("\n");
  
  volatile int32_t min_int = -2147483648; // 0x80000000
  volatile int32_t c = -1;
  
  print_string("Dividing MinInt by -1 (Overflow)...\n");
  
  // Overflow division: -2^31 / -1
  // DIV returns -2^31.
  // REM returns 0.
  
  int32_t res_ovf_div = min_int / c;
  int32_t res_ovf_rem = min_int % c;
  
  print_string("MinInt / -1 = "); print_hex(res_ovf_div); print_string("\n");
  print_string("MinInt % -1 = "); print_int(res_ovf_rem); print_string("\n");
  
  print_string("--- TEST COMPLETE ---\n");
  while (1);
  return 0;
}
