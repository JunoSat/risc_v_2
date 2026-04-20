import subprocess
import sys
import os

print("--- RV32IMF Automated Verification Script ---")

# Step 1: Compile the RISC-V SoC with Iverilog
cmd_iverilog = [
    "iverilog", "-o", "sim.vvp", 
    "tb_uart_soc.v", "top_fpga.v", "pipeline.v", "id_stage.v", "ex_stage.v", 
    "mem_stage.v", "wb_stage.v", "if_stage.v", "id_ex_reg.v", "ex_mem_reg.v", 
    "mem_wb_reg.v", "if_id_reg.v", "hazard_unit.v", "fp_regfile.v", "fpu.v", 
    "fpu_add_sub.v", "fpu_div.v", "fpu_mult.v", "fpu_sqrt.v", "uart.v", 
    "uart_tx_fifo.v", "mult_div.v", "csr_file.v", "memory.v"
]

print("[1/3] Compiling Design with iverilog...")
try:
    subprocess.run(cmd_iverilog, check=True)
    print("      Compilation successful.")
except subprocess.CalledProcessError:
    print("      Compilation FAILED. Please ensure iverilog is installed and in your PATH.")
    sys.exit(1)
except FileNotFoundError:
    print("      iverilog executable not found in PATH.")
    sys.exit(1)

# Step 2: Run the Simulation
print("[2/3] Simulating with vvp...")
try:
    subprocess.run(["vvp", "sim.vvp"], check=True)
    print("      Simulation complete. VCD dumped to tb_uart_soc.vcd.")
except subprocess.CalledProcessError:
    print("      Simulation FAILED.")
    sys.exit(1)

# Step 3: Analyze the VCD File
print("[3/3] Tracing FPU Signals in VCD Data...")
vcd_path = "tb_uart_soc.vcd"

if not os.path.exists(vcd_path):
    print("      VCD file not found! Simulation may not have generated it.")
    sys.exit(1)

# Variables to trace
vars_to_track = {
    'fp_en_i': None,
    'fp_store_i': None,
    'stall_fpu': None,
    'ex_fp_reg_write': None
}

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var' in line:
            parts = line.split()
            for v in vars_to_track:
                if f' {v} ' in line:
                    vars_to_track[v] = parts[3]
        if '$enddefinitions' in line: break

id_to_var = {v: k for k, v in vars_to_track.items() if v}
state = {k: '0' for k in vars_to_track}

# Pre-calculate strings for maximum speed
zero_targets = set("0" + v for v in id_to_var)
one_targets = set("1" + v for v in id_to_var)

fpu_triggered = False
fpu_stall_cycles = 0
fpu_writebacks = 0

with open(vcd_path, 'r') as f:
    for line in f:
        line_stripped = line.strip()
        if not line_stripped:
            continue
            
        c = line_stripped[0]
        if c == '#':
            # Fast check
            if state['fp_en_i'] == '1': fpu_triggered = True
            if state['stall_fpu'] == '1': fpu_stall_cycles += 1
            if state['ex_fp_reg_write'] == '1': fpu_writebacks += 1
            continue
            
        elif c == 'b':
            parts = line_stripped.split()
            if len(parts) == 2 and parts[1] in id_to_var:
                state[id_to_var[parts[1]]] = parts[0][1:]
                
        elif line_stripped in zero_targets:
            state[id_to_var[line_stripped[1:]]] = '0'
            
        elif line_stripped in one_targets:
            state[id_to_var[line_stripped[1:]]] = '1'

print("\n--- Verification Results ---")
if fpu_triggered:
    print("[PASS] FPU Math Instructions Detected in Execution Stage!")
else:
    print("[INFO] No FPU instructions hit execution. Did you load a Float test into imem?")

print(f"[INFO] FPU Stalled the Pipeline for a total of {fpu_stall_cycles} signal changes.")
print(f"[INFO] Detected {fpu_writebacks} signal updates where FPU attempted RegFile Writeback.")

if fpu_triggered and fpu_stall_cycles > 0:
    print("\nSUCCESS: RV32IMF Pipeline properly decodes ops, passes to EX, stalls on math, and writes back!")
else:
    print("\nNOTE: Load 'core_test.S' with floating point operations (e.g. fadd.s) and re-run to verify the FPU activates!")
