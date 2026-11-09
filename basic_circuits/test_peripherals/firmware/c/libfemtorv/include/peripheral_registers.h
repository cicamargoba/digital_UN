#ifndef PERIPHERAL_REGISTERS_H
#define PERIPHERAL_REGISTERS_H

#include <stdint.h>

/*
 * Mapa MMIO de test_peripherals/rtl/SOC.v.
 * Las direcciones y los offsets estan expresados en BYTES.
 * Cada acceso C es de 32 bits, aunque el registro utilice menos bits.
 * volatile obliga al compilador a realizar los accesos al hardware;
 * no genera esperas, pulsos, sincronizacion ni reconocimiento automatico.
 *
 * UART y panel estan instanciados en el SoC de prueba actual.
 * Tener una direccion reservada NO significa que el periferico exista:
 * multiplicador y conversiones BCD estan deshabilitados en SOC.v;
 * sqrt, divisor y dpRAM tampoco tienen una instancia activa en ese SoC.
 * No consultar DONE de un periferico ausente: el resultado no esta definido.
 */
#define MMIO_REG32(base, offset) \
    (*(volatile uint32_t *)((uintptr_t)(base) + (uintptr_t)(offset)))

/* BRAM de programa/datos: 1024 palabras de 32 bits, rango 0x0000..0x0fff.
 * La pila parte de 0x1000 y crece hacia direcciones menores. */
#define PROGRAM_RAM_BASE 0x00000000u
#define PROGRAM_RAM_BYTES 4096u
#define PROGRAM_STACK_TOP (PROGRAM_RAM_BASE + PROGRAM_RAM_BYTES)

/* UART: datos, control de transmision/recepcion y LED del SoC. */
#define UART_BASE 0x00400000u
#define UART_DATA_OFFSET 0x08u /* W: byte TX [7:0]; R: ultimo byte RX [7:0]. */
#define UART_CTRL_OFFSET 0x10u /* W: control; R: estado, con campos distintos. */
#define UART_DATA_REG MMIO_REG32(UART_BASE, UART_DATA_OFFSET)
#define UART_CTRL_REG MMIO_REG32(UART_BASE, UART_CTRL_OFFSET)
#define UART_TX_WR (1u << 0)    /* Escritura: iniciar TX; activar y desactivar. */
#define UART_RX_ACK (1u << 1)   /* Escritura: reconocer el dato recibido. */
#define UART_LED (1u << 2)      /* Escritura: nivel del registro ledout. */
#define UART_RX_ERROR (1u << 7) /* Lectura: error de recepcion. */
#define UART_RX_AVAIL (1u << 8) /* Lectura: hay un byte recibido disponible. */
#define UART_TX_BUSY (1u << 9)  /* Lectura: transmisor ocupado. */

/* Raiz cuadrada sin signo. Estos nombres son OFFSETS, no registros C.
 * hwmath.c usa sqrt[OFFSET/4], pues cada elemento del puntero ocupa 4 bytes. */
#define SQRT_BASE 0x00410000u
#define SQRT_A 0x04u      /* W: operando de 16 bits. */
#define SQRT_INIT 0x0cu   /* W: bit 0 inicia; escribir 1 y despues 0. */
#define SQRT_RESULT 0x10u /* R: resultado del wrapper de sqrt, 16 bits. */
#define SQRT_DONE 0x14u   /* R: bit 0 indica fin de la operacion. */

/* Multiplicacion sin signo 16 x 16 -> 32 bits. Todos son offsets. */
#define MULT_BASE 0x00420000u
#define MULT_A 0x04u      /* W: primer operando, bits [15:0]. */
#define MULT_B 0x08u      /* W: segundo operando, bits [15:0]. */
#define MULT_INIT 0x0cu   /* W: bit 0 inicia; escribir 1 y despues 0. */
#define MULT_RESULT 0x10u /* R: producto de 32 bits. */
#define MULT_DONE 0x14u   /* R: bit 0 indica fin de la operacion. */

/* Division sin signo. hwmath.c devuelve los 16 bits bajos del resultado.
 * El wrapper peripheral_div.v declara result[16:0]; esta cabecera no
 * atribuye significado al bit adicional ni define division por cero. */
#define DIV_BASE 0x00430000u
#define DIV_A 0x04u      /* W: dividendo de 16 bits. */
#define DIV_B 0x08u      /* W: divisor de 16 bits. */
#define DIV_INIT 0x0cu   /* W: bit 0 inicia; escribir 1 y despues 0. */
#define DIV_RESULT 0x10u /* R: resultado del wrapper; API C toma [15:0]. */
#define DIV_DONE 0x14u   /* R: bit 0 indica fin; no representa un timeout. */

/* Binario -> BCD: cinco digitos empaquetados, cuatro bits por digito. */
#define BIN2BCD_BASE 0x00440000u
#define BIN2BCD_A 0x04u      /* W: entero binario sin signo de 16 bits. */
#define BIN2BCD_INIT 0x0cu   /* W: bit 0 inicia; escribir 1 y despues 0. */
#define BIN2BCD_RESULT 0x10u /* R: cinco digitos BCD en [19:0]. */
#define BIN2BCD_DONE 0x14u   /* R: bit 0 indica fin. */

/* Rango reservado a dpRAM en SOC.v. Sin registros definidos ni instancia
 * activa: no inferir un protocolo de acceso a partir de esta base. */
#define DPRAM_BASE 0x00450000u

