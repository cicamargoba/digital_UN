#ifndef VCOM_SERIAL_H
#define VCOM_SERIAL_H

#include <stdint.h>

#define RX_BUFF_SIZE 64
#define TX_BUFF_SIZE 64

typedef struct {
    uint8_t rx_buff[RX_BUFF_SIZE];
    uint16_t rx_wrptr;
    uint16_t rx_rdptr;
    uint8_t tx_buff[TX_BUFF_SIZE];
    uint16_t tx_wrptr;
    uint16_t tx_rdptr;
    uint16_t hw_flow;
    uint8_t in_buff[64];
    uint16_t in_bytes;
    uint8_t out_buff[64];
    uint16_t out_bytes;
} VCOM;

typedef struct __attribute__((packed)) {
    uint32_t u32DTERate;
    uint8_t u8CharFormat;
    uint8_t u8ParityType;
    uint8_t u8DataBits;
} VCOM_LINE_CODING;

extern volatile VCOM Vcom;
extern VCOM_LINE_CODING LineCfg;

void VCOM_Init(void);
void VCOM_TransferData(void);
void VCOM_LineCoding(VCOM_LINE_CODING *line_cfg);

#endif
