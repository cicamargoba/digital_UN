#!/usr/bin/env python3
import argparse
from pathlib import Path
import re

parser = argparse.ArgumentParser(description="Convert public-domain font8x8_basic.h to a 1024-byte ROM")
parser.add_argument("source", type=Path)
parser.add_argument("--output", type=Path, default=Path(__file__).with_name("font8x8.mem"))
args = parser.parse_args()
rows = re.findall(r"^\s*\{([^{}]+)\}\s*,?\s*//\s*U\+([0-9A-Fa-f]{4})", args.source.read_text(), re.M)
assert len(rows) == 128, "Expected 128 glyphs"
data = []
for code, (values, label) in enumerate(rows):
    glyph = [int(v, 16) for v in re.findall(r"0x([0-9A-Fa-f]{2})", values)]
    assert len(glyph) == 8 and int(label, 16) == code, label
    data.extend(glyph)
assert data[0x41 * 8:0x42 * 8] == [0x0C, 0x1E, 0x33, 0x33, 0x3F, 0x33, 0x33, 0x00]
args.output.write_text("".join(f"{byte:02X}\n" for byte in data))
print(f"Generated {args.output.name}: {len(data)} rows, bit 0 is leftmost pixel")
