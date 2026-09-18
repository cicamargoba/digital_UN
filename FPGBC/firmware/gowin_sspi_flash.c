#include "gowin_sspi_flash.h"
#include "gowin_sspi_platform.h"

#include <stddef.h>

static void sspi_cs_low(void)
{
    gowin_gpio_write(PIN_SSPI_CS_N, false);
    gowin_delay_us(1);
}

static void sspi_cs_high(void)
{
    gowin_gpio_write(PIN_SSPI_CS_N, true);
    gowin_delay_us(1);
}

static void sspi_idle_clocks(unsigned bytes)
{
    sspi_cs_high();
    while (bytes--) {
        gowin_spi_xfer(0xFF);
    }
}

/* Gowin SSPI commands. */
#define GOWIN_CMD_READ_ID            0x11
#define GOWIN_CMD_READ_STATUS        0x41
#define GOWIN_CMD_PROGRAM_SPI_FLASH  0x16

/* JEDEC SPI NOR commands. */
#define FLASH_CMD_READ_ID        0x9F
#define FLASH_CMD_WRITE_ENABLE   0x06
#define FLASH_CMD_READ_STATUS1   0x05
#define FLASH_CMD_READ_DATA      0x03
#define FLASH_CMD_PAGE_PROGRAM   0x02
#define FLASH_CMD_SECTOR_ERASE   0x20

#define FLASH_SR1_WIP            0x01
#define FLASH_SR1_WEL            0x02

#define FLASH_PAGE_SIZE          256u
#define FLASH_SECTOR_SIZE        4096u
#define W25Q16_SIZE              0x200000u

typedef enum {
    FPGA_MODE_MSPI = 0,  /* MODE[2:0] = 000 */
    FPGA_MODE_SSPI = 1,  /* MODE[2:0] = 001 */
} fpga_mode_t;

static void fpga_set_mode(fpga_mode_t mode)
{
    gowin_gpio_write(PIN_MODE2, false);
    gowin_gpio_write(PIN_MODE1, false);
    gowin_gpio_write(PIN_MODE0, mode == FPGA_MODE_SSPI);
    gowin_delay_us(10);
}

static void fpga_pulse_reconfig(void)
{
    gowin_gpio_write(PIN_RECONFIG_N, true);
    gowin_delay_us(10);

    gowin_gpio_write(PIN_RECONFIG_N, false);
    gowin_delay_us(50);

    gowin_gpio_write(PIN_RECONFIG_N, true);
    gowin_delay_ms(2);
}

static bool fpga_wait_ready(uint32_t timeout_ms)
{
    while (timeout_ms--) {
        if (gowin_gpio_read(PIN_READY)) {
            return true;
        }
        gowin_delay_ms(1);
    }
    return false;
}

static bool fpga_wait_done(uint32_t timeout_ms)
{
    while (timeout_ms--) {
        if (gowin_gpio_read(PIN_DONE)) {
            return true;
        }
        gowin_delay_ms(1);
    }
    return false;
}

static void gowin_send_cmd16(uint8_t cmd, uint8_t arg)
{
    sspi_idle_clocks(1);

    sspi_cs_low();
    gowin_spi_xfer(cmd);
    gowin_spi_xfer(arg);
    sspi_cs_high();

    sspi_idle_clocks(1);
}

static uint32_t gowin_read32(uint8_t cmd)
{
    uint32_t value = 0;

    sspi_idle_clocks(1);
    sspi_cs_low();

    gowin_spi_xfer(cmd);
    gowin_spi_xfer(0x00);
    gowin_spi_xfer(0x00);
    gowin_spi_xfer(0x00);

    value |= ((uint32_t)gowin_spi_xfer(0xFF)) << 24;
    value |= ((uint32_t)gowin_spi_xfer(0xFF)) << 16;
    value |= ((uint32_t)gowin_spi_xfer(0xFF)) << 8;
    value |= ((uint32_t)gowin_spi_xfer(0xFF));

    sspi_cs_high();
    sspi_idle_clocks(1);

    return value;
}

