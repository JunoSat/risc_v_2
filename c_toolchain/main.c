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
    print_string("\r\n");
}

void run_negative() {
    print_string("\r\n--- 2. Subtraction (Negative Result) ---\r\n");
    int a = 4;
    int b = 50;
    int c = a - b;
    print_string("Equation: 4 - 50\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\n");
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
    print_string("\r\n");
}

void run_xor() {
    print_string("\r\n--- 5. Bitwise XOR ---\r\n");
    int a = 170; // 0xAA
    int b = 85;  // 0x55
    int c = a ^ b;
    print_string("Equation: 170 ^ 85\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\n");
}

int main() {
    // -----------------------------------------------------
    // IMPORTANT: Wait for user to interact via PuTTY.
    // This prevents the CPU from running everything instantly
    // before the user opens the terminal!
    // -----------------------------------------------------
    print_string("\r\n\r\n============================================\r\n");
    print_string("   RISC-V SOC INTERACTIVE DEMO TERMINAL\r\n");
    print_string("============================================\r\n");
    print_string("Press 's' on your keyboard to start demo...\r\n");
    
    char start_key = 0;
    while (start_key != 's') {
        start_key = get_char();
    }
    
    print_string("\r\nSystem Initialized!\r\n");
    
    // Interactive Loop
    while(1) {
        print_string("\r\nSelect a workload to execute:\r\n");
        print_string("1: Addition\r\n");
        print_string("2: Subtraction (Negative)\r\n");
        print_string("3: Sorting\r\n");
        print_string("4: Fibonacci\r\n");
        print_string("5: XOR\r\n");
        print_string("6: Full ALU Diagnostic TestSuite\r\n");
        print_string("Selection > ");
        
        char sel = get_char();
        print_char(sel); // Echo what they typed back to them
        print_string("\r\n");
        
        if (sel == '1') {
            run_addition();
        } 
        else if (sel == '2') {
            run_negative();
        } 
        else if (sel == '3') {
            run_sorting();
        } 
        else if (sel == '4') {
            run_fibonacci();
        } 
        else if (sel == '5') {
            run_xor();
        }
        else if (sel == '6') {
            run_alu_diagnostic();
        }
        else {
            print_string("Invalid selection. Try 1-6.\r\n");
        }
    }
    return 0;
}
