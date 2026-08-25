#include "blink.h"

void blink_start(uint32_t period_cycles)
{
    BLINK_CONTROL_REG = 0u;
    BLINK_PERIOD_REG = period_cycles;
    BLINK_CONTROL_REG = 1u;
}

void blink_stop(void)
{
    BLINK_CONTROL_REG = 0u;
}
