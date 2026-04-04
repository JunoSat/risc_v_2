import sys

def verilog_div(rs1, rs2):
    accumulator = rs1
    divisor = rs2
    for counter in range(32, 0, -1):
        div_shifted = (accumulator << 1) & ((1 << 64) - 1)
        div_upper = (div_shifted >> 32) & 0xFFFFFFFF
        div_sub_ok = div_upper >= divisor
        
        if div_sub_ok:
            div_sub_val = div_upper - divisor
            acc_lower = ((div_shifted & 0xFFFFFFFF) >> 1) & 0x7FFFFFFF
            accumulator = (div_sub_val << 32) | (acc_lower << 1) | 1
        else:
            acc_lower = ((div_shifted & 0xFFFFFFFF) >> 1) & 0x7FFFFFFF
            accumulator = (div_upper << 32) | (acc_lower << 1) | 0
            
    quo = accumulator & 0xFFFFFFFF
    mod = (accumulator >> 32) & 0xFFFFFFFF
    
    print(f"rs1={rs1} rs2={rs2} -> quo=0x{quo:08X} ({quo}) mod={mod}")

verilog_div(8, 3)
