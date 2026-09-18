#include "usb_lib.h"
#include "usb_istr.h"
#include "usb_desc.h"
#include "usb_regs.h"
#include "usb_pwr.h"

#include "gowin_sspi_platform.h"
#include "board_config.h"

static bool usb_started;

static void usb_poll(void)
{
    if (usb_started && (_GetISTR() != 0u)) {
        USB_Istr();
    }
}

static void busy_delay(uint32_t loops)
{
    while (loops-- != 0u) {
        __NOP();
    }
}

static void gpio_output(GPIO_TypeDef *port, uint16_t pin, bool high)
{
    GPIO_InitTypeDef gpio;

    if (high) {
        GPIO_SetBits(port, pin);
    } else {
        GPIO_ResetBits(port, pin);
    }

    gpio.GPIO_Pin = pin;
    gpio.GPIO_Speed = GPIO_Speed_50MHz;
    gpio.GPIO_Mode = GPIO_Mode_Out_PP;
    GPIO_Init(port, &gpio);
}

static void gpio_input_pullup(GPIO_TypeDef *port, uint16_t pin)
{
    GPIO_InitTypeDef gpio;

    gpio.GPIO_Pin = pin;
    gpio.GPIO_Speed = GPIO_Speed_50MHz;
    gpio.GPIO_Mode = GPIO_Mode_IPU;
    GPIO_Init(port, &gpio);
}

void gowin_platform_init(void)
{
    RCC_APB2PeriphClockCmd(RCC_APB2Periph_AFIO |
                           RCC_APB2Periph_GPIOA |
                           RCC_APB2Periph_GPIOB,
                           ENABLE);

#if FPGBC_RECONFIG_ASSIGNED
    gpio_output(FPGBC_RECONFIG_PORT, FPGBC_RECONFIG_PIN, true);
#endif
#if FPGBC_SCLK_ASSIGNED
    gpio_output(FPGBC_SCLK_PORT, FPGBC_SCLK_PIN, false);
#endif
#if FPGBC_SI_ASSIGNED
    gpio_output(FPGBC_SI_PORT, FPGBC_SI_PIN, true);
#endif
#if FPGBC_SSPI_CS_ASSIGNED
    gpio_output(FPGBC_SSPI_CS_PORT, FPGBC_SSPI_CS_PIN, true);
#endif
#if FPGBC_CLKHOLD_ASSIGNED
    gpio_output(FPGBC_CLKHOLD_PORT, FPGBC_CLKHOLD_PIN, true);
#endif

#if FPGBC_READY_ASSIGNED
    gpio_input_pullup(FPGBC_READY_PORT, FPGBC_READY_PIN);
#endif
#if FPGBC_DONE_ASSIGNED
    gpio_input_pullup(FPGBC_DONE_PORT, FPGBC_DONE_PIN);
#endif
#if FPGBC_SO_ASSIGNED
    gpio_input_pullup(FPGBC_SO_PORT, FPGBC_SO_PIN);
#endif
}

void gowin_gpio_write(uint32_t pin, bool value)
{
    GPIO_TypeDef *port = 0;
    uint16_t gpio_pin = 0;

    switch (pin) {
    case PIN_RECONFIG_N:
#if FPGBC_RECONFIG_ASSIGNED
        port = FPGBC_RECONFIG_PORT;
        gpio_pin = FPGBC_RECONFIG_PIN;
#endif
        break;
    case PIN_SSPI_CS_N:
#if FPGBC_SSPI_CS_ASSIGNED
        port = FPGBC_SSPI_CS_PORT;
        gpio_pin = FPGBC_SSPI_CS_PIN;
#endif
        break;
    default:
        /* MODE[2:0] se consideran fijados por el hardware de la tarjeta. */
        return;
    }

    if (port == 0 || gpio_pin == 0u) {
        return;
    }

    if (value) {
        GPIO_SetBits(port, gpio_pin);
    } else {
        GPIO_ResetBits(port, gpio_pin);
    }
}

bool gowin_gpio_read(uint32_t pin)
{
    switch (pin) {
    case PIN_READY:
#if FPGBC_READY_ASSIGNED
        return GPIO_ReadInputDataBit(FPGBC_READY_PORT, FPGBC_READY_PIN) != Bit_RESET;
#else
        return false;
#endif
    case PIN_DONE:
#if FPGBC_DONE_ASSIGNED
        return GPIO_ReadInputDataBit(FPGBC_DONE_PORT, FPGBC_DONE_PIN) != Bit_RESET;
#else
        return false;
#endif
    default:
        return false;
    }
}

