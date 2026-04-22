CC = riscv-none-elf-gcc
OBJCOPY = riscv-none-elf-objcopy

CFLAGS = -O2 -march=rv32imf -mabi=ilp32 -ffp-contract=off -ffreestanding -nostdlib -mcmodel=medany -Wl,--no-warn-rwx-segments -Ic_toolchain

# Default values if not provided by user
FILE ?= c_toolchain/main.c
COM ?= COM4

# The bare-metal environment needs the initialization script and utility functions
SRCS = c_toolchain/start.S $(FILE) c_toolchain/util.c c_toolchain/workload_alu.c

all: run

program.elf: $(SRCS) c_toolchain/link.ld
	$(CC) $(CFLAGS) -T c_toolchain/link.ld $(SRCS) -o program.elf

program.bin: program.elf
	$(OBJCOPY) -O binary program.elf program.bin

imem.hex: program.bin c_toolchain/bin2hex.py
	python c_toolchain/bin2hex.py program.bin imem.hex

install: imem.hex
	copy imem.hex dmem.hex

run: install
	python c_toolchain/terminal.py $(COM) computations_log.txt

clean:
	del program.elf program.bin imem.hex dmem.hex
