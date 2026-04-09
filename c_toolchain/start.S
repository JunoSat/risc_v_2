.section .init
.global _start

_start:
    li t0, 0x80000000
    li t1, 0x80000008

main_loop:    
wait_a:
    lw t3, 0(t1)
    andi t3, t3, 1
    bne t3, zero, wait_a
    li t2, 0x41
    sw t2, 0(t0)
    
wait_b:
    lw t3, 0(t1)
    andi t3, t3, 1
    bne t3, zero, wait_b
    li t2, 0x42
    sw t2, 0(t0)

wait_c:
    lw t3, 0(t1)
    andi t3, t3, 1
    bne t3, zero, wait_c
    li t2, 0x43
    sw t2, 0(t0)

wait_d:
    lw t3, 0(t1)
    andi t3, t3, 1
    bne t3, zero, wait_d
    li t2, 0x44
    sw t2, 0(t0)
    
    # Adding a newline to format PuTTY nicely
wait_nl:
    lw t3, 0(t1)
    andi t3, t3, 1
    bne t3, zero, wait_nl
    li t2, 0x0A
    sw t2, 0(t0)
    
wait_cr:
    lw t3, 0(t1)
    andi t3, t3, 1
    bne t3, zero, wait_cr
    li t2, 0x0D
    sw t2, 0(t0)
    
    j main_loop
