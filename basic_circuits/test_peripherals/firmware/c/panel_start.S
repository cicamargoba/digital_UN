.option norvc
.option norelax
.section .text.start
.global _start
_start:
    li sp, 0x1000
    li sp, 0x1000
    la gp, __global_pointer$
    la t0, __bss_start
    la t1, __bss_end
clear_bss:
    bgeu t0, t1, call_main
    sw zero, 0(t0)
    addi t0, t0, 4
    j clear_bss
call_main:
    call main
halt:
    j halt
