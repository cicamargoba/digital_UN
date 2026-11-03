from migen import *
from litex.soc.interconnect.csr import *
import os
src_dir = os.path.dirname(os.path.abspath(__file__))

class Mult32(Module, AutoCSR):
    def __init__(self, platform):

        self._A    = CSRStorage(16, description="Operando A (16 bits)")
        self._B    = CSRStorage(16, description="Operando B (16 bits)")
        self._init = CSRStorage( 1, description="Pulso de inicio")

        self._pp   = CSRStatus(32, description="Producto (32 bits)")
        self._done = CSRStatus( 1, description="1 cuando terminó")

        self.specials += Instance("mult_32",
            i_clk  = ClockSignal("sys"),
            i_rst  = ResetSignal("sys"),
            i_init = self._init.storage,
            i_A    = self._A.storage,
            i_B    = self._B.storage,
            o_pp   = self._pp.status,
            o_done = self._done.status,
        )

        for src in ["rsr.v", "lsr_mult.v", "comp.v", "acc.v", "control_mult.v", "mult_32.v"]:
            platform.add_source(os.path.join(src_dir, src))


'''
mem_write 0xf0000000 200
mem_write 0xf0000004 400
mem_write 0xf0000008 1
mem_write 0xf0000008 0
mem_read  0xf000000C 




mem_write 0x82000000 200
mem_write 0x82000004 400
mem_write 0x82000008 1
mem_write 0x82000008 0
mem_read  0x8200000C 

'''