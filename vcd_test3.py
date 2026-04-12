import sys

vcd_path = 'tb_uart_soc.vcd'
start_id = None
data_id = None

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var wire 1' in line and ' uart_tx_start ' in line:
            start_id = line.split()[3]
        if '$var wire 32' in line and ' dmem_write_data ' in line:
            data_id = line.split()[3]

if not start_id or not data_id:
    print("Variables not found!")
    sys.exit(1)

with open(vcd_path, 'r') as f:
    time = 0
    for line in f:
        if line.startswith('#'):
            time = int(line[1:].strip())
        elif line.strip() == f"1{start_id}":
            print(f"Time {time}: uart_tx_start asserting! We need to know dmem_write_data!")
