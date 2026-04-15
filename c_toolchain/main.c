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
    
    // Full ALU 15-edge-case test
    run_alu_diagnostic();
    
    print_string("\r\n============================================\r\n");
    print_string("              TEST SUITE COMPLETE\r\n");
    print_string("============================================\r\n");
    
    return 0; // Goes back to start.S and halts
}
