#!/usr/bin/env python3
"""Extract the HTML sprite scene, simulate RTL, compare its VCD with the source."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SOURCES = [
    "sprite_table.v", "sprite_detector.v", "sprite_select.v", "sprite_half.v",
    "sprite_rom.v", "sprite_collision.v", "sprite_engine.v", "text_palette.v",
]


def source_scene(path):
    raw = path.read_bytes()
    html = raw.decode("utf-8")
    match = re.search(r"var\s+SPR\s*=\s*\{(.*?)\};", html, re.S)
    if not match:
        raise ValueError("No SPR object in HTML")
    patterns = {}
    for name, values in re.findall(r"(\w+)\s*:\s*\[([^\]]*)\]", match[1]):
        tokens = values.split(",")
        if not all(re.fullmatch(r"\s*(?:0x[\da-fA-F]+|\d+)\s*", t) for t in tokens):
            raise ValueError(f"Invalid numeric pattern {name}")
        rows = [int(t.strip(), 16 if t.strip().lower().startswith("0x") else 10) for t in tokens]
        if len(rows) != 8 or any(not 0 <= n <= 255 for n in rows):
            raise ValueError(f"Invalid 8x8 pattern {name}")
        patterns[name] = rows
    palette_match = re.search(r"var\s+PAL\s*=\s*(\[[^;]+\]);", html)
    if not palette_match:
        raise ValueError("No PAL array in HTML")
    palette = json.loads(palette_match[1].replace("'", '"'))
    if len(palette) != 16 or not all(re.fullmatch(r"#[\da-fA-F]{3}", c) for c in palette):
        raise ValueError("Expected 16 RGB444 colors")
    section = re.search(r"GAMES\.push\(\{name:'Space Invaders'.*?(?=GAMES\.push|var LAYER)", html, re.S)
    if not section:
        raise ValueError("No Space Invaders scene in HTML")
    sprites = [dict(x=int(x), y=int(y), pattern=p, color=int(c)) for x, y, p, c in
               re.findall(r"s\.sp\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*SPR\.(\w+)\s*,\s*(\d+)\s*\)", section[0])]
    if len(sprites) != 5 or any(s["pattern"] not in patterns or not 0 <= s["color"] < 16 for s in sprites):
        raise ValueError("Expected the five Space Invaders sprites")
    return dict(source_file=path.name, source_sha256=hashlib.sha256(raw).hexdigest(),
                palette=palette, patterns={s["pattern"]: patterns[s["pattern"]] for s in sprites},
                sprites=sprites, source_bit_order="MSB left", rtl_bit_order="LSB left")


def prepare(scene, out):
    names = list(scene["patterns"])
    memory = [0] * 256
    for index, name in enumerate(names):
        for row, value in enumerate(scene["patterns"][name]):
            memory[index * 8 + row] = int(f"{value:08b}"[::-1], 2)
    descriptors = [0] * 8
    for slot, sprite in enumerate(scene["sprites"]):
        descriptors[slot] = ((1 << 25) | (sprite["color"] << 21) |
                             (names.index(sprite["pattern"]) << 16) |
                             ((sprite["y"] & 255) << 8) | (sprite["x"] & 255))
    (out / "space_invaders_patterns.mem").write_text("".join(f"{v:02X}\n" for v in memory))
    (out / "space_invaders_palette.mem").write_text("".join(f"{int(c[1:], 16):03X}\n" for c in scene["palette"]))
    (out / "space_invaders_descriptors.mem").write_text("".join(f"{v:07X}\n" for v in descriptors))
    (out / "source_scene.json").write_text(json.dumps(scene, indent=2) + "\n")


def expected_scene(scene):
    pixels = [None] * 4096
    boxes = [0] * 4096
    for sprite in scene["sprites"]:
        pattern = scene["patterns"][sprite["pattern"]]
        color = int(scene["palette"][sprite["color"]][1:], 16)
        for dy in range(8):
            for dx in range(8):
                x, y = sprite["x"] + dx, sprite["y"] + dy
                if 0 <= x < 64 and 0 <= y < 64:
                    index = y * 64 + x
                    boxes[index] += 1
                    if boxes[index] > 1:
                        raise ValueError("Reference scene has overlapping boxes: AND-OR is not priority selection")
                    if pattern[dy] & (1 << (7 - dx)):
                        pixels[index] = color
    return pixels


def capture_vcd(path):
    wanted = {"sample_valid", "sample_addr", "spr", "spr_on0", "spr_on1", "col"}
    codes, values, scope = {}, {}, []
    pixels = [None] * 4096
    addresses = set()
    previous_valid = False
    collision = 0

    def consume():
        nonlocal previous_valid, collision
        if not codes or codes.get("sample_valid") not in values:
            return
        valid = values[codes["sample_valid"]] == "1"
        if valid and not previous_valid:
            if set(codes) != wanted:
                raise ValueError("Incomplete VCD output declarations")
            sample = {}
            for name, code in codes.items():
                bits = values.get(code, "x")
                if any(c in bits.lower() for c in "xz"):
                    raise ValueError(f"Unknown captured output {name}")
                sample[name] = int(bits, 2)
            addr = sample["sample_addr"]
            if addr in addresses or not 0 <= addr < 2048:
                raise ValueError(f"Duplicate or invalid sample address {addr}")
            addresses.add(addr)
            collision |= sample["col"]
            pixels[addr] = (sample["spr"] >> 12) if sample["spr_on0"] else None
            pixels[addr + 2048] = (sample["spr"] & 4095) if sample["spr_on1"] else None
        previous_valid = valid

    for line in path.open():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "$scope":
            scope.append(parts[2])
        elif parts[0] == "$upscope":
            scope.pop()
        elif parts[0] == "$var" and scope == ["sprite_scene_TB"] and parts[4] in wanted:
            codes[parts[4]] = parts[3]
        elif line[0] == "#":
            consume()
        elif line[0] in "01xz":
            values[line[1:].strip()] = line[0]
        elif line[0] == "b":
            values[parts[1]] = parts[0][1:]
    consume()
    if len(addresses) != 2048:
        raise ValueError(f"Only {len(addresses)} of 2048 pixel pairs captured")
    return pixels, collision


def rgb(value):
    return tuple(((value >> shift) & 15) * 17 for shift in (8, 4, 0))


def render(pixels):
    image = Image.new("RGB", (64, 64))
    image.putdata([rgb(v) if v is not None else ((230, 230, 230) if ((i % 64)//4 + (i//64)//4) % 2 else (250, 250, 250))
                   for i, v in enumerate(pixels)])
    return image


def pictures(actual, expected, scene, out):
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    try:
        font = ImageFont.truetype(font_path, 17)
        small = ImageFont.truetype(font_path, 14)
    except OSError:
        font = small = ImageFont.load_default()
    simulated = render(actual)
    reference = render(expected)
    simulated.resize((512, 512), Image.Resampling.NEAREST).save(out / "simulated.png")
    reference.resize((512, 512), Image.Resampling.NEAREST).save(out / "expected.png")
    diff = Image.new("RGB", (64, 64), "white")
    diff.putdata([(180, 0, 0) if a != e else (255, 255, 255) for a, e in zip(actual, expected)])
    diff.resize((512, 512), Image.Resampling.NEAREST).save(out / "difference.png")
    canvas = Image.new("RGB", (1100, 790), "white")
    draw = ImageDraw.Draw(canvas)
    mismatches = sum(a != e for a, e in zip(actual, expected))
    draw.text((24, 14), "Space Invaders: capa de sprites, 64 x 64", fill="black", font=font)
    draw.text((24, 46), "Salida RTL reconstruida del VCD", fill="black", font=font)
    draw.text((564, 46), "Referencia independiente del HTML", fill="black", font=font)
    canvas.paste(simulated.resize((512, 512), Image.Resampling.NEAREST), (24, 76))
    canvas.paste(reference.resize((512, 512), Image.Resampling.NEAREST), (564, 76))
    draw.rectangle((23, 75, 536, 588), outline="black")
    draw.rectangle((563, 75, 1076, 588), outline="black")
    draw.text((24, 602), f"Diferencias: {mismatches} / 4096 pixeles (color visible y mascara)", fill="black", font=font)
    draw.text((24, 630), "Cuadriculado = transparente. Sin capa de texto, imagen, barrido HUB75 ni logica del juego.", fill="black", font=small)
    draw.text((24, 655), "Patrones originales MSB a la izquierda; bytes invertidos solo al preparar la ROM LSB-first.", fill="black", font=small)
    x = 24
    for sprite in scene["sprites"]:
        tile = [None] * 64
        for y, row in enumerate(scene["patterns"][sprite["pattern"]]):
            for dx in range(8):
                if row & (1 << (7-dx)):
                    tile[y*8+dx] = int(scene["palette"][sprite["color"]][1:], 16)
        icon = Image.new("RGB", (8, 8))
        icon.putdata([rgb(v) if v is not None else (235, 235, 235) for v in tile])
        canvas.paste(icon.resize((64, 64), Image.Resampling.NEAREST), (x, 695))
        draw.text((x+72, 701), sprite["pattern"], fill="black", font=small)
        draw.text((x+72, 728), f"({sprite['x']},{sprite['y']})", fill="black", font=small)
        x += 215
    canvas.save(out / "comparison.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("html", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "build/sprites/space_invaders")
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    scene = source_scene(args.html)
    prepare(scene, out)
    expected = expected_scene(scene)
    compile_cmd = ["iverilog", "-g2012", "-s", "sprite_scene_TB", "-o", str(out / "scene_TB"),
                   str(ROOT / "sprite_scene_TB.v")] + [str(ROOT / name) for name in SOURCES]
    subprocess.run(compile_cmd, cwd=out, check=True)
    run = subprocess.run(["vvp", str(out / "scene_TB")], cwd=out, check=True, capture_output=True, text=True)
    (out / "simulation.log").write_text(run.stdout + run.stderr)
    print(run.stdout, end="")
    if "WARNING" in run.stdout or "ERROR" in run.stdout or run.stderr:
        raise RuntimeError("Inspect simulator diagnostics in simulation.log")
    actual, collision = capture_vcd(out / "space_invaders.vcd")
    pictures(actual, expected, scene, out)
    mismatch = [dict(x=i%64, y=i//64, actual=a, expected=e) for i, (a,e) in enumerate(zip(actual,expected)) if a != e]
    report = dict(source_file=scene["source_file"], source_sha256=scene["source_sha256"],
                  samples=2048, pixels=4096, opaque_actual=sum(v is not None for v in actual),
                  opaque_expected=sum(v is not None for v in expected), collision=collision,
                  differences=len(mismatch), mismatches=mismatch,
                  passed=not mismatch and collision == 0)
    (out / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print("Image:", out / "comparison.png")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
