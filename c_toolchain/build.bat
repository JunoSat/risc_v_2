@echo off
echo COMPILING RISC-V C CODE...
riscv-none-elf-gcc -O2 -march=rv32im -mabi=ilp32 -ffreestanding -nostdlib -mcmodel=medany -T link.ld start.S main.c -o program.elf

echo EXTRACTING BINARY...
riscv-none-elf-objcopy -O binary program.elf program.bin

echo CONVERTING TO VERILOG HEX...
python bin2hex.py program.bin imem.hex

echo INSTALLING INTO WORKSPACE...
copy imem.hex ..\imem.hex

echo DONE!
