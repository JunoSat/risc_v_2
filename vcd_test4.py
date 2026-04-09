import sys

vcd_path = 'tb_uart_soc.vcd'
data_id = None
start_id = None

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var wire 1' in line and ' uart_tx_start ' in line:
            start_id = line.split()[3]
        if '$var wire 32' in line and ' dmem_write_data ' in line:
            data_id = line.split()[3]

data_val = ""
with open(vcd_path, 'r') as f:
    time = 0
    for line in f:
        if line.startswith('#'):
            time = int(line[1:].strip())
        elif line.startswith('b'):
            parts = line.strip().split()
            if len(parts) == 2 and parts[1] == data_id:
                data_val = parts[0][1:] # omit 'b'
        elif line.strip() == f"1{start_id}":
            print(f"Time {time}: uart_tx_start=1, dmem_write_data={data_val}")
