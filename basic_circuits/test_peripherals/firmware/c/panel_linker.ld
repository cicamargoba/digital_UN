ENTRY(_start)
MEMORY
{
    BRAM (rwx) : ORIGIN = 0x0000, LENGTH = 0x1000
}
SECTIONS
{
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
        *(.rodata .rodata.* .srodata .srodata.*)
    } > BRAM
    .data : {
        . = ALIGN(4);
        *(.data .data.* .sdata .sdata.*)
    } > BRAM
    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > BRAM
    PROVIDE(__global_pointer$ = 0x800);
    ASSERT(__bss_end <= 0xf00, "Panel firmware leaves less than 256 bytes for the stack")
    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.eh_frame*) }
}
