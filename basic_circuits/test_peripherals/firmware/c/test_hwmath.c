/*
 * test_hwmath.c - Demo de perifericos hardware desde C
 *
 * Prueba: printf, multiplicador, sqrt y divisor
 */
#include <femtorv32.h>

int main() {
    uint32_t r;
    uint16_t q;

    /* --- printf --- */
    printf("=== Demo libfemtorv ===\n");
    printf("printf: %%d=%d %%x=%x %%s=%s %%c=%c\n", 42, 255, "OK", 'A');

    /* --- hw_mult --- */
    printf("\n--- hw_mult ---\n");
    r = hw_mult(12, 34);
    printf("12 * 34 = %d\n", r);

    r = hw_mult(255, 255);
    printf("255 * 255 = %d\n", r);

    r = hw_mult(1000, 50);
    printf("1000 * 50 = %d\n", r);

    /* --- hw_sqrt --- */
    printf("\n--- hw_sqrt ---\n");
    q = hw_sqrt(144);
    printf("sqrt(144) = %d\n", q);

    q = hw_sqrt(256);
    printf("sqrt(256) = %d\n", q);

    q = hw_sqrt(10000);
    printf("sqrt(10000) = %d\n", q);

    /* --- hw_div --- */
    printf("\n--- hw_div ---\n");
    q = hw_div(100, 7);
    printf("100 / 7 = %d\n", q);

    q = hw_div(255, 16);
    printf("255 / 16 = %d\n", q);

    q = hw_div(1000, 10);
    printf("1000 / 10 = %d\n", q);

    printf("\nDone.\n");
    return 0;
}
