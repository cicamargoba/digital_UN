#ifndef GOWIN_SSPI_PLATFORM_H
#define GOWIN_SSPI_PLATFORM_H

#include <stdbool.h>
#include <stdint.h>

/*
 * Capa que debe implementar el firmware CH32V203.
 * Los identificadores de pin predeterminados son abstractos y pueden
 * reemplazarse con -DPIN_<nombre>=<valor> o desde el HAL de la aplicación.
 */
#ifndef PIN_MODE0
#define PIN_MODE0       0u
#endif
#ifndef PIN_MODE1
#define PIN_MODE1       1u
#endif
#ifndef PIN_MODE2
#define PIN_MODE2       2u
#endif
#ifndef PIN_RECONFIG_N
#define PIN_RECONFIG_N  3u
#endif
#ifndef PIN_READY
#define PIN_READY       4u
#endif
#ifndef PIN_DONE
#define PIN_DONE        5u
#endif
#ifndef PIN_SSPI_CS_N
#define PIN_SSPI_CS_N   6u
#endif

void gowin_gpio_write(uint32_t pin, bool value);
bool gowin_gpio_read(uint32_t pin);
void gowin_delay_us(uint32_t us);
void gowin_delay_ms(uint32_t ms);

/* Transferencia SPI full-duplex de 8 bits, modo definido por Gowin SSPI. */
uint8_t gowin_spi_xfer(uint8_t tx);

/* Servicios mínimos requeridos por el programa de prueba. */
void gowin_platform_init(void);
void gowin_serial_init(void);
void gowin_serial_write(const uint8_t *data, uint32_t len);

#endif
