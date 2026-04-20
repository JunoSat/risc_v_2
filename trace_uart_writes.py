vcd_path = 'tb_uart_soc.vcd'
track = {'dmem_write_address': None, 'dmem_write_ready': None, 'dmem_write_data': None}

with open(vcd_path) as f:
    for line in f:
        if '$var' in line:
            parts = line.split()
            for v in track:
                if (' ' + v + ' ') in line:
                    track[v] = parts[3]
        if '$enddefinitions' in line:
            break

print("Signal IDs found:", track)
idmap = {v: k for k, v in track.items() if v}
state = {k: '0' * 32 for k in track}
found = 0

with open(vcd_path) as f:
    time = 0
    for line in f:
        line = line.rstrip('\n')
        if line.startswith('#'):
            time = int(line[1:].strip())
        elif line.startswith('b'):
            parts = line.strip().split()
            if len(parts) == 2 and parts[1] in idmap:
                state[idmap[parts[1]]] = parts[0][1:]
        elif len(line) >= 2 and line[1:] in idmap:
            state[idmap[line[1:]]] = line[0]

        wr = state.get('dmem_write_ready', '0')
        addr_bin = state.get('dmem_write_address', '0' * 32)
        try:
            addr = int(addr_bin, 2)
        except ValueError:
            addr = 0

        if wr == '1' and addr >= 0x80000000 and found < 10:
            found += 1
            data_bin = state.get('dmem_write_data', '')
            try:
                data = int(data_bin, 2)
            except ValueError:
                data = 0
            c = chr(data & 0xFF) if 32 <= (data & 0xFF) < 127 else '?'
            print(f'Time {time}: UART STORE to 0x{addr:08X}  data=0x{data:08X}  char={c}')

        if time > 10_000_000:
            break

print(f'Done. Total UART stores to 0x8...: {found}')
