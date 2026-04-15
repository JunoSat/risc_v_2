#include "util.h"
#include "workload_alu.h"

void run_addition() {
    print_string("\r\n--- 1. Addition Workload ---\r\n");
    int a = 100;
    int b = 2;
    int c = a + b;
    print_string("Equation: 100 + 2\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\nExpected: 102\r\n");
}

void run_negative() {
    print_string("\r\n--- 2. Subtraction (Negative Result) ---\r\n");
    int a = 4;
    int b = 50;
    int c = a - b;
    print_string("Equation: 4 - 50\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\nExpected: -46\r\n");
}

void run_sorting() {
    print_string("\r\n--- 3. Array Sorting (Bubble Sort) ---\r\n");
    int arr[] = {6, 3, 9};
    int swapped;
    int n = 3;
    
    print_string("Original Array: 6, 3, 9\r\n");
    
    do {
        swapped = 0;
        for(int j=0; j<n-1; j++) {
            if (arr[j] > arr[j+1]) {
                int temp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = temp;
                swapped = 1;
            }
        }
        n = n - 1;
    } while(swapped == 1);
    
    print_string("Sorted Array: ");
    print_int(arr[0]); print_string(", ");
    print_int(arr[1]); print_string(", ");
    print_int(arr[2]); print_string("\r\n");
    print_string("Expected: 3, 6, 9\r\n");
}

void run_fibonacci() {
    print_string("\r\n--- 4. Fibonacci Series ---\r\n");
    int t1 = 0, t2 = 1;
    int nextTerm;
    print_string("Fibonacci (5 terms): ");
    for (int i = 1; i <= 5; ++i) {
        print_int(t1);
        if (i < 5) print_string(", ");
        nextTerm = t1 + t2;
        t1 = t2;
        t2 = nextTerm;
    }
    print_string("\r\nExpected: 0, 1, 1, 2, 3\r\n");
}

void run_xor() {
    print_string("\r\n--- 5. Bitwise XOR ---\r\n");
    int a = 170; // 0xAA
    int b = 85;  // 0x55
    int c = a ^ b;
    print_string("Equation: 170 ^ 85\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\nExpected: 255\r\n");
}

void run_multiplication() {
    print_string("\r\n--- 6. Multiplication Workload ---\r\n");
    int a = 15;
    int b = 6;
    int c = a * b;
    print_string("Equation: 15 * 6\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\nExpected: 90\r\n");

    print_string("\r\n--- Edge Case: Multiplication by Zero ---\r\n");
    int d = 999;
    int e = 0;
    int f = d * e;
    print_string("Equation: 999 * 0\r\n");
    print_string("Result: ");
    print_int(f);
    print_string("\r\nExpected: 0\r\n");
    
    print_string("\r\n--- Edge Case: Negative Multiplication ---\r\n");
    int g = -8;
    int h = 9;
    int i = g * h;
    print_string("Equation: -8 * 9\r\n");
    print_string("Result: ");
    print_int(i);
    print_string("\r\nExpected: -72\r\n");
}

void run_division() {
    print_string("\r\n--- 7. Division Workload ---\r\n");
    int a = 144;
    int b = 12;
    int c = a / b;
    print_string("Equation: 144 / 12\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\nExpected: 12\r\n");

    print_string("\r\n--- Edge Case: Division by Zero ---\r\n");
    volatile int d = 50;
    volatile int e = 0;
    int f = d / e;
    print_string("Equation: 50 / 0\r\n");
    print_string("Result: ");
    // Note: RISC-V hardware specification mandates division by zero yields -1
    print_int(f);
    print_string("\r\nExpected: -1\r\n");

    print_string("\r\n--- Edge Case: Remainder (Modulo) ---\r\n");
    volatile int g = 25;
    volatile int h = 7;
    int i = g % h;
    print_string("Equation: 25 % 7\r\n");
    print_string("Result: ");
    print_int(i);
    print_string("\r\nExpected: 4\r\n");
}

int main() {
    print_string("\r\n\r\n============================================\r\n");
    print_string("   RISC-V SOC AUTOMATED DIAGNOSTIC RUN\r\n");
    print_string("============================================\r\n");
    print_string("Execution Started!\r\n");
    
    // Linearly execute all workloads, exactly like the Assembly test did
    run_addition();
    run_negative();
    run_sorting();
    run_fibonacci();
    run_xor();
    run_multiplication();
    run_division();
    
    // Full ALU 15-edge-case test
    run_alu_diagnostic();
    
    print_string("\r\n============================================\r\n");
    print_string("              TEST SUITE COMPLETE\r\n");
    print_string("============================================\r\n");
    
    return 0; // Goes back to start.S and halts
}
