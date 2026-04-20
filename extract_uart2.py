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
with open(vcd_path, 'r') as f:
    time = 0
    for line in f:
        if line.startswith('#'):
            time = int(line[1:].strip())
        elif line.startswith('b'):
            parts = line.strip().split()
            if len(parts) == 2 and parts[1] in id_to_var:
                val = parts[0][1:]
                state[id_to_var[parts[1]]] = val
                if id_to_var[parts[1]] == 'uart_tx_start' and val == '1':
                    d = state['dmem_write_data']
                    print(f"Time {time}: uart_tx_start=1, dmem_wdata={d} -> {hex(int(d,2)) if d else 'None'}")
                if id_to_var[parts[1]] == 'dmem_write_data' and state['uart_tx_start'] == '1':
                    try:
                        hex_val = hex(int(val, 2))
                        chr_val = chr(int(val, 2) & 0xFF)
                        print(f"Time {time}: dmem_wdata updated while uart_tx_start=1 to {val} -> {hex_val} ({chr_val})")
                    except ValueError:
                        print(f"Time {time}: dmem_wdata updated while uart_tx_start=1 to {val} -> UNKNOWN")
        elif line.strip() in [f"0{v}" for v in id_to_var] or line.strip() in [f"1{v}" for v in id_to_var]:
            val = line[0]
            var = id_to_var[line[1:].strip()]
            state[var] = val
            if var == 'uart_tx_start' and val == '1':
                d = state['dmem_write_data']
                try:
                    hex_val = hex(int(d, 2)) if d else 'None'
                    print(f"Time {time}: uart_tx_start=1, dmem_wdata={d} -> {hex_val}")
                except ValueError:
                    print(f"Time {time}: uart_tx_start=1, dmem_wdata={d} -> UNKNOWN")
