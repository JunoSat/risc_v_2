#include "util.h"
#include <stdint.h>

void c_trap_handler(unsigned int cause) {
  print_string("\r\n[TRAP] Cause: ");
  print_int(cause);
  while (1);
}

int main() {
  for (volatile int i = 0; i < 500000; i++); 

  print_string("--- RV32I INTEGER OVERFLOW TEST ---\n");
  
  int32_t max_int = 2147483647; // 0x7FFFFFFF
  int32_t min_int = -2147483648; // 0x80000000
  
  print_string("Max Int: "); print_hex(max_int); print_string("\n");
  
  int32_t over = max_int + 1;
  print_string("Max Int + 1: "); print_hex(over); 
  if (over == min_int) {
      print_string(" (Wrapped to Min Int) [PASS]\n");
  } else {
      print_string(" (Error)\n");
  }
  
  int32_t under = min_int - 1;
  print_string("Min Int - 1: "); print_hex(under);
  if (under == max_int) {
      print_string(" (Wrapped to Max Int) [PASS]\n");
  } else {
      print_string(" (Error)\n");
  }
  
  print_string("--- TEST COMPLETE ---\n");
  while (1);
  return 0;
}
