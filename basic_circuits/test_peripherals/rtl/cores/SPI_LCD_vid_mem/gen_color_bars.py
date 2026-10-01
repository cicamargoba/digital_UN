from pathlib import Path
import struct
import zlib

root = Path(__file__).resolve().parent
width = height = 240
colors = [(255,255,255), (255,255,0), (0,255,255), (0,255,0), (255,0,255), (255,0,0), (0,0,255), (0,0,0)]
frame = bytearray()
rows = bytearray()
for y in range(height):
    rows.append(0)
    for x in range(width):
        r, g, b = colors[x // 30]
        rows.extend((r, g, b))
        value = ((b >> 3) << 11) | ((g >> 2) << 5) | (r >> 3)
        frame.extend((value >> 8, value & 255))

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')
(root / 'color_bars.png').write_bytes(png)
depth = 1 << 18
image = (frame * ((depth + len(frame) - 1) // len(frame)))[:depth]
(root / 'video_mem_init.hex').write_text(''.join(f'{byte:02X}\n' for byte in image))
assert len(frame) == 115200
assert len(image) == depth
assert bytes(int(s, 16) for s in (root / 'video_mem_init.hex').read_text().split()) == image
print(f'Created color_bars.png: {width}x{height}; video_mem_init.hex: {depth} bytes, repeated BGR565 frame, MSB first')
