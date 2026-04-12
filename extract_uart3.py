"""Extract UART TX bytes from VCD by watching uart_tx_start and dmem_write_data"""
import sys

vcd_path = 'tb_uart_soc.vcd'
vars = {'uart_tx_start': None, 'dmem_write_data': None}

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var' in line:
            parts = line.split()
            for v in vars:
                if f' {v} ' in line and vars[v] is None:
                    vars[v] = parts[3]
        if '$enddefinitions' in line:
            break

id_to_var = {v: k for k, v in vars.items() if v}
state = {k: '0' for k in vars}
tx_active = False
chars = []

with open(vcd_path, 'r') as f:
    time = 0
    for line in f:
        if line.startswith('#'):
            time = int(line[1:].strip())
        elif line.startswith('b'):
            parts = line.strip().split()
            if len(parts) == 2 and parts[1] in id_to_var:
                state[id_to_var[parts[1]]] = parts[0][1:]
        elif len(line.strip()) >= 2:
            bit = line.strip()[0]
            var_id = line.strip()[1:]
            if var_id in id_to_var and bit in ('0', '1'):
                state[id_to_var[var_id]] = bit
                
                if id_to_var[var_id] == 'uart_tx_start' and bit == '1':
                    val = int(state['dmem_write_data'], 2) if state['dmem_write_data'] != '0' else 0
                    byte_val = val & 0xFF
                    chars.append(chr(byte_val) if 32 <= byte_val < 127 else f'\\x{byte_val:02x}')

# Print the output as it would appear on terminal
output = ''.join(chars)
print(f"UART Output ({len(chars)} bytes):")
print("---")
print(output)
print("---")
