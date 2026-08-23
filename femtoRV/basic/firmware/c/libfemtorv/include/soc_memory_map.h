#ifndef SOC_MEMORY_MAP_H
#define SOC_MEMORY_MAP_H

/* System configuration. */
#define SOC_RAM_SIZE_BYTES      0x00002000
#define SOC_CPU_COUNTER_BITS    32

/* Memory-mapped peripheral base addresses. */
#define UART_BASE               0x00400000
#define SQRT_BASE               0x00410000
#define MULT_BASE               0x00420000
#define DIV_BASE                0x00430000
#define BIN2BCD_BASE            0x00440000
#define DPRAM_BASE              0x00450000
#define BCD2BIN_BASE            0x00460000
#define WS2812_BASE             0x00470000

/* UART register offsets and absolute addresses. */
#define UART_DATA_OFFSET        0x08
#define UART_CONTROL_OFFSET     0x10
#define UART_DATA               (UART_BASE + UART_DATA_OFFSET)
#define UART_CONTROL            (UART_BASE + UART_CONTROL_OFFSET)

/* UART control/status bits. */
#define UART_CONTROL_TX_WRITE   0x001
#define UART_CONTROL_RX_ACK     0x002
#define UART_CONTROL_LED        0x004
#define UART_STATUS_RX_ERROR    0x080
#define UART_STATUS_RX_AVAIL    0x100
#define UART_STATUS_TX_BUSY     0x200

#endif
