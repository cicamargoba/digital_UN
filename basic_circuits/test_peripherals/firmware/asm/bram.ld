MEMORY {
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x1000  /* 4 KiB RAM */
}
SECTIONS
{
    everything :
    {
        . = ALIGN(4);
        calculator.o (.text)
        *(.*)
    } >BRAM
}
