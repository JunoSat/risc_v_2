import sys

vcd_path = 'tb_uart_soc.vcd'
tx_var_id = None
clk_var_id = None

with open(vcd_path, 'r') as f:
    for line in f:
        if '$var wire 1' in line and ' uart_tx ' in line:
            tx_var_id = line.split()[3]
        if '$var wire 1' in line and ' clk ' in line:
            clk_var_id = line.split()[3]

if not tx_var_id or not clk_var_id:
    print("Variables not found!", tx_var_id, clk_var_id)
    sys.exit(1)

tx_val = 1
time = 0
edges = []

with open(vcd_path, 'r') as f:
    for line in f:
        if line.startswith('#'):
            time = int(line[1:].strip())
        elif line.strip() == f"0{tx_var_id}":
            edges.append((time, 0))
            tx_val = 0
        elif line.strip() == f"1{tx_var_id}":
            edges.append((time, 1))
            tx_val = 1

# UART Decode
# 115200 baud = 868 clks per bit = 8680ns per bit
bit_time = 8680
chars = []
idx = 0

while idx < len(edges):
    # Find next falling edge (start bit)
    if edges[idx][1] == 0:
        start_time = edges[idx][0]
        
        # Sample bits at start_time + bit_time*1.5, 2.5, ..., 8.5
        val = 0
        for b in range(8):
            sample_time = start_time + bit_time * (b + 1.5)
            # Find the value at sample_time
            # Find the last edge before sample_time
            sample_val = 0
            for i in range(idx, len(edges)):
                if edges[i][0] > sample_time:
                    sample_val = edges[i-1][1] if i > 0 else 0
                    break
            else:
                sample_val = edges[-1][1]
            val |= (sample_val << b)
        chars.append(chr(val))
        
        # Advance index past this character
        end_time = start_time + bit_time * 10
        while idx < len(edges) and edges[idx][0] < end_time:
            idx += 1
    else:
        idx += 1

print("Transmitted:", chars, "Total edges:", len(edges))
