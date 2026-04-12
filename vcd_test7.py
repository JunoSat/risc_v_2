import sys

vcd_path = 'tb_uart_soc.vcd'
vars = {
    'forward_b_sel': None,
    'id_ex_rs2': None,
    'ex_mem_rd': None,
    'ex_write_data_calc': None,
    'mem_write_data': None,
    'dmem_write_data': None,
    'uart_tx_start': None
}

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var' in line:
            parts = line.split()
            for v in vars:
                if f' {v} ' in line:
                    vars[v] = parts[3]

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
                if 45000 <= time <= 65000:
                    print(f"Time {time}: {id_to_var[parts[1]]} = {val}")
        elif line.strip() in [f"0{v}" for v in id_to_var] or line.strip() in [f"1{v}" for v in id_to_var]:
            val = line[0]
            var = id_to_var[line[1:].strip()]
            state[var] = val
            if 45000 <= time <= 65000:
                print(f"Time {time}: {var} = {val}")
