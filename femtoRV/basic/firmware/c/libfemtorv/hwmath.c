/*
 * hwmath.c - Funciones C para perifericos hardware (mult, div, sqrt)
 *
 * Operaciones sin signo, enteros de 16 bits.
 * - hw_mult(a,b): 16x16 -> 32 bits
 * - hw_div(a,b):  16/16 -> 16 bits (cociente)
 * - hw_sqrt(a):   raiz cuadrada de 16 bits
 *
 * El CPU femtoRV32 no tiene mul/div hardware; estos perifericos
 * hacen las operaciones en ciclos de reloj y se acceden por MMIO.
 */

#include <femtorv32.h>

#define SQRT_BASE  0x410000
#define MULT_BASE  0x420000
#define DIV_BASE   0x430000


/* Mult register offsets (word-aligned) */
#define MULT_A       0x04
#define MULT_B       0x08
#define MULT_INIT    0x0C
#define MULT_RESULT  0x10
#define MULT_DONE    0x14

/* Div register offsets (word-aligned, 32-bit) */
#define DIV_A        0x04
#define DIV_B        0x08
#define DIV_INIT     0x0C
#define DIV_DONE     0x14
#define DIV_RESULT   0x10

/* Sqrt register offsets (word-aligned) */
#define SQRT_A       0x04
#define SQRT_INIT    0x0C
#define SQRT_RESULT  0x10
#define SQRT_DONE    0x14

/*
 * hw_mult: multiplicacion sin signo 16x16 -> 32 bits
 * Init es latched: escribir 1 luego 0 para crear el pulso.
 */
uint32_t hw_mult(uint16_t a, uint16_t b) {
    volatile uint32_t *mult = (volatile uint32_t *)MULT_BASE;

    mult[MULT_A/4]  = a;
    mult[MULT_B/4]  = b;
    mult[MULT_INIT/4] = 1;  /* assert init */
    mult[MULT_INIT/4] = 0;  /* deassert init */
    while (!(mult[MULT_DONE/4] & 1))
        ;
    return mult[MULT_RESULT/4];
}

/*
 * hw_div: division sin signo 16/16 -> cociente 16 bits
 * Init es latched: escribir 1 luego 0 para crear el pulso.
 */
uint16_t hw_div(uint16_t a, uint16_t b) {
    volatile uint32_t *div = (volatile uint32_t *)DIV_BASE;
    div[DIV_A/4]    = a;
    div[DIV_B/4]    = b;
    div[DIV_INIT/4] = 1;
    div[DIV_INIT/4] = 0;
    while (!(div[DIV_DONE/4] & 1))
        ;
    return (uint16_t)(div[DIV_RESULT/4] & 0xFFFF);
}

/*
 * hw_sqrt: raiz cuadrada entera sin signo de 16 bits
 * Init es latched: escribir 1 luego 0.
 */
uint16_t hw_sqrt(uint16_t a) {
    volatile uint32_t *sqrt = (volatile uint32_t *)SQRT_BASE;
    sqrt[SQRT_A/4] = a;
    sqrt[SQRT_INIT/4] = 1;
    sqrt[SQRT_INIT/4] = 0;
    while (!(sqrt[SQRT_DONE/4] & 1))
        ;
    return (uint16_t)(sqrt[SQRT_RESULT/4] & 0xFFFF);
}
