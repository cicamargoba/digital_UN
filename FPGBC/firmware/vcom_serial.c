#include "vcom_serial.h"

volatile VCOM Vcom;
VCOM_LINE_CODING LineCfg = {115200u, 0u, 0u, 8u};

void VCOM_Init(void)
{
}

void VCOM_TransferData(void)
{
}

void VCOM_LineCoding(VCOM_LINE_CODING *line_cfg)
{
    if (line_cfg != 0) {
        LineCfg = *line_cfg;
    }
}
