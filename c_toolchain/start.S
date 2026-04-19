.section .init
.globl _start

_start:
    # 1. Initialize Stack Pointer
    li sp, 0x2000
    
    # 2. Initialize Trap Vector
    la t0, _trap_handler
    csrw mtvec, t0
    
    # 3. Jump to C main function
    jal ra, main

halt:
    j halt

_trap_handler:
    # 1. SAVE CPU STATE (Push ALL 16 caller-saved registers)
    addi sp, sp, -64
    sw ra, 60(sp)
    sw t0, 56(sp)
    sw t1, 52(sp)
    sw t2, 48(sp)
    sw t3, 44(sp)
    sw t4, 40(sp)
    sw t5, 36(sp)
    sw t6, 32(sp)
    sw a0, 28(sp)
    sw a1, 24(sp)
    sw a2, 20(sp)
    sw a3, 16(sp)
    sw a4, 12(sp)
    sw a5, 8(sp)
    sw a6, 4(sp)
    sw a7, 0(sp)

    # 2. CALL C HANDLER
    csrr a0, mcause
    jal ra, c_trap_handler

    # 3. ADVANCE MEPC BY 4 BYTES
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0

    # 4. RESTORE CPU STATE (Pop ALL 16 caller-saved registers)
    lw ra, 60(sp)
    lw t0, 56(sp)
    lw t1, 52(sp)
    lw t2, 48(sp)
    lw t3, 44(sp)
    lw t4, 40(sp)
    lw t5, 36(sp)
    lw t6, 32(sp)
    lw a0, 28(sp)
    lw a1, 24(sp)
    lw a2, 20(sp)
    lw a3, 16(sp)
    lw a4, 12(sp)
    lw a5, 8(sp)
    lw a6, 4(sp)
    lw a7, 0(sp)
    addi sp, sp, 64

    # 5. RESUME PIPELINE
    mret