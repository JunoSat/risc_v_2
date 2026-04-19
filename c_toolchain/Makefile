CC = riscv-none-elf-gcc
OBJCOPY = riscv-none-elf-objcopy

CFLAGS = -O2 -march=rv32imf -mabi=ilp32 -ffreestanding -nostdlib -mcmodel=medany

SRCS = start.S main.c util.c workload_alu.c

# Keep the parent-directory seed hex files in sync with every build so that
# fresh bitstreams (and simulation testbenches) see the latest workload. The
# bootloader still mirrors the payload into both IMEM and DMEM at runtime, so
# the parent copies are a convenience, not a correctness requirement.
all: install

program.elf: $(SRCS) link.ld
	$(CC) $(CFLAGS) -T link.ld $(SRCS) -o program.elf

program.bin: program.elf
	$(OBJCOPY) -O binary program.elf program.bin

imem.hex: program.bin bin2hex.py
	python bin2hex.py program.bin imem.hex

install: imem.hex
	copy imem.hex ..\imem.hex
	copy imem.hex ..\dmem.hex

clean:
	del program.elf program.bin imem.hex
