# Read hex file and create address map
with open('imem.hex', 'r') as f:
    lines = [l.strip() for l in f.readlines() if l.strip()]

for i, hexval in enumerate(lines[:60]):
    addr = i * 4
    val = int(hexval, 16)
    # Decode basic instruction fields
    opcode = val & 0x7F
    rd = (val >> 7) & 0x1F
    funct3 = (val >> 12) & 0x7
    rs1 = (val >> 15) & 0x1F
    rs2 = (val >> 20) & 0x1F
    funct7 = (val >> 25) & 0x7F
    imm_i = (val >> 20) & 0xFFF
    if imm_i & 0x800: imm_i -= 0x1000
    
    desc = ""
    if opcode == 0x13:  # I-type ALU
        if funct3 == 0: desc = f"addi x{rd}, x{rs1}, {imm_i}"
        elif funct3 == 1: desc = f"slli x{rd}, x{rs1}, {rs2}"
        elif funct3 == 5: desc = f"srli x{rd}, x{rs1}, {rs2}"
        elif funct3 == 7: desc = f"andi x{rd}, x{rs1}, {imm_i}"
        else: desc = f"alu_i x{rd}, x{rs1}, {imm_i} f3={funct3}"
    elif opcode == 0x33:  # R-type
        if funct7 == 1: desc = f"mul x{rd}, x{rs1}, x{rs2}" if funct3 == 0 else f"mulh/div x{rd}, x{rs1}, x{rs2}"
        elif funct7 == 0 and funct3 == 0: desc = f"add x{rd}, x{rs1}, x{rs2}"
        elif funct7 == 0x20 and funct3 == 0: desc = f"sub x{rd}, x{rs1}, x{rs2}"
        elif funct3 == 5 and funct7 == 0: desc = f"srl x{rd}, x{rs1}, x{rs2}"
        elif funct3 == 4: desc = f"xor x{rd}, x{rs1}, x{rs2}"
        else: desc = f"r-type x{rd}, x{rs1}, x{rs2} f3={funct3} f7={funct7}"
    elif opcode == 0x6F:  # JAL
        imm = ((val >> 31) << 20) | (((val >> 12) & 0xFF) << 12) | (((val >> 20) & 1) << 11) | (((val >> 21) & 0x3FF) << 1)
        if imm & 0x100000: imm -= 0x200000
        desc = f"jal x{rd}, PC+{imm}"
    elif opcode == 0x63:  # Branch
        imm = ((val >> 31) << 12) | (((val >> 7) & 1) << 11) | (((val >> 25) & 0x3F) << 5) | (((val >> 8) & 0xF) << 1)
        if imm & 0x1000: imm -= 0x2000
        names = {0: 'beq', 1: 'bne', 4: 'blt', 5: 'bge', 6: 'bltu', 7: 'bgeu'}
        bname = names.get(funct3, f'b?{funct3}')
        desc = f"{bname} x{rs1}, x{rs2}, PC+{imm}"
    elif opcode == 0x37:  # LUI
        desc = f"lui x{rd}, {val >> 12}"
    elif opcode == 0x23:  # Store
        imm_s = ((val >> 25) << 5) | ((val >> 7) & 0x1F)
        desc = f"sw x{rs2}, {imm_s}(x{rs1})"
    elif opcode == 0x03:  # Load
        desc = f"lw x{rd}, {imm_i}(x{rs1})"
    elif opcode == 0x67:  # JALR
        desc = f"jalr x{rd}, x{rs1}, {imm_i}"
    else:
        desc = f"? opcode={opcode:#x}"
    
    print(f"0x{addr:03x} ({addr:3d}): {hexval} -> {desc}")
