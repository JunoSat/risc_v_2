import sys

vcd_path = 'tb_uart_soc.vcd'
tx_var_id = None

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var wire 1' in line and 'uart_tx ' in line:
            parts = line.split()
            tx_var_id = parts[3]
            break

if not tx_var_id:
    print("uart_tx not found!")
    sys.exit(1)

tx_edges = 0
with open(vcd_path, 'r') as f:
    for line in f:
        if line.endswith(tx_var_id + '\n') and (line.startswith('0') or line.startswith('1')):
            tx_edges += 1

print(f"uart_tx transitioned {tx_edges} times!")
