import sys

vcd_path = 'tb_uart_soc.vcd'
forward_b = None

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var wire 2' in line and ' forward_b_sel ' in line:
            forward_b = line.split()[3]

if forward_b:
    with open(vcd_path, 'r') as f:
        for line in f:
            if line.startswith('b'):
                parts = line.strip().split()
                if len(parts) == 2 and parts[1] == forward_b:
                    print(f"forward_b_sel changed to {parts[0][1:]}")
