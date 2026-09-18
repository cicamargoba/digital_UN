#ifndef FPGBC_BOARD_CONFIG_H
#define FPGBC_BOARD_CONFIG_H

#include "ch32v20x.h"

/*
 * Único archivo que debe modificarse cuando se complete el pinout.
 * Cada señal tiene un indicador *_ASSIGNED. No se accede a una señal cuyo
 * indicador sea cero.
 */
#define FPGBC_READY_ASSIGNED       1
#define FPGBC_READY_PORT       GPIOA
#define FPGBC_READY_PIN        GPIO_Pin_3   /* CH32 físico 13 */

#define FPGBC_DONE_ASSIGNED        1
#define FPGBC_DONE_PORT        GPIOA
#define FPGBC_DONE_PIN         GPIO_Pin_4   /* CH32 físico 14 */

#define FPGBC_RECONFIG_ASSIGNED    1
#define FPGBC_RECONFIG_PORT    GPIOA
#define FPGBC_RECONFIG_PIN     GPIO_Pin_5   /* CH32 físico 15 */

#define FPGBC_SCLK_ASSIGNED        1
#define FPGBC_SCLK_PORT        GPIOA
#define FPGBC_SCLK_PIN         GPIO_Pin_6   /* CH32 físico 16 */

#define FPGBC_SI_ASSIGNED          0
/* #define FPGBC_SI_PORT       GPIOx */
/* #define FPGBC_SI_PIN        GPIO_Pin_x */

#define FPGBC_SO_ASSIGNED          1
#define FPGBC_SO_PORT          GPIOB
#define FPGBC_SO_PIN           GPIO_Pin_5   /* CH32 físico 41 */

#define FPGBC_SSPI_CS_ASSIGNED     0
/* #define FPGBC_SSPI_CS_PORT  GPIOx */
/* #define FPGBC_SSPI_CS_PIN   GPIO_Pin_x */

#define FPGBC_CLKHOLD_ASSIGNED     0
/* #define FPGBC_CLKHOLD_PORT  GPIOx */
/* #define FPGBC_CLKHOLD_PIN   GPIO_Pin_x */

#define FPGBC_REQUIRED_PINS_ASSIGNED \
    (FPGBC_READY_ASSIGNED && FPGBC_RECONFIG_ASSIGNED && \
     FPGBC_SCLK_ASSIGNED && FPGBC_SI_ASSIGNED && \
     FPGBC_SO_ASSIGNED && FPGBC_SSPI_CS_ASSIGNED)

#endif
