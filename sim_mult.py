def simulate_mult(rs1, rs2, op=0):
    divisor = rs1 & 0xFFFFFFFF
    accumulator = rs2 & 0xFFFFFFFF
    
    counter = 32
    while counter > 0:
        acc_top = (accumulator >> 32) & 0xFFFFFFFF
        acc_bot = accumulator & 0xFFFFFFFF
        
        mult_step_sum = acc_top + divisor
        
        if (accumulator & 1) == 1:
            # { mult_step_sum, accumulator[31:1] }
            new_acc = (mult_step_sum << 31) | (acc_bot >> 1)
            accumulator = new_acc
        else:
            accumulator = accumulator >> 1
            
        counter -= 1
        
    return accumulator

print(f"10 * 20 = {simulate_mult(10, 20)}")
