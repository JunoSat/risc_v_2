#include <stdint.h>

#define CORDIC_ANGLE  ((volatile int32_t*) 0x40000000)
#define CORDIC_STATUS ((volatile int32_t*) 0x40000004)
#define CORDIC_SINE   ((volatile int32_t*) 0x40000008)
#define CORDIC_COSINE ((volatile int32_t*) 0x4000000C)

void c_trap_handler(unsigned int cause) { }

volatile int32_t global_result = 0;

void request_cordic_math(int32_t q4_28_angle) {
    *CORDIC_ANGLE = q4_28_angle;
    // Wait for the AXI Slave to return Valid == 1
    while (*CORDIC_STATUS == 0);
    
    // Read the results out over AXI
    int32_t my_sine = *CORDIC_SINE;
    int32_t my_cosine = *CORDIC_COSINE;
    
    // Store it somewhere to prevent compiler optimizing it away
    global_result = my_sine + my_cosine;
}

int main() {
    // ----------------------------------------------------
    // BASE INSTRUCTIONS TEST (RV32IMF - ~20 operations)
    // ----------------------------------------------------
    int a = 15;
    int b = 25;
    int c = a + b;
    int d = c * 2;
    int e = d / 5;
    
    float f1 = 3.1415f;
    float f2 = 2.0f;
    float f3 = f1 * f2;
    float f4 = f3 + 1.5f;
    
    int g = (int)f4;
    for(int i = 0; i < 5; i++) {
        g += i;
    }

    // ----------------------------------------------------
    // CORDIC ACCELERATOR TEST VIA AXI4-LITE
    // ----------------------------------------------------
    
    // Test 1: PI/2 = 421657428 = 0x1921FB54 
    request_cordic_math(0x1921FB54);
    
    // Test 2: PI/4 = 210828714 = 0x0C90FDAB
    request_cordic_math(0x0C90FDAB);
    
    // Wait indefinitely
    while(1);
    return 0;
}
