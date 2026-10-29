#!/usr/bin/env python3

from migen import *
from litex.gen import *
from litex.build.io import DDROutput
from litex.soc.cores.clock.gowin_gw2a import GW2APLL
from litex.soc.integration.soc import *
from litex.soc.integration.soc import SoCRegion
from litex.soc.integration.builder import *
from litex.soc.cores.gpio import GPIOIn

from board import fpgbc_plat
from mult import mult_32

# CRG ----------------------------------------------------------------------------------------------

class _CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq, with_hdmi=False):
        self.rst      = Signal()
        self.cd_sys   = ClockDomain()
        self.cd_por   = ClockDomain()
        # Clk
        clk40 = platform.request("clk40")


        rst_n = platform.request("reset_n")

        # PLL
        self.pll = pll = GW2APLL(devicename=platform.devicename, device=platform.device)
        self.comb += pll.reset.eq(~rst_n)
        pll.register_clkin(clk40, 40e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, toolchain="apicula", sys_clk_freq=40e6,
        with_led_chaser      = False,
        with_rgb_led         = False,
        with_buttons         = True,
        with_spi_flash       = False,
        **kwargs):
        platform = fpgbc_plat.Platform(toolchain="apicula")

       # CRG --------------------------------------------------------------------------------------
        self.crg = _CRG(platform, sys_clk_freq)

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform, sys_clk_freq,
            ident                     = "LiteX SoC on FPGBC",
            integrated_main_ram_size  = 0x8000,
            **kwargs)


        #MULTIPLIER
        self.csr.add("mult0")
        self.submodules.mult0 = mult_32.Mult32(platform)


        # SPI Flash: XT25F64B ----------------------------------------------------------------------
        if with_spi_flash:
            from litespi.modules import W25Q16 as SpiFlashModule # compatible with XT25F64B
            from litespi.opcodes import SpiNorFlashOpCodes as Codes
            self.add_spi_flash(mode="1x", module=SpiFlashModule(Codes.READ_1_1_1))

        # Buttons ----------------------------------------------------------------------------------

# Build --------------------------------------------------------------------------------------------

def main():
    from litex.build.parser import LiteXArgumentParser
    parser = LiteXArgumentParser(platform=fpgbc_plat.Platform, description="LiteX SoC on FPGBC.")
    parser.add_target_argument("--flash",          action="store_true",      help="Flash bitstream.")
    parser.add_target_argument("--sys-clk-freq",   default=48e6, type=float, help="System clock frequency.")
    parser.add_target_argument("--with-spi-flash", action="store_true",      help="Enable memory-mapped SPI flash.")
    parser.set_defaults(
        cpu_type = "femtorv",
        cpu_variant = "quark",
    )
    args = parser.parse_args()

    soc = BaseSoC(
        toolchain            = args.toolchain,
        sys_clk_freq         = args.sys_clk_freq,
        with_spi_flash       = args.with_spi_flash,
        **parser.soc_argdict
    )

    builder = Builder(soc, **parser.builder_argdict)
    if args.build:
        builder.build(**parser.toolchain_argdict)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

    if args.flash:
        prog = soc.platform.create_programmer()
        prog.flash(0, builder.get_bitstream_filename(mode="flash", ext=".fs"), external=True)

if __name__ == "__main__":
    main()

'''
        SoCCore.__init__(self, platform,
            cpu_type                 = "femtorv",
            cpu_variant              = "intermissum",
            clk_freq                 = 40e6,
            ident                    = "LiteX CPU Test SoC", ident_version=True,
            integrated_rom_size      = 0x9000#,
            #integrated_rom_init      = "./NO_bios_firmware_stream/firmware.bin"
'''