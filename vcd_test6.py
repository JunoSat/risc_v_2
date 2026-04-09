import sys

vcd_path = 'tb_uart_soc.vcd'
vars_to_track = {
    'dmem_write_data': None,
    'dmem_write_ready': None,
    'uart_tx_data': None,
    'uart_tx_start': None,
    'ex_write_data_calc': None,
    'mem_write_data': None
}

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var' in line:
            parts = line.split()
            # Match the variable name to its ID
            for var in vars_to_track:
                if f' {var} ' in line:
                    vars_to_track[var] = parts[3]

# Create a mapping from ID to variable name
id_to_var = {v: k for k, v in vars_to_track.items() if v}

state = {var: "0" for var in vars_to_track}

with open(vcd_path, 'r') as f:
    time = 0
    for line in f:
        if line.startswith('#'):
            time = int(line[1:].strip())
        elif line.startswith('b'):
            parts = line.strip().split()
            if len(parts) == 2 and parts[1] in id_to_var:
                var = id_to_var[parts[1]]
                val = parts[0][1:]
                state[var] = val
                if var == 'uart_tx_start' and val == '1':
                    print(f"Time {time}: uart_tx_start=1, dmem_wdata={state.get('dmem_write_data')}, mem_wdata={state.get('mem_write_data')}, ex_calc={state.get('ex_write_data_calc')}")
        elif line.strip() in [f"0{v}" for v in id_to_var] or line.strip() in [f"1{v}" for v in id_to_var]:
            val = line[0]
            var = id_to_var[line[1:].strip()]
            state[var] = val
            if var == 'uart_tx_start' and val == '1':
                print(f"Time {time}: uart_tx_start=1, dmem_wdata={state.get('dmem_write_data')}, mem_wdata={state.get('mem_write_data')}, ex_calc={state.get('ex_write_data_calc')}")
