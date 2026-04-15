.section .init
.globl _start

_start:
    # Initialize Stack Pointer to middle of 4KB DMEM (0x0800) to safely prevent edge-clipping
    li sp, 0x0800
    
    # Jump to C main function
    jal ra, main

halt:
    j halt