void gowin_delay_us(uint32_t us)
{
    while (us-- != 0u) {
        busy_delay(SystemCoreClock / 6000000u);
    }
}

void gowin_delay_ms(uint32_t ms)
{
    while (ms-- != 0u) {
        busy_delay(SystemCoreClock / 6000u);
        usb_poll();
    }
}

uint8_t gowin_spi_xfer(uint8_t tx)
{
#if !(FPGBC_SCLK_ASSIGNED && FPGBC_SI_ASSIGNED && FPGBC_SO_ASSIGNED)
    (void)tx;
    return 0xFFu;
#else
    uint8_t rx = 0;

    for (uint8_t mask = 0x80u; mask != 0u; mask >>= 1) {
        if ((tx & mask) != 0u) {
            GPIO_SetBits(FPGBC_SI_PORT, FPGBC_SI_PIN);
        } else {
            GPIO_ResetBits(FPGBC_SI_PORT, FPGBC_SI_PIN);
        }

        GPIO_SetBits(FPGBC_SCLK_PORT, FPGBC_SCLK_PIN);
        gowin_delay_us(1);
        rx <<= 1;
        if (GPIO_ReadInputDataBit(FPGBC_SO_PORT, FPGBC_SO_PIN) != Bit_RESET) {
            rx |= 1u;
        }
        GPIO_ResetBits(FPGBC_SCLK_PORT, FPGBC_SCLK_PIN);
        gowin_delay_us(1);
    }

    return rx;
#endif
}

void Delay_Ms(uint32_t ms)
{
    gowin_delay_ms(ms);
}

void USB_Port_Set(FunctionalState state, FunctionalState internal_pullup)
{
    RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA, ENABLE);

    if (state) {
        _SetCNTR(_GetCNTR() & (~(1u << 1)));
        GPIOA->CFGHR &= 0xFFF00FFFu;
        GPIOA->OUTDR &= ~(3u << 11);
        GPIOA->CFGHR |= 0x00044000u;
    } else {
        _SetCNTR(_GetCNTR() | (1u << 1));
        GPIOA->CFGHR &= 0xFFF00FFFu;
        GPIOA->OUTDR &= ~(3u << 11);
        GPIOA->CFGHR |= 0x00033000u;
    }

    if (internal_pullup) {
        EXTEN->EXTEN_CTR |= EXTEN_USBD_PU_EN;
    } else {
        EXTEN->EXTEN_CTR &= ~EXTEN_USBD_PU_EN;
    }
}

static void int_to_unicode(uint32_t value, uint8_t *buffer, uint8_t len)
{
    for (uint8_t i = 0; i < len; ++i) {
        uint8_t digit = (uint8_t)(value >> 28);
        if (digit < 10u) {
            buffer[2u * i] = (uint8_t)((uint8_t)'0' + digit);
        } else {
            buffer[2u * i] = (uint8_t)((uint8_t)'A' + digit - 10u);
        }
        buffer[2u * i + 1u] = 0;
        value <<= 4;
    }
}

static void usb_config(void)
{
    extern uint8_t USBD_StringSerial[];
    uint32_t serial0 = *(uint32_t *)0x1FFFF7E8u;
    uint32_t serial1 = *(uint32_t *)0x1FFFF7ECu;
    uint32_t serial2 = *(uint32_t *)0x1FFFF7F0u;

    RCC_USBCLKConfig(RCC_USBCLKSource_PLLCLK_Div3);
    RCC_APB1PeriphClockCmd(RCC_APB1Periph_USB, ENABLE);

    int_to_unicode(serial0 + serial2, &USBD_StringSerial[2], 8);
    int_to_unicode(serial1 + serial2, &USBD_StringSerial[18], 4);

    USB_Init();
    usb_started = true;
}

void gowin_serial_init(void)
{
    usb_config();
}

void gowin_serial_write(const uint8_t *data, uint32_t len)
{
    while (bDeviceState != CONFIGURED) {
        usb_poll();
    }

    while (len != 0u) {
        uint16_t chunk = len > CDC_BULK_IN_SZ ? CDC_BULK_IN_SZ : (uint16_t)len;

        while (GetEPTxStatus(ENDP3) != EP_TX_NAK) {
            usb_poll();
        }

        USB_SIL_Write(EP3_IN, (uint8_t *)data, chunk);
        SetEPTxValid(ENDP3);

        while (GetEPTxStatus(ENDP3) != EP_TX_NAK) {
            usb_poll();
        }

        data += chunk;
        len -= chunk;
    }
}
