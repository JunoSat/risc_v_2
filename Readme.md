# RV32IMF RISC-V Hardware Calculator

This repository contains a 5-stage pipelined RISC-V processor with support for the RV32I (Base Integer), RV32M (Multiply/Divide), and RV32F (Single-Precision Floating Point) extensions. It includes a UART interface for communication and a C-based firmware calculator.

## Table of Contents
- [Features](#features)
- [Project Structure](#project-structure)
- [Recent Bug Fixes & Improvements](#recent-bug-fixes--improvements)
- [Getting Started](#getting-started)
- [Hardware Review](#hardware-review)

## Features
- **5-Stage Pipeline**: IF, ID, EX, MEM, WB with full hazard detection and forwarding.
- **RV32F Support**: Dedicated FPU handling FADD.S, FSUB.S, FMUL.S, FLW, FSW, etc.
- **UART Communication**: Integrated UART RX/TX for interactive debugging and data transfer.
- **Floating Point Calculator**: C firmware that parses expressions and computes results on hardware.

## Recent Bug Fixes & Improvements

### 1. Pipeline Load-Use Hazard Fix (`pipeline.v`)
- **Issue**: The `ex_mem_reg` was being stalled during Load-Use hazards. This caused the Load instruction to be "stuck" in the EX/MEM pipeline register, effectively deleting it and replacing it with the previous instruction.
- **Fix**: Re-routed the stall signal for the EX/MEM stage to `stage_stall_ex` (which ignores Load-Use stalls) while maintaining proper stalls for the IF/ID/EX boundaries. This ensures Load instructions advance to memory to fetch data.

### 2. Compiler Optimization Tuning (`build.bat`)
- **Issue**: GCC was generating `FMADD.S` (Fused Multiply-Add) instructions, which the hardware FPU does not support, causing illegal instruction exceptions.
- **Fix**: Added `-ffp-contract=off` to the compiler flags to disable FMA fusion, ensuring only base `FADD.S` and `FMUL.S` instructions are generated.

### 3. UART Terminal Stability (`terminal.py`)
- **Issue**: The Python terminal would crash with a `ctypes` error on exit due to improper serial port handling during `KeyboardInterrupt`.
- **Fix**: Implemented `os._exit(0)` in the interrupt handler to cleanly terminate the process and all threads.

### 4. UART TX FIFO Optimization (`uart_tx_fifo.v`)
- **Recommendation**: Removed asynchronous reset loops inside the memory array to allow Vivado to correctly map the FIFO to dedicated Block RAM (BRAM) instead of consuming thousands of LUTs.

## Hardware Review & Progress Report

> [!IMPORTANT]
> **Status**: The pipeline is now functionally correct at the architectural level. The critical "vanishing Load" bug has been resolved.

### Critical Findings:
1. **The "Silent" Pipeline Freeze**: The most significant blocker was the `ex_mem_reg` stalling during memory reads. Because the pipeline was technically still "running" but skipping memory loads, the firmware would loop infinitely or jump to zero-value addresses.
2. **Instruction Set Mismatch**: The RV32F implementation is specialized. Users must ensure the compiler is restricted from using Fused Multiply-Add (FMA) unless the FPU is upgraded to support the 3-op instruction format.
3. **UART Synchronization**: The 1-cycle latency match for UART reads in `top_fpga.v` is correctly implemented using `is_uart_read_r`, matching the BRAM timing.

### Recommendations for Future Development:
- **FPGA Utilization**: Monitor BRAM usage if the UART FIFO depth is increased.
- **FPU Exceptions**: Consider implementing IEEE-754 exception flags (Invalid, Overflow, etc.) in the CSR file for better debugging of edge-case math.
- **Timing Analysis**: As more features are added, check the "Set Up" and "Hold" times in Vivado, especially regarding the long paths through the FPU.

---
**Maintained by**: Antigravity AI & Purushottam Jha
**Date**: April 2026
