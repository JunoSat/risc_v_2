import sys

vcd_path = 'tb_uart_soc.vcd'
vars = {'dmem_write_data': None, 'uart_tx_start': None}

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var' in line:
            parts = line.split()
            for v in vars:
                if f' {v} ' in line:
                    vars[v] = parts[3]
        if '$enddefinitions' in line: break

id_to_var = {v: k for k, v in vars.items() if v}
state = {k: '0' for k in vars}

output_string = ""
last_tx_start = '0'

with open(vcd_path, 'r') as f:
    for line in f:
        if line.startswith('#'):
            continue
        elif line.startswith('b'):
            parts = line.strip().split()
            if len(parts) == 2 and parts[1] in id_to_var:
                state[id_to_var[parts[1]]] = parts[0][1:]
        elif line.strip() in [f"0{v}" for v in id_to_var] or line.strip() in [f"1{v}" for v in id_to_var]:
            val = line[0]
            var = id_to_var[line[1:].strip()]
            state[var] = val
            
            # Detect Positive Edge of uart_tx_start
            if var == 'uart_tx_start':
                if val == '1' and last_tx_start == '0':
                    d = state['dmem_write_data']
                    if d and not ('x' in d or 'z' in d):
                        char_code = int(d, 2) & 0xFF
                        if char_code < 128:
                            output_string += chr(char_code)
                last_tx_start = val

print("\n--- EXTRACTED UART TERMINAL OUTPUT ---")
print(output_string)
print("--------------------------------------\n")
