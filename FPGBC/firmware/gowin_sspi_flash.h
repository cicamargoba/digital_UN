#ifndef GOWIN_SSPI_FLASH_H
#define GOWIN_SSPI_FLASH_H

#include <stdbool.h>
#include <stdint.h>

/*
 * Fuente de datos de la imagen. La implementación debe copiar exactamente
 * len bytes desde offset hacia dst y retornar true si la lectura fue válida.
 */
typedef bool (*image_read_fn)(void *ctx,
                              uint32_t offset,
                              uint8_t *dst,
                              uint32_t len);

/*
 * Entra al puente SSPI→MSPI y lee el JEDEC ID de la flash externa.
 * El valor retornado usa el formato 0xMMTTCC:
 * fabricante, tipo de memoria y capacidad.
 */
bool gowin_detect_external_flash(uint32_t *jedec_id);

/* Programa y verifica una imagen en la flash externa conectada al MSPI. */
bool gowin_program_external_flash_from_image(uint32_t flash_base,
                                             uint32_t image_size,
                                             image_read_fn read_image,
                                             void *ctx);

/* Cambia MODE[2:0] a MSPI, pulsa RECONFIG_N y espera DONE. */
bool gowin_boot_from_external_flash(void);

#endif
