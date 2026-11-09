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

static void show_score(const char digits[4])
{
    for (uint32_t i = 0u; i < 4u; ++i)
        write_text(4u + i, (15u << TEXT_FOREGROUND_SHIFT) | (uint32_t)digits[i]);
}

static void add_ten_points(char digits[4])
{
    for (int i = 2; i >= 0; --i) {
        if (digits[i] != '9') {
            ++digits[i];
            break;
        }
        digits[i] = '0';
    }
}

int main(void)
{
    TEXT_WE = 0u;
    SPRITE_WE = 0u;

    for (uint32_t cell = 0u; cell < 64u; ++cell)
        write_text(cell, 0x20u);

    for (uint32_t slot = 0u; slot < 8u; ++slot)
        write_sprite(slot, 0u);

    const char *message = "PTS ";
    for (uint32_t i = 0u; i < 4u; ++i)
        write_text(i, (15u << TEXT_FOREGROUND_SHIFT) | (uint32_t)message[i]);
    char score[4] = {'0', '0', '0', '0'};
    show_score(score);

    write_sprite(0u, sprite_descriptor(12u, 12u, 0u, 14u));
    write_sprite(2u, sprite_descriptor(28u, 56u, 1u, 6u));

    int x = 0;
    int direction = 1;
    int projectile_y = 53;
    unsigned int reload_frames = 0u;
    for (;;) {
        write_sprite(1u, sprite_descriptor((uint32_t)x, 24u, 4u, 10u));
        if (projectile_y >= 9) {
            write_sprite(3u, sprite_descriptor(31u, (uint32_t)projectile_y, 2u, 12u));
            projectile_y -= 2;
        } else {
            write_sprite(3u, 0u);
            if (reload_frames == 0u) {
                add_ten_points(score);
                show_score(score);
            }
            ++reload_frames;
            if (reload_frames == 4u) {
                projectile_y = 53;
                reload_frames = 0u;
            }
        }
        wait_iterations(PANEL_FRAME_DELAY);
        x += direction;
        if (x == 56)
            direction = -1;
        else if (x == 0)
            direction = 1;
    }
}