static bool gowin_enter_sspi(void)
{
    fpga_set_mode(FPGA_MODE_SSPI);
    fpga_pulse_reconfig();

    if (!fpga_wait_ready(500)) {
        return false;
    }

    sspi_idle_clocks(4);
    return true;
}

/*
 * Después de 0x16 0x00, la FPGA debe encaminar SSPI hacia la flash MSPI.
 * A partir de este punto se usan comandos JEDEC y no comandos Gowin.
 */
static void gowin_enter_spi_flash_direct(void)
{
    gowin_send_cmd16(GOWIN_CMD_PROGRAM_SPI_FLASH, 0x00);
    gowin_delay_us(10);
}

static void flash_addr24(uint32_t addr)
{
    gowin_spi_xfer((uint8_t)(addr >> 16));
    gowin_spi_xfer((uint8_t)(addr >> 8));
    gowin_spi_xfer((uint8_t)addr);
}

static uint32_t flash_read_jedec_id(void)
{
    uint32_t id = 0;

    sspi_cs_low();
    gowin_spi_xfer(FLASH_CMD_READ_ID);
    id |= ((uint32_t)gowin_spi_xfer(0xFF)) << 16;
    id |= ((uint32_t)gowin_spi_xfer(0xFF)) << 8;
    id |= ((uint32_t)gowin_spi_xfer(0xFF));
    sspi_cs_high();

    return id;
}

static uint8_t flash_read_status1(void)
{
    uint8_t status;

    sspi_cs_low();
    gowin_spi_xfer(FLASH_CMD_READ_STATUS1);
    status = gowin_spi_xfer(0xFF);
    sspi_cs_high();

    return status;
}

static bool flash_wait_ready(uint32_t timeout_ms)
{
    while (timeout_ms--) {
        if ((flash_read_status1() & FLASH_SR1_WIP) == 0) {
            return true;
        }
        gowin_delay_ms(1);
    }
    return false;
}

static void flash_write_enable(void)
{
    sspi_cs_low();
    gowin_spi_xfer(FLASH_CMD_WRITE_ENABLE);
    sspi_cs_high();
}

static bool flash_wait_wel(uint32_t timeout_ms)
{
    while (timeout_ms--) {
        if (flash_read_status1() & FLASH_SR1_WEL) {
            return true;
        }
        gowin_delay_ms(1);
    }
    return false;
}

static bool flash_sector_erase_4k(uint32_t addr)
{
    flash_write_enable();
    if (!flash_wait_wel(100)) {
        return false;
    }

    sspi_cs_low();
    gowin_spi_xfer(FLASH_CMD_SECTOR_ERASE);
    flash_addr24(addr);
    sspi_cs_high();

    return flash_wait_ready(5000);
}

static bool flash_page_program(uint32_t addr,
                               const uint8_t *data,
                               uint32_t len)
{
    if (len == 0 || len > FLASH_PAGE_SIZE) {
        return false;
    }
    if ((addr & 0xFFu) + len > FLASH_PAGE_SIZE) {
        return false;
    }

    flash_write_enable();
    if (!flash_wait_wel(100)) {
        return false;
    }

    sspi_cs_low();
    gowin_spi_xfer(FLASH_CMD_PAGE_PROGRAM);
    flash_addr24(addr);
    for (uint32_t i = 0; i < len; ++i) {
        gowin_spi_xfer(data[i]);
    }
    sspi_cs_high();

    return flash_wait_ready(1000);
}

static void flash_read(uint32_t addr, uint8_t *data, uint32_t len)
{
    sspi_cs_low();
    gowin_spi_xfer(FLASH_CMD_READ_DATA);
    flash_addr24(addr);
    for (uint32_t i = 0; i < len; ++i) {
        data[i] = gowin_spi_xfer(0xFF);
    }
    sspi_cs_high();
}

