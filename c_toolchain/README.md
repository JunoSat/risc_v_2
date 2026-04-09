# RISC-V Bare-Metal C Toolchain Environment

This folder contains a fully functional, self-contained development environment to write standard `C` code for your custom FPGA RISC-V processor! It correctly links the memory maps, provides the stack initialization scripts, and configures the exact compiler flags required to securely test your RV32IM Multiply/Divide extensions. 

## 1. Setup the RISC-V Compiler
To actually convert your `.c` files into hardware `.hex` format, you must download the official compiler.
1. Download **xPack GNU RISC-V Embedded GCC** for Windows (Search "xPack RISC-V GCC").
2. Extract the `.zip` file somewhere on your PC (e.g. `C:\riscv_toolchain\`).
3. Add the `\bin\` folder of that extracted location to your System Environment variables **`PATH`**. 
   *(This ensures computers know what `riscv-none-elf-gcc` is when you type it!)*

## 2. Understanding the Files
* `main.c`: Your standard C program! It contains a while loop polling your UART hardware correctly using pointers exactly mapped to `0x8000_0000`. Edit this file to make the processor do anything!
* `start.S`: Bare metal CPUs naturally don't have an operating system to setup memory. This fast 10-line assembly script automatically zeroes out memory and initializes the vital Stack Pointer (`sp`) mapping exactly inside the CPU's memory footprint so you can actually assign and call C local variables without corrupting memory! It then cleanly hands off logic to `main()`.
* `link.ld`: The crucial Linker Script mapping memory segments correctly exactly allocating machine code precisely targeting `0x0000_0000` (which is where your CPU boots from).
* `bin2hex.py`: The translator file taking dense zeros and ones extracting them to human readable `.hex` files mapped for Big / Little Endian processing over 32bits.

## 3. How to Compile & Flash the Hardware
Anytime you modify `main.c`:

1. Open a Command Prompt or Powershell into this folder.
2. Run the build script by simply dragging and dropping or typing:
   ```bash
   build.bat
   ```
*(Alternatively, you can just type `make install` if you've mapped Make to your path!)*

This executes compiling dynamically! It will literally compile `program.elf`, strip it into raw binary `program.bin`, format it into `imem.hex` using python, and forcibly **copy it out into your root RISC-V workspace folder!**

Once the script completes, jump back into Vivado, literally just hit **"Generate Bitstream"**, and Vivado will natively pull the updated `imem.hex` code strings transparently! Your FPGA will physically boot straight into executing your `C` logic locally!
