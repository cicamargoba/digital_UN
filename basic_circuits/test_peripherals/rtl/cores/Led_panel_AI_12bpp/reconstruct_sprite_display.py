#!/usr/bin/env python3
"""Compare integrated RGB444 composition and reconstruct external HUB75 outputs."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from reconstruct_text_display import capture

ROOT = Path(__file__).resolve().parent


def load(name):
    return [int(word, 16) for word in (ROOT / name).read_text().split()]


def reference():
    font = load("font8x8.mem")
    palette = load("pal16.mem")
    top = load("text_demo_top.mem")
    images = [load("image0.hex"), load("image1.hex")]
    patterns = load("sprite_demo_patterns.mem")
    spr_palette = load("sprite_demo_palette.mem")
    descriptors = load("sprite_demo.mem")
    result = []
    overwritten_text = 0
    opaque = 0
    for y in range(64):
        for x in range(64):
            value = images[y//32][(y%32)*64+x]
            text_on = False
            glyph_on = False
            if y < 32:
                cell = top[(y//8)*8+x//8]
                glyph_on = bool(font[(cell&127)*8+y%8] & (1 << (x%8)))
                fg, bg = (cell>>7)&15, (cell>>11)&15
                text_on = glyph_on or bg != 0
                if text_on:
                    value = palette[fg if glyph_on else bg]
            hits = []
            for word in descriptors:
                sx, sy = word&255, (word>>8)&255
                sx = sx-256 if sx>=128 else sx
                sy = sy-256 if sy>=128 else sy
                dx, dy = x-sx, y-sy
                if word>>25 and 0 <= dx < 8 and 0 <= dy < 8:
                    hits.append((word, dx, dy))
            if len(hits)>1:
                raise ValueError("Demo must not contain overlapping sprite boxes")
            if hits:
                word, dx, dy = hits[0]
                if patterns[((word>>16)&31)*8+dy] & (1 << dx):
                    value = spr_palette[(word>>21)&15]
                    opaque += 1
                    overwritten_text += bool(glyph_on)
            result.append(value)
    assert opaque > 0
    return result, opaque, overwritten_text


def check_composition(path, expected):
    wanted = {
        "text_display_TB.clk1": "clk",
        "text_display_TB.pix_addr": "addr",
        "text_display_TB.mixed": "mixed",
        "text_display_TB.SCANNER.sprite_ready": "ready",
        "text_display_TB.SCANNER.sprite_col": "col",
    }
    codes, vals, pending, scope = {}, {}, {}, []
    errors = []
    checked = 0
    seen = set()
    collisions = 0

    def flush():
        nonlocal checked, collisions
        old = vals.copy()
        vals.update(pending)
        if set(codes) != set(wanted.values()):
            return
        if old.get(codes["clk"]) == "1" and vals.get(codes["clk"]) == "0" and vals.get(codes["ready"]) == "1":
            pair = {}
            for key in ("addr", "mixed", "col"):
                source = old if key == "addr" else vals
                bits = source.get(codes[key], "x")
                if any(c in bits.lower() for c in "xz"):
                    raise ValueError(f"Unknown integrated signal {key}")
                pair[key] = int(bits,2)
            addr = pair["addr"]
            want = (expected[addr]<<12) | expected[addr+2048]
            checked += 1
            seen.add(addr)
            collisions |= pair["col"]
            if pair["mixed"] != want:
                errors.append(dict(address=addr,actual=pair["mixed"],expected=want))

    for line in path.open():
        parts = line.split()
        if not parts:
            continue
        if parts[0]=="$scope":
            scope.append(parts[2])
        elif parts[0]=="$upscope":
            scope.pop()
        elif parts[0]=="$var":
            name = ".".join(scope+[parts[4]])
            if name in wanted:
                codes[wanted[name]]=parts[3]
        elif line[0]=="#":
            flush()
            pending={}
        elif line[0] in "01xz":
            pending[line[1:].strip()]=line[0]
        elif line[0]=="b":
            pending[parts[1]]=parts[0][1:]
    flush()
    if len(seen) != 2048:
        raise ValueError(f"Only {len(seen)} distinct composed pixel pairs checked")
    return checked, errors, collisions


def image(pixels):
    result=Image.new("RGB",(64,64))
    result.putdata([tuple(((v>>s)&15)*17 for s in (8,4,0)) for v in pixels])
    return result.resize((512,512),Image.Resampling.NEAREST)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcd",type=Path,default=ROOT/"build/text/text_display_TB.vcd")
    parser.add_argument("--output",type=Path,default=ROOT/"build/sprites/display")
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    expected,opaque,overlap=reference()
    checks,composition_errors,collisions=check_composition(args.vcd,expected)
    events,exposures,clocks,coincident=capture(args.vcd)
    if len(events)<128:
        raise ValueError("Incomplete external HUB75 frame")
    frame=[0]*4096
    for index,event in enumerate(events[:128]):
        row,plane=divmod(index,4)
        assert event["row"]==row and event["clocks"]==64 and len(event["bits"])==64
        for x,bits in enumerate(event["bits"]):
            for c in range(3):
                frame[row*64+x] |= bits[c] << (8-c*4+plane)
                frame[(row+32)*64+x] |= bits[c+3] << (8-c*4+plane)
    differences=sum(a!=e for a,e in zip(frame,expected))
    shifted=[expected[y*64+max(0,x-1)] for y in range(64) for x in range(64)]
    shifted_errors=sum(a!=e for a,e in zip(frame,shifted))
    actual_img=image(frame)
    expected_img=image(expected)
    actual_img.save(args.output/"simulated.png")
    expected_img.save(args.output/"expected.png")
    canvas=Image.new("RGB",(1100,690),"white")
    draw=ImageDraw.Draw(canvas)
    try:
        font=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",17)
    except OSError:
        font=ImageFont.load_default()
    draw.text((24,12),"Top integrado: HOLA / MUNDO y sprites sobre la imagen",fill="black",font=font)
    draw.text((24,46),"Salida real RGB / LP_CLK / LATCH / ROW",fill="black",font=font)
    draw.text((564,46),"Composicion esperada antes del barrido",fill="black",font=font)
    canvas.paste(actual_img,(24,78))
    canvas.paste(expected_img,(564,78))
    draw.text((24,605),f"Mezcla RGB444: {len(composition_errors)} errores en {checks} pares comprobados.",fill="black",font=font)
    draw.text((24,634),f"Salida HUB75: {differences}/4096 diferencias; modelo de desplazamiento +1 columna: {shifted_errors}.",fill="black",font=font)
    canvas.save(args.output/"comparison.png")
    report=dict(composition_checks=checks,composition_errors=len(composition_errors),
                composed_pair_coverage=2048,sprite_opaque_pixels=opaque,sprite_over_glyph_pixels=overlap,
                collision=collisions,external_differences=differences,
                external_right_shift_model_errors=shifted_errors,external_samples=8192,
                coincident_rgb_changes=coincident,exact_panel_match=differences==0,
                composition_passed=not composition_errors and collisions==0,
                first_composition_errors=composition_errors[:10])
    (args.output/"comparison.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))
    print("Image:",args.output/"comparison.png")
    return 0 if report["composition_passed"] and differences==0 else 1


if __name__=="__main__":
    raise SystemExit(main())
