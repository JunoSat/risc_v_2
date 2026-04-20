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
    # 1. SAVE CPU STATE (Push caller-saved registers to stack)
    addi sp, sp, -32
    sw ra, 28(sp)
    sw a0, 24(sp)
    sw a1, 20(sp)
    sw a2, 16(sp)
    sw t0, 12(sp)
    sw t1, 8(sp)
    sw t2, 4(sp)

    # 2. CALL C HANDLER
    csrr a0, mcause
    jal ra, c_trap_handler

    # 3. ADVANCE MEPC BY 4 BYTES
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0      # (Requires Hardware Fix below)

    # 4. RESTORE CPU STATE (Pop from stack)
    lw ra, 28(sp)
    lw a0, 24(sp)
    lw a1, 20(sp)
    lw a2, 16(sp)
    lw t0, 12(sp)
    lw t1, 8(sp)
    lw t2, 4(sp)
    addi sp, sp, 32

    # 5. RESUME PIPELINE
    mret