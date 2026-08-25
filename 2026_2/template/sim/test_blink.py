import sys
from pathlib import Path

from migen.sim import run_simulation

CORE_DIR = Path(__file__).resolve().parents[1] / "soc" / "cores" / "blink"
sys.path.insert(0, str(CORE_DIR))

from blink import BlinkCore


def stimulus(dut):
    yield dut.period.eq(3)
    yield dut.enable.eq(1)

    previous = 0
    transitions = 0

    for _ in range(20):
        yield
        current = yield dut.led
        if current != previous:
            transitions += 1
            previous = current

    assert transitions >= 5, f"Expected at least 5 transitions, observed {transitions}"
    print("PASS: LiteX/Migen blink behavior verified")


if __name__ == "__main__":
    dut = BlinkCore()
    run_simulation(dut, stimulus(dut), vcd_name="blink.vcd")
