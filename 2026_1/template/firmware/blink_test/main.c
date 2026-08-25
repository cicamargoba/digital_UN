#include <stdint.h>
#include "../../cores/blink/firmware/blink.h"

int main(void)
{
    blink_start(12500000u);

    while (1) {
    }

    return 0;
}
