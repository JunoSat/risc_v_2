# RV32IMF SoC with AXI4-Lite Hardware Accelerators

A complete, synthesizable 5-stage pipelined RISC-V System-on-Chip built in Verilog. It supports the **RV32IMF** instruction set (Base Integer, Multiply/Divide, and Single-Precision Floating Point) and features a fully operational **dual-accelerator AXI4-Lite Control Plane** for hardware-accelerated trigonometry (CORDIC) and matrix multiplication (4×4 Systolic Array).

---

## Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [File Reference](#2-file-reference)
3. [Prerequisites](#3-prerequisites)
4. [Running on the FPGA](#4-running-on-the-fpga)
5. [Running via Icarus Verilog (iverilog)](#5-running-via-icarus-verilog-iverilog)
6. [Writing Firmware (C Code Guide)](#6-writing-firmware-c-code-guide)
   - [Bare-Metal Skeleton](#bare-metal-skeleton)
   - [Example 1: Basic Integer & Float Arithmetic](#example-1-basic-integer--float-arithmetic)
   - [Example 2: CORDIC Trigonometry Accelerator](#example-2-cordic-trigonometry-accelerator)
   - [Example 3: 4×4 Systolic Array (Matrix Multiply)](#example-3-4x4-systolic-array-matrix-multiply)
7. [Memory Map Reference](#7-memory-map-reference)
8. [Known Issues & Errata](#8-known-issues--errata)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          top_fpga.v (SoC Top)                       │
│                                                                     │
│  ┌──────────────┐    ┌────────────────────────────────────────────┐ │
│  │  Bootloader  │    │             pipeline.v (CPU)               │ │
│  │  (UART RX)   │───▶│  IF → ID → EX → MEM → WB  (Hazard Unit)  │ │
│  └──────────────┘    └──────────────────┬─────────────────────────┘ │
│                                         │ Load/Store                 │
│  ┌──────────────┐    ┌──────────────────▼──────────────────────────┐│
│  │   UART TX    │    │              Address Decoder                ││
│  │  (0x8000...) │    │  0x0... → BRAM  │  0x4... → CORDIC (AXI)  ││
│  └──────────────┘    │  0x8... → UART  │  0x5... → Systolic (AXI)││
│                       └─────────────────────────────────────────────┘│
│                                                                     │
│  ┌──────────────────────┐   ┌──────────────────────────────────────┐│
│  │  axi_cordic_slave    │   │       axi_systolic_4x4               ││
│  │  (0x4000_0000)       │   │       (0x5000_0000)                  ││
│  │  ┌──────────────┐    │   │  ┌──────────────────────────────┐    ││
│  │  │  cordic.v    │    │   │  │  4×4 Processing Element Grid │    ││
│  │  │ (32-iter SM) │    │   │  │  + Wavefront Skew Buffers    │    ││
│  │  └──────────────┘    │   │  └──────────────────────────────┘    ││
│  └──────────────────────┘   └──────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### Key Design Properties
| Property | Value |
|---|---|
| ISA | RV32IMF |
| Pipeline Stages | 5 (IF, ID, EX, MEM, WB) |
| Clock | 50 MHz (external MMCM/PLL input) |
| IMEM/DMEM | Block RAM (8 KB each) |
| UART Baud Rate | 115,200 |
| AXI Version | AXI4-Lite |
| CORDIC Precision | Q4.28 fixed-point, 32 iterations |
| Systolic Array | 4×4 MAC grid, wavefront-scheduled |
| Target FPGA | Nexys A7-100T (Artix-7) |

---

## 2. File Reference

### Hardware (Verilog)

| File | Purpose |
|---|---|
| `top_fpga.v` | **SoC top-level.** Wires together the CPU, memories, UART, bootloader, and both AXI accelerators. Address decoding lives here. |
| `pipeline.v` | Full 5-stage pipeline integrating the register file, hazard unit, FPU, and CSR file. |
| `if_stage.v` / `if_id_reg.v` | Instruction Fetch stage and its pipeline register. |
| `id_stage.v` / `id_ex_reg.v` | Instruction Decode (control signals, register reads) and pipeline register. |
| `ex_stage.v` / `ex_mem_reg.v` | Execute stage (ALU, branch resolution, FPU dispatch) and pipeline register. |
| `mem_stage.v` / `mem_wb_reg.v` | Memory access stage and pipeline register. |
| `wb_stage.v` | Write-Back stage, selects result source and commits to register file. |
| `hazard_unit.v` | Detects RAW hazards, load-use stalls, FPU multi-cycle stalls, and AXI bus busy stalls. |
| `fpu.v` | Single-precision FPU supporting FADD.S, FSUB.S, FMUL.S, FCVT, FCMP. |
| `fp_regfile.v` | 32-entry floating-point register file (f0–f31). |
| `mult_div.v` | Iterative RV32M multiplier/divider. |
| `csr_file.v` | Machine-mode CSRs (mstatus, mepc, mcause, etc.). |
| `memory.v` | Dual-port BRAM wrapper for instruction and data memories. |
| `uart.v` / `uart_tx_fifo.v` | 8N1 UART peripheral with a TX FIFO backed by Block RAM. |
| `bootloader.v` | Hardware state machine that receives a compiled binary over UART and writes it into IMEM/DMEM before releasing CPU reset. |
| `axi4_lite_master.v` | Reusable AXI4-Lite Master state machine. Translates a CPU load/store into a compliant AW+W+B or AR+R channel sequence. |
| `axi_cordic_slave.v` | AXI4-Lite Slave wrapper for the CORDIC engine. Decodes register offsets and drives `cordic.v`. |
| `cordic.v` | Iterative CORDIC engine (circular rotation mode). 32-cycle state machine with hardcoded arctangent LUT (Q4.28). |
| `axi_systolic_4x4.v` | AXI4-Lite Slave for the 4×4 systolic array. Includes the PE grid, wavefront skew buffers, weight/activation registers, and step-trigger logic. |
| `opcode.vh` | Shared parameter definitions for all RISC-V opcodes and function codes. |
| `constraint.xdc` | Vivado pin constraints for the Nexys A7-100T (clock, reset, LEDs, UART). |

### Testbenches

| File | What It Tests |
|---|---|
| `tb_cordic.v` | Standalone CORDIC unit test. Applies π/2, π/4, −π/2, and 0 angles and checks outputs. |
| `tb_full_soc.v` | Full SoC integration test. Loads a compiled `.hex` program into memory and monitors AXI bus traffic on both the CORDIC and Systolic channels. |
| `tb_axi_soc.v` | Targeted AXI handshake verification (write then read cycle). |
| `tb_pipeline.v` | Pipeline-level unit test with a hand-coded instruction sequence. |

### Firmware Toolchain (`c_toolchain/`)

| File | Purpose |
|---|---|
| `start.S` | Assembly boot stub. Sets up the stack pointer, clears BSS, installs the trap vector, and jumps to `main()`. Runs before any C code. |
| `link.ld` | Linker script. Places `.text` at address `0x00000000` and reserves space for the stack. |
| `util.h` / `util.c` | Bare-metal UART helper functions: `print_char()`, `print_string()`, `print_int()`. |
| `workload_alu.c` | RV32IM integer and multiply/divide test suite. |
| `main.c` | Default firmware entry point (original calculator demo). |
| `test_cordic.c` | CORDIC accelerator firmware test. |
| `test_systolic.c` | Systolic array firmware test (identity-matrix multiplication). |
| `build.bat` | Windows batch script that compiles, extracts, and converts a C file to `imem.hex`. |
| `bin2hex.py` | Python script that converts a raw `.bin` binary into Verilog `$readmemh`-compatible hex. |
| `terminal.py` | Python UART terminal. Sends the compiled binary to the FPGA bootloader and opens an interactive console. |
| `gen_lut.py` | Utility that pre-calculates the CORDIC arctangent LUT values. |

### Root Makefile

| Command | Action |
|---|---|
| `make` | Compile `c_toolchain/main.c` and deploy to FPGA over `COM3`. |
| `make FILE=c_toolchain/test_cordic.c` | Compile a specific C file and deploy. |
| `make FILE=c_toolchain/test_systolic.c COM=COM4` | Compile and deploy to a different COM port. |
| `make clean` | Remove all build artifacts. |

---

## 3. Prerequisites

### Required Software
| Tool | Purpose | Download |
|---|---|---|
| **Xilinx Vivado 2022.2+** | FPGA synthesis, implementation, and bitstream generation | [xilinx.com](https://www.xilinx.com/support/download.html) |
| **xPack RISC-V GCC** | Bare-metal C cross-compiler (`riscv-none-elf-gcc`) | [github.com/xpack-dev-tools](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases) |
| **Icarus Verilog** | Open-source Verilog simulator (for `iverilog` flow) | [bleyer.org/icarus](http://bleyer.org/icarus/) |
| **Python 3.8+** | Runs `terminal.py` and `bin2hex.py` | [python.org](https://www.python.org/downloads/) |
| **pyserial** | Python serial port library | `pip install pyserial` |

### Environment Setup
After installing xPack GCC, add its `bin` directory to your system `PATH`. Open PowerShell and verify:
```powershell
riscv-none-elf-gcc --version
# Expected: riscv-none-elf-gcc (xPack ...) 15.x.x
```

---

## 4. Running on the FPGA

This is the flow for programming a **Nexys A7-100T** (Artix-7) and running compiled firmware on it live.

### Step 1 — Open Vivado and Create a Project
1. Launch **Vivado** → *Create Project*.
2. Add all `.v` files from the project root as **Design Sources**.
3. Add `constraint.xdc` as a **Constraints** source.
4. Set the target part to `xc7a100tcsg324-1` (Nexys A7-100T).

> [!IMPORTANT]
> The design expects a **50 MHz** clock arriving at the `clk` input. In Vivado's Block Design, instantiate a **Clocking Wizard** IP configured to output 50 MHz from the board's 100 MHz oscillator, then connect its output to `top_fpga.clk`. This replaces any internal clock divider and eliminates timing skew across the AXI bus.

### Step 2 — Generate Bitstream
1. In Vivado, click **Generate Bitstream** (this runs Synthesis → Implementation → Bitstream automatically).
2. Once complete, connect your FPGA via USB and click **Open Hardware Manager** → **Program Device**.
3. The FPGA will boot into the hardware **Bootloader** state machine, which idles waiting for a binary over UART.

### Step 3 — Write and Compile Your Firmware
Create or edit a `.c` file in the `c_toolchain/` directory (see [Section 6](#6-writing-firmware-c-code-guide) for examples).

### Step 4 — Deploy and Run
Open **PowerShell** in the project root:
```powershell
# Compile c_toolchain/main.c and send it to the FPGA on COM3
make

# Deploy a different file to a different port
make FILE=c_toolchain/test_cordic.c COM=COM5
```

The Makefile:
1. Cross-compiles your `.c` file with `riscv-none-elf-gcc` (RV32IMF, bare-metal).
2. Extracts the raw binary with `riscv-none-elf-objcopy`.
3. Converts it to Verilog-compatible hex with `bin2hex.py`.
4. Launches `terminal.py`, which sends the binary to the FPGA bootloader chunk-by-chunk over serial.
5. Once the bootloader finishes writing, it releases the CPU reset and your code runs.
6. The terminal stays open — any `print_string()` calls in your firmware will appear here.

> [!TIP]
> Find your COM port in Windows **Device Manager** under *Ports (COM & LPT)*. It will be listed as "USB Serial Port".

---

## 5. Running via Icarus Verilog (iverilog)

This flow lets you simulate the entire SoC on your PC without any FPGA hardware. The testbench loads `imem.hex` directly into the simulated BRAM.

### Step 1 — Compile Firmware to `.hex`
You must build the firmware first so the simulator has something to run. Temporarily rename any conflicting `main.c`:
```powershell
cd c_toolchain
.\build.bat test_cordic.c
cd ..
```
This produces `imem.hex` and `dmem.hex` in the project root.

### Step 2a — Run the Standalone CORDIC Testbench
This directly drives `cordic.v` with hardcoded angles — no CPU involved. Use this to verify the math engine in isolation.
```powershell
iverilog -o cordic_sim.vvp tb_cordic.v cordic.v
vvp cordic_sim.vvp
```
**Expected output:**
```
PI/2  -> Sine: 10000005  Cosine: 00000000   (1.0 and 0.0 in Q4.28)
PI/4  -> Sine: 0b504f33  Cosine: 0b504f32   (0.707 each)
-PI/2 -> Sine: effffffa  Cosine: 00000002   (-1.0 and ~0.0)
ZERO  -> Sine: 00000000  Cosine: 10000005   (0.0 and 1.0)
```

### Step 2b — Run the Full SoC Integration Testbench
This simulates the entire CPU pipeline executing the compiled firmware, with the AXI bus monitors printing every transaction.
```powershell
iverilog -Wall -o full_soc.vvp `
  tb_full_soc.v top_fpga.v axi4_lite_master.v `
  axi_cordic_slave.v axi_systolic_4x4.v cordic.v `
  pipeline.v memory.v csr_file.v fpu.v fp_regfile.v `
  hazard_unit.v id_ex_reg.v id_stage.v if_id_reg.v `
  if_stage.v mem_stage.v mem_wb_reg.v mult_div.v `
  wb_stage.v uart.v uart_tx_fifo.v bootloader.v `
  ex_stage.v ex_mem_reg.v

vvp full_soc.vvp
```
The testbench will print every AXI-Lite transaction it observes, for example:
```
[SYS-WRITE Req] Time  2185000 | Addr: 50000040, Data:  10
[SYS-WRITE Req] Time  2515000 | Addr: 50000050, Data:   1   ← Step trigger
[SYS-READ Done] Time  4705000 | Returning Data:         40  ← Result
```

> [!NOTE]
> The warnings `$readmemh: Not enough words in the file` are expected and harmless. The memory is initialized to zero for unused cells.

---

## 6. Writing Firmware (C Code Guide)

All firmware runs bare-metal — there is no OS, no `libc`, and no dynamic memory. Every C file you write must follow a specific structure.

### Bare-Metal Skeleton
Every firmware file **must** contain these two symbols, which the linker and trap vector require:

```c
#include <stdint.h>

// REQUIRED: trap handler called on any hardware exception (divide-by-zero, etc.)
// You can print diagnostics here or simply swallow the exception.
void c_trap_handler(unsigned int cause) {
    // Optional: handle the exception. 'cause' is the mcause CSR value.
}

int main() {
    // Your code here.

    while (1); // Prevent main() from returning into garbage memory.
    return 0;
}
```

To compile and deploy your file:
```powershell
# From the project root:
make FILE=c_toolchain/your_file.c COM=COM3
```

---

### Example 1: Basic Integer & Float Arithmetic
Standard RV32IMF operations — integer math, multiplication, division, and software floating-point conversions.

```c
#include <stdint.h>
#include "util.h"  // provides print_string(), print_int()

void c_trap_handler(unsigned int cause) { }

int main() {
    // --- Integer (RV32I) ---
    int a = 42, b = 7;
    int sum  = a + b;   // ADD
    int diff = a - b;   // SUB
    int prod = a * b;   // MUL  (RV32M)
    int quot = a / b;   // DIV  (RV32M)
    int rem  = a % b;   // REM  (RV32M)

    print_string("Sum:  "); print_int(sum);  print_string("\r\n");
    print_string("Quot: "); print_int(quot); print_string("\r\n");

    // --- Floating Point (RV32F) ---
    float pi = 3.14159f;
    float r  = 5.0f;
    float area = pi * r * r;   // FMUL.S

    // Convert float result to integer for printing (no printf available)
    int area_int = (int)area;  // FCVT.W.S
    print_string("Area (int): "); print_int(area_int); print_string("\r\n");

    while (1);
    return 0;
}
```

> [!NOTE]
> Avoid using `printf`, `malloc`, `scanf`, or any standard library function — they are not linked. Use `print_string()` and `print_int()` from `util.h` instead.

---

### Example 2: CORDIC Trigonometry Accelerator

The CORDIC engine computes **both sine and cosine simultaneously** in 32 clock cycles. The CPU writes an angle (in **Q4.28 fixed-point** format) and polls a status register until the result is ready.

**Q4.28 encoding:** Multiply your angle in radians by `2^28 = 268,435,456` and truncate to `int32_t`.

| Angle | Radians | Q4.28 Hex |
|---|---|---|
| 0° | 0.0 | `0x00000000` |
| 45° | π/4 ≈ 0.7854 | `0x0C90FDAB` |
| 90° | π/2 ≈ 1.5708 | `0x1921FB54` |
| −90° | −π/2 | `0xE6DE04AC` |

**Memory Map (Base: `0x4000_0000`)**

| Offset | Access | Description |
|---|---|---|
| `0x00` | Write | Input angle in Q4.28. Writing here starts the CORDIC engine. |
| `0x04` | Read | Status. Returns `1` when computation is complete. |
| `0x08` | Read | Sine result in Q4.28. |
| `0x0C` | Read | Cosine result in Q4.28. |

```c
#include <stdint.h>

#define CORDIC_ANGLE  ((volatile int32_t*) 0x40000000)
#define CORDIC_STATUS ((volatile int32_t*) 0x40000004)
#define CORDIC_SINE   ((volatile int32_t*) 0x40000008)
#define CORDIC_COSINE ((volatile int32_t*) 0x4000000C)

void c_trap_handler(unsigned int cause) { }

// Convert a float angle (radians) to Q4.28 format
int32_t to_q4_28(float radians) {
    return (int32_t)(radians * 268435456.0f);
}

// Convert a Q4.28 result back to float
float from_q4_28(int32_t q) {
    return (float)q / 268435456.0f;
}

void compute_trig(float angle_rad) {
    *CORDIC_ANGLE = to_q4_28(angle_rad); // Write angle → triggers start
    while (*CORDIC_STATUS == 0);          // Spin-wait for completion
    int32_t sin_q = *CORDIC_SINE;
    int32_t cos_q = *CORDIC_COSINE;

    // Convert back if needed:
    // float sin_f = from_q4_28(sin_q);
    // float cos_f = from_q4_28(cos_q);
}

int main() {
    // sin(π/2) should be 1.0, cos(π/2) should be 0.0
    compute_trig(1.5707963f);  // 90 degrees

    // sin(π/4) ≈ cos(π/4) ≈ 0.7071
    compute_trig(0.7853982f);  // 45 degrees

    // Negative angle: sin(-π/4) ≈ -0.7071
    compute_trig(-0.7853982f);

    while (1);
    return 0;
}
```

> [!TIP]
> The Q4.28 results are signed 32-bit integers. A result of `0x10000005` represents approximately `+1.0`, and `0xF0000000` represents approximately `−1.0`. Divide by `268435456.0f` to recover the float.

---

### Example 3: 4×4 Systolic Array (Matrix Multiply)

The systolic array computes matrix-vector and matrix-matrix products using 16 parallel MAC (Multiply-Accumulate) processing elements arranged in a 4×4 grid.

**How it works:** A 4×4 systolic array uses a **diagonal wavefront**. Input data enters from the left side, but each row is delayed by one extra clock tick (Row 0 = 0 delay, Row 1 = 1 delay, etc.). This means the full result takes **2N − 1 = 7 clock cycles** to propagate through a 4×4 grid.

**Memory Map (Base: `0x5000_0000`)**

| Offset | Access | Description |
|---|---|---|
| `0x00–0x3C` | Write | 16 weight registers (Matrix B). `0x00` = W[0][0], `0x04` = W[0][1], ..., `0x3C` = W[3][3]. |
| `0x40–0x4C` | Write | 4 activation holding registers (one column of Matrix A). `0x40` = Row 0, `0x44` = Row 1, etc. |
| `0x50` | Write | **Step trigger.** Write any value to advance the array by one clock cycle. |
| `0x60–0x6C` | Read | 4 output partial sum registers (one output column). `0x60` = Col 0, ..., `0x6C` = Col 3. |

```c
#include <stdint.h>

#define SYS_WEIGHT_BASE ((volatile int32_t*) 0x50000000)
#define SYS_ACT_BASE    ((volatile int32_t*) 0x50000040)
#define SYS_STEP        ((volatile int32_t*) 0x50000050)
#define SYS_OUT_BASE    ((volatile int32_t*) 0x50000060)

void c_trap_handler(unsigned int cause) { }

// Load a 4x4 weight matrix (row-major order)
void load_weights(int32_t W[4][4]) {
    for (int r = 0; r < 4; r++)
        for (int c = 0; c < 4; c++)
            SYS_WEIGHT_BASE[r*4 + c] = W[r][c];
}

// Feed one input column and advance the wavefront
void feed_column(int32_t col[4]) {
    SYS_ACT_BASE[0] = col[0];
    SYS_ACT_BASE[1] = col[1];
    SYS_ACT_BASE[2] = col[2];
    SYS_ACT_BASE[3] = col[3];
    *SYS_STEP = 1;   // Advance the array by one cycle
}

// Feed zeros to flush the pipeline
void flush_step() {
    SYS_ACT_BASE[0] = 0; SYS_ACT_BASE[1] = 0;
    SYS_ACT_BASE[2] = 0; SYS_ACT_BASE[3] = 0;
    *SYS_STEP = 1;
}

int main() {
    // Example: Multiply identity matrix by vector [10, 20, 30, 40]
    // Result should be [10, 20, 30, 40]

    // Step 1: Load weights (identity matrix)
    int32_t identity[4][4] = {
        {1, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 0, 1, 0},
        {0, 0, 0, 1}
    };
    load_weights(identity);

    // Step 2: Feed the input vector as the first column
    int32_t input_col[4] = {10, 20, 30, 40};
    feed_column(input_col);

    // Step 3: Flush with zeros for 2N-2 = 6 more steps
    // (Total pipeline latency = 2N-1 = 7 steps for 4x4 array)
    for (int i = 0; i < 6; i++) {
        flush_step();
    }

    // Step 4: Read output column results
    int32_t out0 = SYS_OUT_BASE[0]; // Should be 10
    int32_t out1 = SYS_OUT_BASE[1]; // Should be 20
    int32_t out2 = SYS_OUT_BASE[2]; // Should be 30
    int32_t out3 = SYS_OUT_BASE[3]; // Should be 40

    volatile int32_t check = out0 + out1 + out2 + out3; // 100

    while (1);
    return 0;
}
```

> [!IMPORTANT]
> **Why 7 steps?** In a systolic 4×4 wavefront, Row 3 activation data is delayed by 3 pipeline registers before entering the array. After feeding your data column, the last valid result does not appear at the output until 7 total clock cycles have elapsed (2N − 1 for an N×N array). Always flush with exactly `2N − 2` zero-padded steps after your data column.

---

## 7. Memory Map Reference

| Base Address | Peripheral | Description |
|---|---|---|
| `0x0000_0000` | **IMEM (BRAM)** | Instruction memory. Loaded by the bootloader at reset. |
| `0x0000_0000` | **DMEM (BRAM)** | Data memory. Shared space for stack, heap, and `.data` segment. |
| `0x4000_0000` | **CORDIC Slave** | AXI4-Lite: Write angle → Poll status → Read sine/cosine. |
| `0x5000_0000` | **Systolic Array** | AXI4-Lite: Write weights → Write activations → Step → Read outputs. |
| `0x8000_0000` | **UART** | `+0x00` TX byte, `+0x04` RX byte, `+0x08` status (RX ready, TX full). |

---

## 8. Known Issues & Errata

| # | Component | Issue | Fix |
|---|---|---|---|
| 1 | `pipeline.v` | Load-Use hazard was stalling `ex_mem_reg`, effectively deleting load instructions. | Re-routed the stall signal so only IF/ID/EX stages freeze on load-use; EX/MEM advances. |
| 2 | `build.bat` | GCC emitting `FMADD.S` (Fused Multiply-Add), which the FPU does not support. | Added `-ffp-contract=off` compiler flag to disable FMA fusion. |
| 3 | `terminal.py` | `ctypes` crash on `Ctrl+C` exit due to improper thread teardown. | Replaced `raise SystemExit` with `os._exit(0)` in the interrupt handler. |
| 4 | `uart_tx_fifo.v` | Async reset in memory array prevents Vivado from inferring Block RAM (uses LUTs instead). | Removed async reset from the array; Vivado now correctly maps it to BRAM primitives. |
| 5 | `top_fpga.v` | Internal 50 MHz clock generated by flip-flop toggle could cause hold-time violations across the AXI network. | Removed internal divider; `clk` port now expects a clean 50 MHz from an external Clocking Wizard. |

---

**Maintained by:** Sathvik & Antigravity AI  
**Last Updated:** April 2026
