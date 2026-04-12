import sys

vcd_path = 'tb_uart_soc.vcd'
tx_var_id = None
time_scale = 1 # assume 1ns

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var wire 1' in line and ' uart_tx ' in line:
            tx_var_id = line.split()[3]

edges = []
with open(vcd_path, 'r') as f:
    time = 0
    tx_val = 1
    for line in f:
        if line.startswith('#'):
            time = int(line[1:].strip())
        elif line.strip() == f"0{tx_var_id}":
            edges.append((time, 0))
            tx_val = 0
        elif line.strip() == f"1{tx_var_id}":
            edges.append((time, 1))
            tx_val = 1

# Analyze edges
baud = 115200
bit_ns = 1e9 / baud
print(f"Expected bit duration: {bit_ns} ns")

prev_time = 0
for t, v in edges:
    duration = t - prev_time
    bits = round(duration / bit_ns)
    print(f"At {t} ns, val changed to {v}. Last state held for {bits} bits ({duration} ns)")
    prev_time = t
