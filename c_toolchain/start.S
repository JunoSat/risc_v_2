.section .init
.globl _start

_start:
    # Initialize Stack Pointer to the absolute top of 8KB DMEM (0x2000)
    li sp, 0x2000
    
    # Initialize Trap Vector (exceptions will jump to _trap_handler)
    la t0, _trap_handler
    csrw mtvec, t0
    
    # ---------------------------------------------------------
    # TEST: Floating Point Test (RV32F)
    # ---------------------------------------------------------
    # 2.5 is approx 0x40200000, 3.5 is approx 0x40600000
    li t0, 0x40200000
    li t1, 0x40600000
    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    
    flw f1, 0(sp)
    flw f2, 4(sp)
    fadd.s f3, f1, f2
    fsw f3, 0(sp)
    
    lw a0, 0(sp)
    addi sp, sp, 8
    # ---------------------------------------------------------

    # Jump to C main function
    jal ra, main

halt:
    j halt

_trap_handler:
    jal ra, c_trap_handler
    j _start
