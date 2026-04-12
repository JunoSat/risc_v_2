.eqv UART_TX,   0x80000000
.eqv UART_STAT, 0x80000008

.text
.globl _start
_start:
    # 1. Print 'T' to show booted
    li a0, 'T'
    jal ra, print_char

    # 2. Test ADD (10 + 20 = 30)
    li t3, 10
    li t4, 20
    add t5, t3, t4
    li t6, 30
    beq t5, t6, add_pass
    li a0, 'F'
    j add_print
add_pass:
    li a0, 'P' 
add_print:
    jal ra, print_char

    # 3. Test MUL (10 * 20 = 200)
    li t3, 10
    li t4, 20
    mul t5, t3, t4
    li t6, 200
    beq t5, t6, mul_pass
    li a0, 'X' 
    j mul_print
mul_pass:
    li a0, 'P' 
mul_print:
    jal ra, print_char

    # 4. Test SLLI (Shift Left Logical Immediate)
    # 2 << 2 = 8
    li t3, 2
    slli t5, t3, 2
    li t6, 8
    beq t5, t6, slli_pass
    li a0, 'L' # SLLI failed
    j slli_print
slli_pass:
    li a0, 'P'
slli_print:
    jal ra, print_char

    # 5. Test SRL (Shift Right Logical by Register)
    # 32 >> 2 = 8
    li t3, 32
    li t4, 2
    srl t5, t3, t4
    li t6, 8
    beq t5, t6, srl_pass
    li a0, 'R' # SRL failed
    j srl_print
srl_pass:
    li a0, 'P'
srl_print:
    jal ra, print_char

    # 6. Test ANDI 
    # 0xFA & 0x0F = 0x0A
    li t3, 0xFA
    andi t5, t3, 0x0F
    li t6, 0x0A
    beq t5, t6, andi_pass
    li a0, 'N' # ANDI failed
    j andi_print
andi_pass:
    li a0, 'P'
andi_print:
    jal ra, print_char

    # 7. Test BLT / BGT (pseudo)
    # 10 < 20
    li t3, 10
    li t4, 20
    blt t3, t4, blt_pass
    li a0, 'B' # Branch failed
    j blt_print
blt_pass:
    li a0, 'P'
blt_print:
    jal ra, print_char

halt:
    j halt

print_char:
    li t0, UART_STAT
    li t1, UART_TX
wait_uart:
    lw t2, 0(t0)
    andi t2, t2, 1
    bnez t2, wait_uart
    sw a0, 0(t1)
    ret
