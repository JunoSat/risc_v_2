#include "util.h"
#include <stdint.h>

void c_trap_handler(unsigned int cause) {
  print_string("\r\n[TRAP] Cause: ");
  print_int(cause);
  while (1);
}

int main() {
  for (volatile int i = 0; i < 500000; i++); 

  print_string("--- RV32M MULT/DIV NORMAL TEST ---\n");
  
  volatile int32_t a = 15;
  volatile int32_t b = 4;
  
  int32_t res_mul = a * b; // 60
  int32_t res_div = a / b; // 3
  int32_t res_rem = a % b; // 3
  
  print_string("15 * 4 = "); print_int(res_mul); print_string("\n");
  print_string("15 / 4 = "); print_int(res_div); print_string("\n");
  print_string("15 % 4 = "); print_int(res_rem); print_string("\n");
  
  // Division by zero tests
  volatile int32_t zero = 0;
  int32_t res_div_zero = a / zero; // Should return -1
  int32_t res_rem_zero = a % zero; // Should return numerator (15)
  
  print_string("15 / 0 = "); print_int(res_div_zero); print_string("\n");
  print_string("15 % 0 = "); print_int(res_rem_zero); print_string("\n");
  
  volatile int32_t c = -20;
  volatile int32_t d = 3;
  
  print_string("-20 / 3 = "); print_int(c / d); print_string("\n");
  print_string("-20 % 3 = "); print_int(c % d); print_string("\n");
  
  print_string("--- TEST COMPLETE ---\n");
  while (1);
  return 0;
}
