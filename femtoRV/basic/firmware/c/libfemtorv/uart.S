.include "femtorv32.inc"
	
#################################################################################	
# NanoRv UART support
#################################################################################

.global	putchar
.type	putchar, @function
putchar:
   sw a0, IO_UART_DAT(gp)
   li   t0, 0x01
   sw   t0, IO_UART_CNTL(gp)
   li   t0, 0x00
   sw   t0, IO_UART_CNTL(gp)
   li t0, 1<<9
.L0:  
   lw t1, IO_UART_CNTL(gp)
   and t1, t1, t0
   bnez t1, .L0
  ret

.global	getchar
.type	getchar, @function
getchar:
        lw   a0, IO_UART_CNTL(gp)   # read status register
        andi t0, a0, 256            # bit 8 = rx_avail
        beqz t0, getchar            # no data, keep polling
        lw   a0, IO_UART_DAT(gp)   # read data register
        andi a0, a0, 255           # extract byte
        li   t0, 0x02              # rx_ack (bit 1)
        sw   t0, IO_UART_CNTL(gp)  # assert rx_ack (clears rx_avail)
        li   t0, 0x00
        sw   t0, IO_UART_CNTL(gp)  # deassert rx_ack
        li   t0, 10                 # <enter> generates CR/LF, we ignore LF.
        beq  a0, t0, getchar
        ret

