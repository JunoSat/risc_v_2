.section .init
.global _start

_start:
    /* Initialize Stack Pointer to top of 4KB Data Memory (0x1000) */
    /* This allows C functions to use local variables safely! */
    li sp, 0x00001000
    
    /* Jump into the C main() function */
    call main

/* Halt catch if main somehow exits */
stop:
    j stop
