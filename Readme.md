# RV-Accel: A 5-Stage RV32IMF SoC with Custom RTL Math and DSP Accelerators


## Overview
This project implements a fully custom, 5-stage pipelined RISC-V processor conforming to the RV32IMF instruction set architecture. It is synthesized and optimized for the Digilent Nexys A7 FPGA platform.

### Key Features
- **RV32I Base Integer Set**: Full 32-bit integer instruction support.
- **RV32M Multiply/Divide Extension**: Dedicated hardware multiplier and divider unit that correctly handles signed/unsigned operations and architectural edge cases.
- **RV32F Single-Precision Floating-Point**: Fully custom FPU supporting hardware addition, subtraction, multiplication, iterative division, sign-injection, and bi-directional float-integer conversions. (Had to lower the effective frequency to avoid setup time violations.)
- **Memory-Mapped Accelerators (AXI4-Lite)**:
  - **4x4 Systolic Array**: Computes wavefront matrix multiplications.
  - **Iterative CORDIC**: Hardware trigonometric solver for Sine/Cosine.
- **Custom UART Bootloader**: A hardware-level bootloader that intercepts serial payloads and flashes them directly into BRAM, allowing you to iterate on C code in seconds without ever having to re-synthesize the FPGA bitstream!

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          top_fpga.v (SoC Top)                       │
│                                                                     │
│  ┌──────────────┐    ┌────────────────────────────────────────────┐ │
│  │  Bootloader  │    │             pipeline.v (CPU)               │ │
│  │  (UART RX)   │ -> │  IF → ID → EX → MEM → WB  (Hazard Unit)    │ |
│  └──────────────┘    └──────────────────┬─────────────────────────┘ │
│                                         │ Load/Store                │
│  ┌──────────────┐    ┌──────────────────▼──────────────────────────┐│
│  │   UART TX    │    │              Address Decoder                ││
│  │  (0x8000...) │    │  0x0... → BRAM  │  0x4... → CORDIC (AXI)    ││
│  └──────────────┘    │  0x8... → UART  │  0x5... → Systolic (AXI)  ││
│                      └─────────────────────────────────────────────┘│
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

### Design Properties

| Property         | Value                             |
| ---------------- | --------------------------------- |
| ISA              | RV32IMF                           |
| Pipeline Stages  | 5 (IF, ID, EX, MEM, WB)           |
| Clock            | 50 MHz (external MMCM/PLL input)  |
| IMEM/DMEM        | Block RAM (8 KB each)             |
| UART Baud Rate   | 115,200                           |
| AXI Version      | AXI4-Lite                         |
| CORDIC Precision | Q4.28 fixed-point, 32 iterations  |
| Systolic Array   | 4×4 MAC grid, wavefront-scheduled |
| Target FPGA      | Nexys A7-100T (Artix-7)           |

---

## Hardware Setup & Programming
1. **Locate Bitstream**: The final compiled hardware bitstream should be stored in the `bitstream` directory.
2. **Program FPGA**: Open Xilinx Vivado, open the Hardware Manager, and program the Nexys A7 FPGA with your bitstream.
3. **UART Connection**: Connect the FPGA board's USB-UART port to your computer. Identify the COM port assigned to the FPGA in your device manager (e.g., `COM4`).

---

## The Reset Switch
The processor uses **Switch 0 (J15)** on the Nexys A7 to control its execution state. The entire design relies on an active-low reset tree.

- **Push DOWN (Logic 0)**: Holds the processor, bootloader, and all peripherals in a clean, frozen **Reset** state.
- **Push UP (Logic 1)**: Releases the reset, activating the Bootloader to listen for new firmware over the UART line.

---

## Test Workloads

### 1. RV32M Integer & Math Testing
This workload thoroughly validates the integer pipeline and the hardware Multiply/Divide extension. It explicitly checks architectural edge cases:
- **Integer Overflow**: Verifies that adding `1` to the maximum 32-bit signed integer (`0x7FFFFFFF`) wraps cleanly to the minimum negative integer (`0x80000000`), and vice versa.
- **Division by Zero**: Asserts that dividing by zero correctly returns `-1` (all 1s) and modulo by zero returns the original dividend, strictly adhering to the RISC-V specification.

**Steps to run:**
1. Push **Switch 0 DOWN** to hold the FPGA in reset. After that Program (or reprogram) the FPGA using bitstream(top_fpga.bit) present in bitstream directory.
2. Execute the compilation and run command:
   ```bash
   make FILE=c_toolchain/rv32m_full_testing.c run COM=COM4
   ```
   *(Remember to replace `COM4` with your active UART port)*
3. The Python script will pause and prompt you to activate the Bootloader.
4. Push **Switch 0 UP** to release the reset.
5. Press **ENTER** on your keyboard to flash the payload and view the results.

### 2. RV32F Floating-Point Testing
This workload stresses the floating-point unit pipeline. It exercises IEEE 754 single-precision additions, subtractions, multiplications, and divisions. It also leverages the processor's combinatorial hardware logic to test sign negation (`fsgnjn.s`) and bi-directional integer-float conversions (`fcvt.w.s` and `fcvt.s.w`).

**Steps to run:**
1. Push **Switch 0 DOWN** to hold the FPGA in reset. After that Program (or reprogram) the FPGA using bitstream(top_fpga.bit) present in bitstream directory.
2. Execute the compilation and run command:
   ```bash
   make FILE=c_toolchain/fpu_main.c run COM=COM4
   ```
     *(Remember to replace `COM4` with your active UART port)*
3. The Python script will pause and prompt you to activate the Bootloader.
4. Push **Switch 0 UP** to release the reset.
5. Press **ENTER** on your keyboard to flash the payload and view the results.

### 3. AXI Hardware Accelerators (Systolic Array & CORDIC)
This workload tests the custom hardware accelerators mapped onto the processor's AXI4-Lite bus.
- **CORDIC**: Triggers iterative sine and cosine calculations for specific angles via memory-mapped IO.
- **Systolic Array**: Performs stepwise matrix multiplications, demonstrating the hardware wavefront execution by shifting activations and accumulating partial sums over multiple clock cycles.

**Steps to run:**
1. Push **Switch 0 DOWN** to hold the FPGA in reset. After that Program (or reprogram) the FPGA using bitstream(top_fpga.bit) present in bitstream directory.
2. Execute the compilation and run command:
   ```bash
   make FILE=c_toolchain/main.c run COM=COM4
   ```
     *(Remember to replace `COM4` with your active UART port)*
3. The Python script will pause and prompt you to activate the Bootloader.
4. Push **Switch 0 UP** to release the reset.
5. Press **ENTER** on your keyboard to flash the payload and view the results.

## 4. Outputs:
**1. CORDIC and Systolic Array**
<img width="890" height="725" alt="image" src="https://github.com/user-attachments/assets/27a12d1c-0e79-4a54-8a28-ba9bb8a92b84" />

**2. RV32M (multiplication and division)**
<img width="644" height="402" alt="image" src="https://github.com/user-attachments/assets/ac6d3c90-2c80-4a69-9d30-cc3d2e7cd0ad" />

**3. RV32F ( Floating-Point Operations)**
<img width="765" height="224" alt="image" src="https://github.com/user-attachments/assets/63d04068-c00e-4ca7-92fc-be9016482352" />



