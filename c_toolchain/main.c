#include "util.h"
#include "workload_alu.h" // Include the automated tests

// Accept the mcause CSR value passed from start.S
void c_trap_handler(unsigned int cause) {
    print_string("\r\n=========================================\r\n");
    print_string("[HARDWARE EXCEPTION] TRAP INTERCEPTED\r\n");
    print_string("=========================================\r\n");
    
    print_string("MCAUSE Code: ");
    print_int(cause);
    
    // Check for our custom divide-by-zero code (24)
    if (cause == 24) {
        print_string(" -> Math/Div-By-Zero Fault Evaluated.\r\n");
    } else {
        print_string(" -> Unknown Hardware Fault.\r\n");
    }
    
    print_string("Advancing Program Counter and Resuming...\r\n\r\n");
}

int strcmp(const char* s1, const char* s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++; s2++;
    }
    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

int has_dot(const char* str) {
    while (*str) {
        if (*str == '.') return 1;
        str++;
    }
    return 0;
}

int my_atoi(const char* str) {
    int res = 0;
    int sign = 1;
    if (*str == '-') { sign = -1; str++; }
    while (*str >= '0' && *str <= '9') {
        res = res * 10 + (*str - '0');
        str++;
    }
    return res * sign;
}

float my_atof(const char* str) {
    float res = 0.0f;
    float sign = 1.0f;
    if (*str == '-') { sign = -1.0f; str++; }
    while (*str >= '0' && *str <= '9') {
        res = res * 10.0f + (float)(*str - '0');
        str++;
    }
    if (*str == '.') {
        str++;
        float frac = 1.0f;
        while (*str >= '0' && *str <= '9') {
            frac = frac / 10.0f;
            res = res + (float)(*str - '0') * frac;
            str++;
        }
    }
    return res * sign;
}

void print_float(float val) {
    if (val < 0) { print_char('-'); val = -val; }
    int int_part = (int)val;
    print_int(int_part);
    print_char('.');
    float frac = val - (float)int_part;
    // 4 decimal places
    for (int i=0; i<4; i++) {
        frac = frac * 10.0f;
        int d = (int)frac;
        print_char('0' + d);
        frac = frac - (float)d;
    }
}

void read_line(char* buf, int max_len) {
    int i = 0;
    while (i < max_len - 1) {
        char c = get_char();
        if (c == '\r' || c == '\n') {
            print_string("\r\n");
            break;
        } else if (c == 8 || c == 127) { // backspace
            if (i > 0) {
                i--;
                print_char(8); print_char(' '); print_char(8);
            }
        } else {
            buf[i++] = c;
            print_char(c);
        }
    }
    buf[i] = '\0';
}

void parse_and_execute(char* line) {
    if (line[0] == '\0') return;
    
    char op[16];
    char arg1[32];
    char arg2[32];
    op[0] = '\0'; arg1[0] = '\0'; arg2[0] = '\0';
    
    int state = 0;
    int idx = 0;
    for (int i=0; line[i] != '\0'; i++) {
        if (line[i] == ' ') {
            if (state == 0 && idx > 0) { op[idx] = '\0'; state++; idx=0; }
            else if (state == 1 && idx > 0) { arg1[idx] = '\0'; state++; idx=0; }
            continue;
        }
        if (state == 0 && idx < 15) op[idx++] = line[i];
        else if (state == 1 && idx < 31) arg1[idx++] = line[i];
        else if (state == 2 && idx < 31) arg2[idx++] = line[i];
    }
    if (state == 0) op[idx] = '\0';
    else if (state == 1) arg1[idx] = '\0';
    else if (state == 2) arg2[idx] = '\0';
    
    if (strcmp(op, "help") == 0) {
        print_string("Commands: add, sub, mul, div. Example: add 5 3 or add 5.2 3.1\r\n");
        return;
    }

    int is_float = has_dot(arg1) || has_dot(arg2);
    
    print_string("Result: ");
    
    if (is_float) {
        float f1 = my_atof(arg1);
        float f2 = my_atof(arg2);
        float res = 0.0f;
        if (strcmp(op, "add") == 0) res = f1 + f2;
        else if (strcmp(op, "sub") == 0) res = f1 - f2;
        else if (strcmp(op, "mul") == 0) res = f1 * f2;
        else if (strcmp(op, "div") == 0) res = f1 / f2;
        else { print_string("Unknown OP\r\n"); return; }
        print_float(res);
    } else {
        int i1 = my_atoi(arg1);
        int i2 = my_atoi(arg2);
        int res = 0;
        if (strcmp(op, "add") == 0) res = i1 + i2;
        else if (strcmp(op, "sub") == 0) res = i1 - i2;
        else if (strcmp(op, "mul") == 0) res = i1 * i2;
        else if (strcmp(op, "div") == 0) {
            if (i2 == 0) res = -1; // match previous division by 0 RISC-V behavior
            else res = i1 / i2;
        }
        else { print_string("Unknown OP\r\n"); return; }
        print_int(res);
    }
    print_string("\r\n");
}

// Small self-contained demonstration of the four operations over int and
// float so the workload drives every datapath (ALU / M / F) without waiting
// on the host terminal.
static void show_int(const char* label, int a, int b, int r) {
    print_string(label); print_int(a);
    print_string(", "); print_int(b);
    print_string(") = "); print_int(r);
    print_string("\r\n");
}

static void show_flt(const char* label, float a, float b, float r) {
    print_string(label); print_float(a);
    print_string(", "); print_float(b);
    print_string(") = "); print_float(r);
    print_string("\r\n");
}

int main() {

    // 1. Print Startup Banner
    print_string("\r\n==========================================================\r\n");
    print_string("             FPGA HARDWARE BOOT SEQUENCE                  \r\n");
    print_string("==========================================================\r\n");

    // 2. RUN AUTOMATED HARDWARE TESTS
    int errors = run_alu_diagnostic();

    // 3. Print the Results
    print_string("\r\nDiagnostic Complete. Total Errors: ");
    print_int(errors);
    print_string("\r\n\r\n");

    // 4. Fixed calculator demonstration (no terminal input needed)
    print_string("============================================\r\n");
    print_string("   RV32IMF CALCULATOR DEMONSTRATION\r\n");
    print_string("============================================\r\n");

    int ia = 17, ib = 5;
    show_int("int add(",  ia, ib, ia + ib);
    show_int("int sub(",  ia, ib, ia - ib);
    show_int("int mul(",  ia, ib, ia * ib);
    show_int("int div(",  ia, ib, ia / ib);

    float fa = 5.25f, fb = 3.125f;
    show_flt("flt add(", fa, fb, fa + fb);
    show_flt("flt sub(", fa, fb, fa - fb);
    show_flt("flt mul(", fa, fb, fa * fb);
    show_flt("flt div(", fa, fb, fa / fb);

    print_string("\r\n[DONE] Workload complete. Halting.\r\n");

    // 5. Halt - spin forever so the CPU does not drift into garbage memory.
    while (1) { }
    return 0;
}
