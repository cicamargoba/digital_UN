#!/usr/bin/env python3
import argparse
from collections import Counter, defaultdict, deque
from pathlib import Path
import struct
import zlib


def png(path, frame, scale=6):
    width = height = 64
    rows = bytearray()
    for row in frame:
        pixels = bytes(component * 17 for pixel in row for component in pixel)
        expanded = b"".join(pixels[x:x + 3] * scale for x in range(0, len(pixels), 3))
        for _ in range(scale):
            rows.extend(b"\x00" + expanded)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width * scale, height * scale, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


def capture(path):
    names = {"LP_CLK", "LATCH", "NOE", "ROW", "RGB0", "RGB1"}
    ids, values, updates, scope = {}, {}, {}, []
    shifted = deque(maxlen=64)
    events, exposures = [], []
    now = 0
    shift_count = 0
    total_shifts = 0
    active = None
    coincident_rgb = 0
    tick_ps = None
    timescale = False

    def flush():
        nonlocal shift_count, total_shifts, active, coincident_rgb
        old = values.copy()
        values.update(updates)
        if not ids:
            return
        if old.get(ids["LP_CLK"]) == "0" and values.get(ids["LP_CLK"]) == "1":
            bits = []
            for key in ("RGB0", "RGB1"):
                before = old.get(ids[key], "x")
                if "x" in before or "z" in before:
                    raise ValueError(f"Unknown {key} sampled at {now}")
                bits.extend(int(bit) for bit in before.zfill(3))
                if values.get(ids[key]) != before:
                    coincident_rgb += 1
            shifted.append(bits)
            shift_count += 1
            total_shifts += 1
        if active is not None and old.get(ids["NOE"]) == "0":
            if values.get(ids["NOE"]) != "0" or old.get(ids["LATCH"]) == "0" and values.get(ids["LATCH"]) == "1":
                exposures.append((active, now))
                active = None
        if old.get(ids["LATCH"]) == "0" and values.get(ids["LATCH"]) == "1":
            row = int(values[ids["ROW"]], 2)
            events.append({"time": now, "row": row, "clocks": shift_count, "bits": list(shifted)})
            shift_count = 0
            if values.get(ids["NOE"]) == "0":
                active = (len(events) - 1, now)

    with path.open() as stream:
        for raw in stream:
            line = raw.strip()
            parts = line.split()
            if not parts:
                continue
            if parts[0] == "$timescale":
                timescale = True
            elif timescale and parts[0] != "$end":
                unit = "".join(parts)
                if unit != "1ps":
                    raise ValueError(f"Expected 1ps VCD timescale, got {unit}")
                tick_ps = 1
            elif parts[0] == "$scope":
                scope.append(parts[2])
            elif parts[0] == "$upscope":
                scope.pop()
            elif parts[0] == "$var" and scope == ["text_display_TB"] and parts[4] in names:
                ids[parts[4]] = parts[3]
            elif parts[0] == "$end":
                timescale = False
            elif line.startswith("#"):
                flush()
                updates = {}
                now = int(line[1:])
            elif line[0] in "01xz":
                updates[line[1:]] = line[0]
            elif line.startswith("b") and len(parts) == 2:
                updates[parts[1]] = parts[0][1:]
    flush()
    assert set(ids) == names and tick_ps == 1
    return events, exposures, total_shifts, coincident_rgb


def main():
    parser = argparse.ArgumentParser(description="Reconstruct HUB75 output from external VCD signals")
    parser.add_argument("--vcd", type=Path, default=Path("build/text/text_display_TB.vcd"))
    parser.add_argument("--output-dir", type=Path, default=Path("Docs"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    events, exposures, clocks, coincident_rgb = capture(args.vcd)
    if len(events) < 128:
        raise ValueError("Capture does not contain 32 rows x 4 planes")
    frame = [[[0, 0, 0] for _ in range(64)] for _ in range(64)]
    for number, event in enumerate(events[:128]):
        row, plane = divmod(number, 4)
        assert event["row"] == row, (number, event["row"])
        assert event["clocks"] == 64 and len(event["bits"]) == 64, event
        for x, bits in enumerate(event["bits"]):
            for color in range(3):
                frame[row][x][color] |= bits[color] << plane
                frame[row + 32][x][color] |= bits[color + 3] << plane

    load = lambda name: [int(word, 16) for word in (root / name).read_text().split()]
    font, palette, top_cells = load("font8x8.mem"), load("pal16.mem"), load("text_demo_top.mem")
    image_top, image_bot = load("image0.hex"), load("image1.hex")
    assert [word & 127 for word in top_cells[:4]] == list(b"HOLA")
    assert [word & 127 for word in top_cells[8:13]] == list(b"MUNDO")
    expected = [[[0, 0, 0] for _ in range(64)] for _ in range(64)]
    for y in range(64):
        for x in range(64):
            if y < 32:
                cell = top_cells[(y // 8) * 8 + x // 8]
                char, fg, bg = cell & 127, (cell >> 7) & 15, (cell >> 11) & 15
                glyph_bit = (font[char * 8 + y % 8] >> (x % 8)) & 1
                value = palette[fg if glyph_bit else bg] if glyph_bit or bg else image_top[y * 64 + x]
            else:
                value = image_bot[(y - 32) * 64 + x]
            expected[y][x] = [(value >> shift) & 15 for shift in (8, 4, 0)]
    errors = [(x, y, frame[y][x], expected[y][x]) for y in range(64) for x in range(64) if frame[y][x] != expected[y][x]]
    args.output_dir.mkdir(parents=True, exist_ok=True)
    png(args.output_dir / "text_display_reconstructed.png", frame)
    png(args.output_dir / "text_display_expected.png", expected)
    print(f"LATCH events: {len(events)}; settled VCD rising LP_CLK edges: {clocks}")
    print(f"First frame: 128 latches, 8192 samples of RGB[5:0], 4096 RGB444 pixels")
    print(f"Pixels different from reference: {len(errors)} / 4096")
    top_errors = sum(y < 32 for x, y, actual, reference in errors)
    print(f"Different pixels: top={top_errors}, bottom={len(errors) - top_errors}")
    shifted_errors = sum(frame[y][x] != expected[y][max(0, x - 1)] for y in range(64) for x in range(64))
    print(f"Differences against one-column right-shift model: {shifted_errors} / 4096")
    print(f"RGB changes at same timestamp as sampling edge: {coincident_rgb}")
    dwell = defaultdict(list)
    for (event_number, start), end in exposures:
        if event_number < 128:
            dwell[event_number % 4].append((end - start) / 1000)
    print("NOE active durations (ns), by bit plane:", {k: dict(Counter(v)) for k, v in dwell.items()})
    print("Top text pixels (#=nonblack):")
    for row in frame[:16]:
        print("".join("#" if any(pixel) else "." for pixel in row[:40]))
    for error in errors[:12]:
        print("Mismatch x,y,actual,expected:", error)
    if errors:
        raise SystemExit(1)
    print("PASS: reconstructed output matches HOLA/MUNDO and lower image")


if __name__ == "__main__":
    main()
