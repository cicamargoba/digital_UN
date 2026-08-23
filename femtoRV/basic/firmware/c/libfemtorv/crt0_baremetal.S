#include "include/soc_memory_map.h"

.text
.global _start
.type _start, @function

_start:
.option push
.option norelax
     li   gp, UART_BASE
     li   sp, SOC_RAM_SIZE_BYTES
     call main
     tail exit

