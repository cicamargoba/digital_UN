#ifndef H__FEMTORV32__H
#define H__FEMTORV32__H

#include "soc_memory_map.h"
#include <stdint.h>


#define RV32_FASTCODE

/* Standard library */
extern int  printf(const char *fmt,...); /* supports %s, %d, %x */
extern void exit(int);
extern void abort();
extern int  getchar();
extern int  putchar(int c);
extern int  puts(const char* s);

/* Timing */
extern uint32_t cycles();            /* gets the number of cycles since last reset       (needs NRV_COUNTERS_64) */
extern uint32_t milliseconds();      /* gets the number of milliseconds since last reset (needs NRV_COUNTERS_64) */
extern void wait_cycles(int cycles); /* waits for a number of cycles.       */
extern void milliwait(int ms);       /* waits for a number of milliseconds. */
extern void microwait(int us);       /* waits for a number of microseconds. */
#define delay(ms) milliwait(ms)

/* System */

extern int filesystem_init(); /* 
			       * needs to be called to access files on SDCard (fopen(),fread()...) 
			       * returns 0 on success, non-zero on error.
			       */


/* Specialized print functions (but one can use printf() instead) */
extern void print_string(const char* s);
extern void print_dec(int val);
extern void print_hex_digits(unsigned int val, int digits);
extern void print_hex(unsigned int val);


/********************* Memory-mapped IO *******************************************************/
#define IO_IN(address)       (*(volatile uint32_t *)(address))
#define IO_OUT(address,val)  (IO_IN(address) = (val))
#define LEDS(val)            IO_OUT(UART_CONTROL, val)

#define FEMTORV32_FREQ            27000000
#define FEMTORV32_COUNTER_BITS    SOC_CPU_COUNTER_BITS

/* Hardware math peripherals (unsigned, 16-bit) */
extern uint32_t hw_mult(uint16_t a, uint16_t b);  /* 16x16 -> 32 */
extern uint16_t hw_div(uint16_t a, uint16_t b);   /* 16/16 -> quotient */
extern uint16_t hw_sqrt(uint16_t a);              /* sqrt(16) -> 16 */

#endif
