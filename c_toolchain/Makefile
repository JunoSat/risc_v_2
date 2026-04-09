CC = riscv-none-elf-gcc
OBJCOPY = riscv-none-elf-objcopy

CFLAGS = -O2 -march=rv32im -mabi=ilp32 -ffreestanding -nostdlib -mcmodel=medany

all: imem.hex

program.elf: start.S main.c link.ld
	$(CC) $(CFLAGS) -T link.ld start.S main.c -o program.elf

program.bin: program.elf
	$(OBJCOPY) -O binary program.elf program.bin

imem.hex: program.bin bin2hex.py
	python bin2hex.py program.bin imem.hex

install: imem.hex
	copy imem.hex ..\imem.hex

clean:
	del program.elf program.bin imem.hex
