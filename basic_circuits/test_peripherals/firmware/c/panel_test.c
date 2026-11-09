#include "libfemtorv/include/peripheral_registers.h"

#ifndef PANEL_FRAME_DELAY
#define PANEL_FRAME_DELAY 100000u
#endif

static void wait_iterations(uint32_t count)
{
    for (volatile uint32_t remaining = count; remaining != 0u; --remaining)
        ;
}

static void write_text(uint32_t cell, uint32_t value)
{
    TEXT_WE = 0u;
    TEXT_ADDR = cell;
    TEXT_DATA = value;
    TEXT_WE = 1u;
    wait_iterations(16u);
    TEXT_WE = 0u;
}

static uint32_t sprite_descriptor(uint32_t x, uint32_t y,
                                  uint32_t pattern, uint32_t color)
{
    return SPRITE_ENABLE | ((color & SPRITE_COLOR_MASK) << SPRITE_COLOR_SHIFT) |
           ((pattern & SPRITE_PATTERN_MASK) << SPRITE_PATTERN_SHIFT) |
           ((y & SPRITE_COORD_MASK) << SPRITE_Y_SHIFT) | (x & SPRITE_COORD_MASK);
}

static void write_sprite(uint32_t slot, uint32_t descriptor)
{
    SPRITE_WE = 0u;
    SPRITE_ADDR = slot;
    SPRITE_DATA = descriptor;
    SPRITE_WE = 1u;
    wait_iterations(10u);
    SPRITE_WE = 0u;
}

int main(void)
{
    TEXT_WE = 0u;
    SPRITE_WE = 0u;

    for (uint32_t cell = 0u; cell < 64u; ++cell)
        write_text(cell, 0x20u);

    for (uint32_t slot = 0u; slot < 8u; ++slot)
        write_sprite(slot, 0u);

    const char *message = "HOLA TU";
    for (uint32_t i = 0u; i < 7u; ++i)
        write_text(10u + i, (15u << 7) | (uint32_t)message[i]);

    write_sprite(1u, sprite_descriptor(28u, 24u, 4u, 10u));
    write_sprite(2u, sprite_descriptor(28u, 56u, 1u, 6u));

    int x = 0;
    int direction = 1;
    for (;;) {
        write_sprite(0u, sprite_descriptor((uint32_t)x, 40u, 0u, 14u));
        write_sprite(2u, sprite_descriptor((uint32_t)x*2, 56u, 1u, 6u));
        wait_iterations(PANEL_FRAME_DELAY);
        x += direction;
        if (x == 56)
            direction = -1;
        else if (x == 0)
            direction = 1;
    }
}
