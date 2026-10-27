#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2023 Icenowy Zheng <uwu@icenowy.me>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.build.generic_platform import *
from litex.build.gowin.platform import GowinPlatform
from litex.build.openfpgaloader import OpenFPGALoader


# IOs ----------------------------------------------------------------------------------------------

_io = [
    # Clk / Rst.
    ("clk40",  0, Pins("11"), IOStandard("LVCMOS33")),

    # Serial.
    ("serial", 0,
        Subsignal("rx", Pins("28")),
        Subsignal("tx", Pins("27")),
        IOStandard("LVCMOS33")
    ),

    # SPIFlash.
    ("spiflash", 0,
        Subsignal("cs_n", Pins("94"), IOStandard("LVCMOS33")),
        Subsignal("clk",  Pins("93"), IOStandard("LVCMOS33")),
        Subsignal("miso", Pins("96"), IOStandard("LVCMOS33")),
        Subsignal("mosi", Pins("95"), IOStandard("LVCMOS33")),
    ),

    # Buttons.
    ("btn", 0,  Pins("120"), IOStandard("LVCMOS33")),

]

# Connectors ---------------------------------------------------------------------------------------

_connectors = [
]

# Platform -----------------------------------------------------------------------------------------

class Platform(GowinPlatform):
    default_clk_name   = "clk40"
    default_clk_period = 1e9/40e6

    def __init__(self, dock="standard", toolchain="apicula"):

        GowinPlatform.__init__(self, "GW2AR-LV18EQ144PC8/I7", _io, _connectors, toolchain=toolchain, devicename="GW2AR-18C")

        self.toolchain.options["use_mspi_as_gpio"]  = 1
        self.toolchain.options["use_sspi_as_gpio"]  = 1
        self.toolchain.options["use_ready_as_gpio"] = 1
        self.toolchain.options["use_done_as_gpio"]  = 1
        self.toolchain.options["rw_check_on_ram"]   = 1

    def create_programmer(self, kit="openfpgaloader"):
        return OpenFPGALoader(cable="ft2232")

    def do_finalize(self, fragment):
        GowinPlatform.do_finalize(self, fragment)
        self.add_period_constraint(self.lookup_request("clk40", loose=True), 1e9/40e6)
