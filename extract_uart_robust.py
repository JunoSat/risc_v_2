import sys
import os

vcd_path = 'tb_uart_soc.vcd'
if not os.path.exists(vcd_path):
    print(f"Error: {vcd_path} not found.")
    sys.exit(1)

# We want the signals inside the "dut" scope specifically to avoid intermediate flickers
target_ids = {'dmem_write_data': None, 'uart_tx_start': None}
current_scope = ""

with open(vcd_path, 'r') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        if line.startswith('$scope'):
            current_scope = line.split()[2]
        if line.startswith('$var') and 'dut' in current_scope:
            parts = line.split()
            # ID is usually parts[3], name is parts[4]
            name = parts[4]
            if name in target_ids and target_ids[name] is None:
                target_ids[name] = parts[3]
        if '$enddefinitions' in line:
            break

id_to_var = {v: k for k, v in target_ids.items() if v}
state = {'dmem_write_data': '0', 'uart_tx_start': '0'}
last_captured_timestamp = -1
output_chars = []

print(f"--- ANALYZING TOP-LEVEL UART (IDs: Data={target_ids['dmem_write_data']}, Start={target_ids['uart_tx_start']}) ---")

with open(vcd_path, 'r') as f:
    current_time = 0
    for line in f:
        line = line.strip()
        if not line: continue
        
        if line[0] == '#':
            current_time = int(line[1:])
            continue
        
        # Check for bit changes
        if line[0] == 'b':
            parts = line.split()
            if len(parts) == 2 and parts[1] in id_to_var:
                state[id_to_var[parts[1]]] = parts[0][1:]
        else:
            val = line[0]
            vid = line[1:]
            if vid in id_to_var:
                state[id_to_var[vid]] = val
                
                # Check for RISING EDGE of uart_tx_start
                if id_to_var[vid] == 'uart_tx_start' and val == '1':
                    # Capture data only ONCE per clock cycle (pulse)
                    if current_time != last_captured_timestamp:
                        d_raw = state['dmem_write_data']
                        d_clean = d_raw.replace('x', '0').replace('z', '0')
                        try:
                            char_code = int(d_clean, 2) & 0xFF
                            if 10 <= char_code <= 127: # Printable + Newlines
                                sys.stdout.write(chr(char_code))
                                sys.stdout.flush()
                                output_chars.append(chr(char_code))
                                last_captured_timestamp = current_time
                        except:
                            pass

print("\n\n--- EXTRACTION COMPLETE ---")