/* BCD -> binario. La entrada debe contener digitos BCD validos y su valor
 * debe caber en los 16 bits de resultado del wrapper. */
#define BCD2BIN_BASE 0x00460000u
#define BCD2BIN_A 0x04u      /* W: cinco digitos BCD empaquetados en [19:0]. */
#define BCD2BIN_INIT 0x0cu   /* W: bit 0 inicia; escribir 1 y despues 0. */
#define BCD2BIN_RESULT 0x10u /* R: valor binario sin signo en [15:0]. */
#define BCD2BIN_DONE 0x14u   /* R: bit 0 indica fin. */

/* Panel HUB75: estos macros SI son registros C desreferenciados.
 * PANEL_BASE es la base del periferico completo.
 * PANEL_REG(offset) suma el offset en bytes y permite leer/escribir
 * el registro de 32 bits situado en esa direccion fisica. */
#define PANEL_BASE 0x00470000u
#define PANEL_REG(offset) (*(volatile uint32_t *)(PANEL_BASE + (offset)))
#define TEXT_ADDR PANEL_REG(0x04u)   /* R/W [5:0]: celda de texto, 0..63. */
#define TEXT_DATA PANEL_REG(0x08u)   /* R/W [14:0]: caracter, frente y fondo. */
#define SPRITE_ADDR PANEL_REG(0x0cu) /* R/W [2:0]: slot de descriptor, 0..7. */
#define SPRITE_DATA PANEL_REG(0x10u) /* R/W [25:0]: descriptor completo. */
#define TEXT_WE PANEL_REG(0x14u)     /* R/W bit 0: habilita escritura de texto. */
#define SPRITE_WE PANEL_REG(0x18u)   /* R/W bit 0: habilita escritura de sprites. */

/* R/W devuelve el REGISTRO del wrapper, no la celda de RAM seleccionada.
 * Reset: los seis registros valen cero. WE es persistente, no automatico.
 * Secuencia: WE=0, cargar direccion y dato, WE=1, esperar la captura en
 * negedge clk1, WE=0. No cambiar direccion/dato mientras WE este activo.
 * WE no controla transparencia: esa se evalua al componer cada pixel.
 */
#define PANEL_TEXT_CELLS 64u
#define PANEL_TEXT_COLUMNS 8u
#define PANEL_SPRITE_SLOTS 8u
#define PANEL_SPRITE_SIZE 8u

/* TEXT_ADDR: ocho columnas x ocho filas de celdas de 8x8 pixeles.
 * cell = fila * 8 + columna, con fila y columna en 0..7.
 * Celdas 0..31: mitad superior; 32..63: mitad inferior.
 * TEXT_DATA = {fondo[3:0], frente[3:0], caracter[6:0]}.
 * Los colores son indices de pal16.mem, no valores RGB directos.
 */
#define TEXT_CHARACTER_MASK 0x7fu
#define TEXT_FOREGROUND_SHIFT 7u
#define TEXT_BACKGROUND_SHIFT 11u
#define TEXT_COLOR_MASK 0x0fu
#define TEXT_SPACE 0x20u

/* write_text(cell, 0x20u):
 * - cell: indice de la celda que se modificara, NO direccion de pixel.
 * - 0x20u: dato completo de 15 bits: caracter ASCII espacio (0x20),
 *   frente 0 y fondo 0. 'u' indica una constante entera sin signo.
 * Con el glifo espacio de la fuente actual y fondo 0, la celda es
 * transparente: deja ver la imagen o un sprite, segun la prioridad.
 * No significa rellenar de negro ni escribir un pixel RGB 0x020.
 * Ejemplo: 'H' blanca, fondo transparente: (15u << 7) | 'H'.
 */

/* SPRITE_DATA: [7:0] X, [15:8] Y, [20:16] patron,
 * [24:21] indice de color y [25] habilitacion.
 * X/Y se codifican en 8 bits, admitiendo coordenadas negativas en
 * complemento a dos para recorte. Para un sprite completo en 64x64,
 * usar X/Y en 0..56. Cada patron es 8x8, una fila por byte de ROM;
 * el bit 0 de cada byte representa el pixel izquierdo.
 */
#define SPRITE_COORD_MASK 0xffu
#define SPRITE_Y_SHIFT 8u
#define SPRITE_PATTERN_MASK 0x1fu
#define SPRITE_PATTERN_SHIFT 16u
#define SPRITE_COLOR_MASK 0x0fu
#define SPRITE_COLOR_SHIFT 21u
#define SPRITE_ENABLE (1u << 25)

/* sprite_descriptor(28u, 24u, 4u, 10u):
 * - 28u: X, columna del pixel superior izquierdo.
 * - 24u: Y, fila del pixel superior izquierdo.
 * - 4u: indice del patron, 0..31; en sprite_demo_patterns.mem actual,
 *   el patron 4 es el invasor. Sus filas estan en los bytes 32..39.
 * - 10u: indice de color, 0..15, en sprite_demo_palette.mem; el valor
 *   actual es RGB444 logico 0x5F5. NO es numero de sprite ni patron.
 * La funcion activa siempre el bit 25 y devuelve 0x0344181C.
 * No escribe hardware: write_sprite(1u, descriptor) escribe ese dato
 * en el slot 1. Slot y patron son indices independientes.
 * Un descriptor cero deshabilita el slot; la imagen de fondo permanece.
 */

#endif
