#include "util.h"

#define UART_TX_DATA ((volatile int*) 0x80000000)
#define UART_RX_DATA ((volatile int*) 0x80000004)
#define UART_STATUS  ((volatile int*) 0x80000008)

char get_char() {
    // Wait until RX_READY (bit 1) is high
    while ((*UART_STATUS & 2) == 0); 
    // Reading implicitly acks and clears the ready flag via hardware
    return (char) *UART_RX_DATA;
}

void print_char(char c) {
    // Wait until TX is ready (hardware flag might be stuck, keeping for legacy)
    while ((*UART_STATUS & 1) != 0); 
    *UART_TX_DATA = (int) c;
    
    // SOFTWARE WORKAROUND: Force a fixed delay to prevent FIFO overflow.
    // At 100MHz, 115200 baud requires ~868 cycles per bit -> ~8680 cycles per char.
    // Using a delay limit of 15000 safely guarantees we wait longer than the UART transmission time.
    for (volatile int delay = 0; delay < 15000; delay++);
}

void print_string(const char* str) {
    while (*str) {
        print_char(*str++);
    }
}

void print_int(int val) {
    if (val < 0) { print_char('-'); val = -val; }
    if (val == 0) { print_char('0'); return; }
    char buf[16];
    int idx = 0;
    while (val > 0) {
        buf[idx++] = (val % 10) + '0';
        val /= 10;
    }
    while (idx > 0) {
        print_char(buf[--idx]);
    }
}

void print_hex(unsigned int val) {
    print_string("0x");
    for (int i = 7; i >= 0; i--) {
        int nibble = (val >> (i * 4)) & 0xF;
        if (nibble < 10) print_char('0' + nibble);
        else print_char('A' + (nibble - 10));
    }
}
