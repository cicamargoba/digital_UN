#include "gowin_sspi_flash.h"
#include "gowin_sspi_platform.h"
#include "board_config.h"

#include <stdbool.h>
#include <stdint.h>

static uint8_t hex_digit(uint8_t value)
{
    value &= 0x0Fu;
    if (value < 10u) {
        return (uint8_t)((uint8_t)'0' + value);
    }
    return (uint8_t)((uint8_t)'A' + value - 10u);
}

static void serial_text(const char *text)
{
    uint32_t len = 0;

    while (text[len] != '\0') {
        ++len;
    }
    gowin_serial_write((const uint8_t *)text, len);
}

static void serial_jedec_id(uint32_t id)
{
    static uint8_t message[] = "FLASH JEDEC ID: 00 00 00\r\n";
    static const uint8_t shifts[] = {20u, 16u, 12u, 8u, 4u, 0u};
    static const uint8_t positions[] = {16u, 17u, 19u, 20u, 22u, 23u};

    for (uint32_t i = 0; i < 6u; ++i) {
        message[positions[i]] = hex_digit((uint8_t)(id >> shifts[i]));
    }

    gowin_serial_write(message, sizeof(message) - 1u);
}

int main(void)
{
    uint32_t jedec_id;
    bool detected = false;

    gowin_platform_init();
    gowin_serial_init();

    serial_text("FPGBC flash probe\r\n");

#if !FPGBC_REQUIRED_PINS_ASSIGNED
    serial_text("ERROR: SSPI PIN CONFIG INCOMPLETE\r\n");
    for (;;) {
        gowin_delay_ms(1000);
    }
#endif

    for (;;) {
        if (!detected) {
            detected = gowin_detect_external_flash(&jedec_id);
        }

        if (detected) {
            serial_jedec_id(jedec_id);
        } else {
            serial_text("FLASH NOT DETECTED\r\n");
        }

        gowin_delay_ms(1000);
    }
}
