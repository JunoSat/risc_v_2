#include "util.h"

#define UART_TX_DATA ((volatile int *)0x80000000)
#define UART_RX_DATA ((volatile int *)0x80000004)
#define UART_STATUS ((volatile int *)0x80000008)

char get_char() {
  // Wait until RX_READY (bit 1) is high
  while ((*UART_STATUS & 2) == 0)
    ;
  // Reading implicitly acks and clears the ready flag via hardware
  return (char)*UART_RX_DATA;
}

void print_char(char c) {
  // Wait until TX is ready (hardware flag might be stuck, keeping for legacy)
  while ((*UART_STATUS & 1) != 0)
    ;
  *UART_TX_DATA = (int)c;

  // SOFTWARE WORKAROUND: Force a fixed delay to prevent FIFO overflow.
  // At 50MHz, 115200 baud requires ~434 cycles per bit -> ~4340 cycles per
  // char. This loop takes > 10,000 cycles, ensuring the UART pops the byte
  // before we send another.
  for (volatile int delay = 0; delay < 2000; delay++)
    ;
}

void print_string(const char *str) {
  while (*str) {
    print_char(*str++);
  }
}

void print_int(int val) {
  if (val < 0) {
    print_char('-');
    val = -val;
  }
  if (val == 0) {
    print_char('0');
    return;
  }
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
    if (nibble < 10)
      print_char('0' + nibble);
    else
      print_char('A' + (nibble - 10));
  }
}

int get_int(void) {
  char buf[12];
  int pos = 0;

  while (1) {
    char c = get_char();

    // Enter — submit
    if (c == '\r' || c == '\n') {
      print_char('\r');
      print_char('\n');
      break;
    }

    // Backspace
    if (c == '\b' || c == 127) {
      if (pos > 0) {
        pos--;
        print_char('\b');
        print_char(' ');
        print_char('\b');
      }
      continue;
    }

    // Accept digits and leading minus
    if (pos < 11) {
      if ((c >= '0' && c <= '9') || (c == '-' && pos == 0)) {
        buf[pos++] = c;
        print_char(c); // echo
      }
    }
  }

  buf[pos] = '\0';

  // Parse signed decimal
  int result = 0;
  int sign = 1;
  int i = 0;

  if (pos > 0 && buf[0] == '-') {
    sign = -1;
    i = 1;
  }

  for (; i < pos; i++) {
    result = result * 10 + (buf[i] - '0');
  }

  return result * sign;
}
