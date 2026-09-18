#include "usb_lib.h"
#include "usb_prop.h"
#include "usb_pwr.h"
#include "usb_istr.h"
#include "usb_desc.h"
#include "usb_mem.h"
#include "vcom_serial.h"

__IO uint16_t wIstr;
__IO uint8_t bIntPackSOF = 0;
__IO uint32_t esof_counter = 0;
__IO uint32_t wCNTR = 0;

void (*pEpInt_IN[7])(void) = {
    EP1_IN_Callback,
    EP2_IN_Callback,
    EP3_IN_Callback,
    NOP_Process,
    NOP_Process,
    NOP_Process,
    NOP_Process,
};

void (*pEpInt_OUT[7])(void) = {
    EP1_OUT_Callback,
    NOP_Process,
    EP3_OUT_Callback,
    NOP_Process,
    NOP_Process,
    NOP_Process,
    NOP_Process,
};

void USB_Istr(void)
{
    uint32_t i;
    __IO uint32_t ep[8];

    wIstr = _GetISTR();

    if (wIstr & ISTR_CTR & wInterrupt_Mask) {
        CTR_LP();
    }

    if (wIstr & ISTR_RESET & wInterrupt_Mask) {
        _SetISTR((uint16_t)CLR_RESET);
        Device_Property.Reset();
    }

    if (wIstr & ISTR_DOVR & wInterrupt_Mask) {
        _SetISTR((uint16_t)CLR_DOVR);
    }

    if (wIstr & ISTR_ERR & wInterrupt_Mask) {
        _SetISTR((uint16_t)CLR_ERR);
    }

    if (wIstr & ISTR_WKUP & wInterrupt_Mask) {
        _SetISTR((uint16_t)CLR_WKUP);
        Resume(RESUME_EXTERNAL);
    }

    if (wIstr & ISTR_SUSP & wInterrupt_Mask) {
        if (fSuspendEnabled) {
            Suspend();
        } else {
            Resume(RESUME_LATER);
        }
        _SetISTR((uint16_t)CLR_SUSP);
    }

    if (wIstr & ISTR_ESOF & wInterrupt_Mask) {
        _SetISTR((uint16_t)CLR_ESOF);
        if ((_GetFNR() & FNR_RXDP) != 0u) {
            ++esof_counter;
            if ((esof_counter > 3u) && ((_GetCNTR() & CNTR_FSUSP) == 0u)) {
                wCNTR = _GetCNTR();
                for (i = 0; i < 8u; ++i) {
                    ep[i] = _GetENDPOINT(i);
                }
                _SetCNTR(wCNTR | CNTR_FRES);
                _SetCNTR(wCNTR & ~CNTR_FRES);
                while ((_GetISTR() & ISTR_RESET) == 0u) {
                }
                _SetISTR((uint16_t)CLR_RESET);
                for (i = 0; i < 8u; ++i) {
                    _SetENDPOINT(i, ep[i]);
                }
                esof_counter = 0;
            }
        } else {
            esof_counter = 0;
        }
        Resume(RESUME_ESOF);
    }
}

void EP1_IN_Callback(void)
{
}

void EP1_OUT_Callback(void)
{
    uint8_t discard[64];
    (void)USB_SIL_Read(EP1_OUT, discard);
    SetEPRxStatus(ENDP1, EP_RX_VALID);
}

void EP2_IN_Callback(void)
{
}

void EP3_IN_Callback(void)
{
}

void EP3_OUT_Callback(void)
{
    Vcom.out_bytes = USB_SIL_Read(EP3_OUT, (uint8_t *)Vcom.out_buff);
    Vcom.out_bytes = 0;
    SetEPRxStatus(ENDP3, EP_RX_VALID);
}