static bool erase_flash_range(uint32_t base, uint32_t size)
{
    uint32_t start = base & ~(FLASH_SECTOR_SIZE - 1u);
    uint32_t end;

    if (size == 0 || base >= W25Q16_SIZE || size > (W25Q16_SIZE - base)) {
        return false;
    }

    end = (base + size + FLASH_SECTOR_SIZE - 1u) &
          ~(FLASH_SECTOR_SIZE - 1u);

    for (uint32_t addr = start; addr < end; addr += FLASH_SECTOR_SIZE) {
        if (!flash_sector_erase_4k(addr)) {
            return false;
        }
    }
    return true;
}

static bool program_flash_image(uint32_t flash_base,
                                uint32_t image_size,
                                image_read_fn read_image,
                                void *ctx)
{
    uint8_t page[FLASH_PAGE_SIZE];

    if (read_image == NULL || !erase_flash_range(flash_base, image_size)) {
        return false;
    }

    for (uint32_t off = 0; off < image_size; off += FLASH_PAGE_SIZE) {
        uint32_t chunk = image_size - off;
        if (chunk > FLASH_PAGE_SIZE) {
            chunk = FLASH_PAGE_SIZE;
        }

        for (uint32_t i = 0; i < FLASH_PAGE_SIZE; ++i) {
            page[i] = 0xFF;
        }
        if (!read_image(ctx, off, page, chunk)) {
            return false;
        }
        if (!flash_page_program(flash_base + off, page, chunk)) {
            return false;
        }
    }
    return true;
}

static bool verify_flash_image(uint32_t flash_base,
                               uint32_t image_size,
                               image_read_fn read_image,
                               void *ctx)
{
    uint8_t expected[FLASH_PAGE_SIZE];
    uint8_t actual[FLASH_PAGE_SIZE];

    for (uint32_t off = 0; off < image_size; off += FLASH_PAGE_SIZE) {
        uint32_t chunk = image_size - off;
        if (chunk > FLASH_PAGE_SIZE) {
            chunk = FLASH_PAGE_SIZE;
        }

        if (!read_image(ctx, off, expected, chunk)) {
            return false;
        }
        flash_read(flash_base + off, actual, chunk);
        for (uint32_t i = 0; i < chunk; ++i) {
            if (expected[i] != actual[i]) {
                return false;
            }
        }
    }
    return true;
}

bool gowin_detect_external_flash(uint32_t *jedec_id)
{
    uint32_t id;

    if (jedec_id == NULL) {
        return false;
    }

    *jedec_id = 0;

    if (!gowin_enter_sspi()) {
        return false;
    }

    /* Verifica primero que el enlace SSPI con la FPGA responde. */
    (void)gowin_read32(GOWIN_CMD_READ_ID);
    (void)gowin_read32(GOWIN_CMD_READ_STATUS);

    gowin_enter_spi_flash_direct();
    id = flash_read_jedec_id();

    if (id == 0x000000u || id == 0xFFFFFFu) {
        return false;
    }

    *jedec_id = id;
    return true;
}

bool gowin_program_external_flash_from_image(uint32_t flash_base,
                                             uint32_t image_size,
                                             image_read_fn read_image,
                                             void *ctx)
{
    uint32_t fpga_id;
    uint32_t fpga_status;
    uint32_t flash_id;

    if (!gowin_enter_sspi()) {
        return false;
    }

    fpga_id = gowin_read32(GOWIN_CMD_READ_ID);
    fpga_status = gowin_read32(GOWIN_CMD_READ_STATUS);
    (void)fpga_id;
    (void)fpga_status;

    gowin_enter_spi_flash_direct();
    flash_id = flash_read_jedec_id();
    if (flash_id == 0x000000u || flash_id == 0xFFFFFFu) {
        return false;
    }

    if (!program_flash_image(flash_base, image_size, read_image, ctx)) {
        return false;
    }
    return verify_flash_image(flash_base, image_size, read_image, ctx);
}

bool gowin_boot_from_external_flash(void)
{
    fpga_set_mode(FPGA_MODE_MSPI);
    fpga_pulse_reconfig();
    return fpga_wait_done(2000);
}
