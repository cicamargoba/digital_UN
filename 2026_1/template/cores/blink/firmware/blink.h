#ifndef BLINK_H
#define BLINK_H

#include <stdint.h>

#define BLINK_BASE_ADDR   0x500000u
#define BLINK_CONTROL_REG (*(volatile uint32_t *)(BLINK_BASE_ADDR + 0x00u))
#define BLINK_PERIOD_REG  (*(volatile uint32_t *)(BLINK_BASE_ADDR + 0x04u))

void blink_start(uint32_t period_cycles);
void blink_stop(void);

#endif
