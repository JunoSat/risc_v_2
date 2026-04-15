.section .init
.globl _start

_start:
    # Initialize Stack Pointer to the absolute top of 4KB DMEM (0x1000)
    li sp, 0x1000
    
    # Jump to C main function
    jal ra, main

halt:
    j halt
