#include "util.h"
#include "workload_alu.h"
void c_trap_handler(unsigned int cause) {
    print_string("\r\n[TRAP]\r\n");
}

int main() {
    for (volatile int i = 0; i < 1; i++); 

    // Directly print Alphabet to ensure UART is ready
    for (char c = 'A'; c <= 'Z'; c++) print_char(c);
    print_char('\r'); print_char('\n');

    // Run the Integer & RV32M test suite
    run_alu_diagnostic();

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

    print_string("\r\n--- STARTING SYSTOLIC ARRAY TESTS ---\r\n");
    volatile unsigned int* sa_ctrl   = (volatile unsigned int*)0x90000000;
    volatile unsigned int* sa_status = (volatile unsigned int*)0x90000004;
    volatile unsigned int* sa_mat_a  = (volatile unsigned int*)0x90000010;
    volatile unsigned int* sa_mat_b  = (volatile unsigned int*)0x90000020;
    volatile unsigned int* sa_mat_c  = (volatile unsigned int*)0x90000030;

    // A = [1 2; 3 4], B = [5 6; 7 8]
    sa_mat_a[0] = 1; sa_mat_a[1] = 2; sa_mat_a[2] = 3; sa_mat_a[3] = 4;
    sa_mat_b[0] = 5; sa_mat_b[1] = 6; sa_mat_b[2] = 7; sa_mat_b[3] = 8;
    
    // Start computation
    *sa_ctrl = 1;

    // Poll status
    while ((*sa_status & 2) == 0);

    // Read C
    unsigned int c00 = sa_mat_c[0];
    unsigned int c01 = sa_mat_c[1];
    unsigned int c10 = sa_mat_c[2];
    unsigned int c11 = sa_mat_c[3];
    
    // Check results (19, 22, 43, 50)
    if (c00 == 19 && c01 == 22 && c10 == 43 && c11 == 50) {
        print_string("Systolic Array [PASSED]\r\n");
    } else {
        print_string("Systolic Array [FAILED]\r\n");
        print_string("C00: "); print_int(c00); print_string("\r\n");
        print_string("C01: "); print_int(c01); print_string("\r\n");
        print_string("C10: "); print_int(c10); print_string("\r\n");
        print_string("C11: "); print_int(c11); print_string("\r\n");
    }

    print_string("\r\nAll computational modules verified! Processor is fully operational!\r\n");

    while(1) {
        // Halt
    }


    while (1) {
        for (volatile int i = 0; i < 100000; i++);
    }
    return 0;
}
