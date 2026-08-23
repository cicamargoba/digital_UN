#include <femtorv32.h>

int main() {
    printf("\n\r=== printf test ===\n\r");

    /* %d */
    printf("%%d  0    : %d\n\r", 0);
    printf("%%d  1    : %d\n\r", 1);
    printf("%%d  42   : %d\n\r", 42);
    printf("%%d  -1   : %d\n\r", -1);
    printf("%%d  -42  : %d\n\r", -42);
    printf("%%d  max  : %d\n\r", 2147483647);
    printf("%%d  min  : %d\n\r", -2147483648);

    /* %x */
    printf("%%x  0       : %x\n\r", 0);
    printf("%%x  ff      : %x\n\r", 0xFF);
    printf("%%x  dead   : %x\n\r", 0xDEAD);
    printf("%%x  beef   : %x\n\r", 0xBEEF);
    printf("%%x  deadbeef: %x\n\r", 0xDEADBEEF);

    /* %s */
    printf("%%s  empty : %s\n\r", "");
    printf("%%s  hello : %s\n\r", "hello world");

    /* %c */
    printf("%%c  A     : %c\n\r", 'A');
    printf("%%c  0     : %c\n\r", '0');
    printf("%%c  nl    : %c\n\r", '\n');

    /* mixed */
    printf("mix d/x/s/c: %d %x %s %c\n\r", 100, 0xCAFE, "test", 'Z');

    /* print_hex / print_dec directos */
    print_dec(12345);
    printf("\n\r");
    print_hex(0xABCDEF01);
    printf("\n\r");

    /* getchar test */
    printf("\n\rPress a key: ");
    int c = getchar();
    printf("\n\rGot: %c (0x%x)\n\r", c, c);

    while(1) {
        LEDS(4);
        delay(500);
        LEDS(0);
        delay(500);
    }
    return 0;
}
