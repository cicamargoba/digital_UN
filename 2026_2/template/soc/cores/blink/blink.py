from migen import If, Module, Signal
from litex.soc.interconnect.csr import AutoCSR, CSRStorage


class BlinkCore(Module):
    """Lógica de parpadeo independiente del bus y de los CSR."""

    def __init__(self):
        self.enable = Signal()
        self.period = Signal(32, reset=1)
        self.led = Signal()

        counter = Signal(32)

        self.sync += If(
            ~self.enable,
            counter.eq(0),
            self.led.eq(0),
        ).Elif(
            (self.period <= 1) | (counter >= (self.period - 1)),
            counter.eq(0),
            self.led.eq(~self.led),
        ).Else(
            counter.eq(counter + 1),
        )


class Blink(Module, AutoCSR):
    """Periférico LiteX con registros de control y período."""

    def __init__(self):
        self.enable = CSRStorage(1, name="enable", description="Enable blinking")
        self.period = CSRStorage(32, reset=1, name="period", description="Clock cycles per LED transition")
        self.led = Signal()

        self.submodules.core = core = BlinkCore()
        self.comb += [
            core.enable.eq(self.enable.storage),
            core.period.eq(self.period.storage),
            self.led.eq(core.led),
        ]
