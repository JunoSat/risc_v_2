#include "util.h"

void c_trap_handler(unsigned int cause) {
    print_string("\r\n[TRAP]\r\n");
}

int main() {
    for (volatile int i = 0; i < 500000; i++); 

    // Directly print Alphabet to ensure UART is ready
    for (char c = 'A'; c <= 'Z'; c++) print_char(c);
    print_char('\r'); print_char('\n');

    // Test a local stack string vs a rodata string
    const char* rod = "HELLOWORLD";
    
    print_char('a'); print_char('d'); print_char('r'); print_char('=');
    print_int((int)rod);
    print_char('\r'); print_char('\n');

    // Print each character explicitly with indices to see if LBU is fetching
    for (int i = 0; i < 10; i++) {
        print_char('[');
        print_int(i);
        print_char(']');
        print_char('=');
        print_char(rod[i]);
        print_char('\r'); print_char('\n');
    }

    // Now test a simple pointer
    const char* ptr = "PTRTEST";
    print_char('p'); print_char('t'); print_char('r'); print_char('=');
    print_int((int)ptr);
    print_char('\r'); print_char('\n');

    while (*ptr != '\0') {
        print_char(*ptr);
        ptr++;
    }
    print_char('\r'); print_char('\n');

    while (1) {
        for (volatile int i = 0; i < 100000; i++);
    }
    return 0;
}
