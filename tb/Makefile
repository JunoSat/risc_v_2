# ===========================================================================
# RV32IMF SoC Comprehensive Testbench Makefile
# ===========================================================================
# Usage:
#   make tb1    - RV32IMF hazard/edge case test (via processor)
#   make tb2    - Standalone CORDIC unit test
#   make tb3    - Standalone Systolic Array unit test
#   make tb4    - CORDIC via processor
#   make tb5    - Systolic Array via processor
#   make tb6    - Full integration (CPU + FPU + CORDIC + Systolic)
#   make all    - Run all testbenches
#   make clean  - Remove all generated files
# ===========================================================================

CC      = riscv-none-elf-gcc
OBJCOPY = riscv-none-elf-objcopy
CFLAGS  = -O2 -march=rv32imf -mabi=ilp32 -ffp-contract=off -ffreestanding -nostdlib -mcmodel=medany -Wl,--no-warn-rwx-segments

# Path to shared toolchain files (relative to tb/)
TOOL = ../c_toolchain
RTL  = ..

# All RTL source files needed for a full SoC simulation
RTL_SRCS = $(RTL)/top_fpga.v $(RTL)/axi4_lite_master.v $(RTL)/axi_cordic_slave.v \
           $(RTL)/axi_systolic_4x4.v $(RTL)/cordic.v $(RTL)/pipeline.v \
           $(RTL)/memory.v $(RTL)/csr_file.v $(RTL)/fpu.v $(RTL)/fp_regfile.v \
           $(RTL)/hazard_unit.v $(RTL)/id_ex_reg.v $(RTL)/id_stage.v \
           $(RTL)/if_id_reg.v $(RTL)/if_stage.v $(RTL)/mem_stage.v \
           $(RTL)/mem_wb_reg.v $(RTL)/mult_div.v $(RTL)/wb_stage.v \
           $(RTL)/uart.v $(RTL)/uart_tx_fifo.v $(RTL)/bootloader.v \
           $(RTL)/ex_stage.v $(RTL)/ex_mem_reg.v

IVFLAGS = -Wall -I$(RTL)

.PHONY: all tb1 tb2 tb3 tb4 tb5 tb6 clean results

all: tb1 tb2 tb3 tb4 tb5 tb6
	@echo.
	@echo =======================================
	@echo   ALL 6 TESTBENCHES COMPLETED
	@echo   Results in tb/results/
	@echo =======================================

# ---------------------------------------------------------------------------
# Ensure results directory exists
# ---------------------------------------------------------------------------
results:
	@if not exist results mkdir results

# ---------------------------------------------------------------------------
# C Compilation: compile a .c file into imem.hex + dmem.hex
# ---------------------------------------------------------------------------
%.hex: %.c tb_common.h
	$(CC) $(CFLAGS) -T $(TOOL)/link.ld $(TOOL)/start.S $< -o program.elf
	$(OBJCOPY) -O binary program.elf program.bin
	python $(TOOL)/bin2hex.py program.bin imem.hex
	copy imem.hex dmem.hex >nul

# ===========================================================================
# TB1: RV32IMF Hazard & Edge Case Test (via processor)
# ===========================================================================
tb1: results test_rv32imf.hex
	@echo === Running TB1: RV32IMF Hazards ===
	iverilog $(IVFLAGS) -o tb1.vvp soc_harness.v tb1_rv32imf_hazards.v $(RTL_SRCS)
	vvp tb1.vvp > results/tb1_rv32imf_hazards.txt 2>&1
	@echo --- TB1 results ---
	@type results\tb1_rv32imf_hazards.txt

# ===========================================================================
# TB2: Standalone CORDIC
# ===========================================================================
tb2: results
	@echo === Running TB2: Standalone CORDIC ===
	iverilog $(IVFLAGS) -o tb2.vvp tb2_cordic_standalone.v $(RTL)/cordic.v
	vvp tb2.vvp > results/tb2_cordic_standalone.txt 2>&1
	@echo --- TB2 results ---
	@type results\tb2_cordic_standalone.txt

# ===========================================================================
# TB3: Standalone Systolic Array
# ===========================================================================
tb3: results
	@echo === Running TB3: Standalone Systolic ===
	iverilog $(IVFLAGS) -o tb3.vvp tb3_systolic_standalone.v $(RTL)/axi_systolic_4x4.v
	vvp tb3.vvp > results/tb3_systolic_standalone.txt 2>&1
	@echo --- TB3 results ---
	@type results\tb3_systolic_standalone.txt

# ===========================================================================
# TB4: CORDIC via Processor
# ===========================================================================
tb4: results test_cordic_proc.hex
	@echo === Running TB4: CORDIC via Processor ===
	iverilog $(IVFLAGS) -o tb4.vvp soc_harness.v tb4_cordic_processor.v $(RTL_SRCS)
	vvp tb4.vvp > results/tb4_cordic_processor.txt 2>&1
	@echo --- TB4 results ---
	@type results\tb4_cordic_processor.txt

# ===========================================================================
# TB5: Systolic Array via Processor
# ===========================================================================
tb5: results test_systolic_proc.hex
	@echo === Running TB5: Systolic via Processor ===
	iverilog $(IVFLAGS) -o tb5.vvp soc_harness.v tb5_systolic_processor.v $(RTL_SRCS)
	vvp tb5.vvp > results/tb5_systolic_processor.txt 2>&1
	@echo --- TB5 results ---
	@type results\tb5_systolic_processor.txt

# ===========================================================================
# TB6: Full Integration
# ===========================================================================
tb6: results test_full_integration.hex
	@echo === Running TB6: Full Integration ===
	iverilog $(IVFLAGS) -o tb6.vvp soc_harness.v tb6_full_integration.v $(RTL_SRCS)
	vvp tb6.vvp > results/tb6_full_integration.txt 2>&1
	@echo --- TB6 results ---
	@type results\tb6_full_integration.txt

# ===========================================================================
# Clean
# ===========================================================================
clean:
	@if exist *.vvp del *.vvp
	@if exist *.elf del *.elf
	@if exist *.bin del *.bin
	@if exist imem.hex del imem.hex
	@if exist dmem.hex del dmem.hex
	@if exist results rmdir /s /q results
	@echo Cleaned.
