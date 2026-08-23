#include "include/soc_memory_map.h"
	
#################################################################################	
# NanoRv UART support
#################################################################################

.global	putchar
.type	putchar, @function
putchar:
   sw a0, UART_DATA_OFFSET(gp)
   li   t0, UART_CONTROL_TX_WRITE
   sw   t0, UART_CONTROL_OFFSET(gp)
   li   t0, 0x00
   sw   t0, UART_CONTROL_OFFSET(gp)
   li t0, UART_STATUS_TX_BUSY
.L0:  
   lw t1, UART_CONTROL_OFFSET(gp)
   and t1, t1, t0
   bnez t1, .L0
  ret

.global	getchar
.type	getchar, @function
getchar:
        lw   a0, UART_CONTROL_OFFSET(gp) # read status register
        andi t0, a0, UART_STATUS_RX_AVAIL
        beqz t0, getchar            # no data, keep polling
        lw   a0, UART_DATA_OFFSET(gp) # read data register
        andi a0, a0, 255           # extract byte
        li   t0, UART_CONTROL_RX_ACK
        sw   t0, UART_CONTROL_OFFSET(gp) # assert rx_ack
        li   t0, 0x00
        sw   t0, UART_CONTROL_OFFSET(gp) # deassert rx_ack
        li   t0, 10                 # <enter> generates CR/LF, we ignore LF.
        beq  a0, t0, getchar
        ret
