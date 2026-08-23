#!/usr/bin/env python3
"""
ws2812_convert.py — Conversor de imagen 8×32 a formato WS2812B

Cableado físico (serpentín por columnas):
  Col par  (0,2,4,...): LED baja de arriba→abajo   (fila 0..7)
  Col impar(1,3,5,...): LED sube de abajo→arriba   (fila 7..0)
  Índice LED = col×8 + segmento_dentro_de_columna

Salidas:
  <nombre>_grb.txt   — 256 valores GRB separados por espacios
  <nombre>.mem        — un valor GRB por línea (para $readmemh en Verilog)
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("ERROR: Pillow no está instalado. Ejecuta: pip install pillow")

# ── constantes ────────────────────────────────────────────────────────────────
COLS = 32
ROWS = 8
N_LEDS = COLS * ROWS          # 256


# ── funciones de mapeo ────────────────────────────────────────────────────────
def pixel_for_led(led_idx: int) -> tuple[int, int]:
    """
    Dado el índice lineal del LED (0..255) devuelve (col, row) en la imagen.
    col par  → row = led_idx % 8  (baja)
    col impar→ row = 7 − (led_idx % 8)  (sube)
    """
    col = led_idx // ROWS
    seg = led_idx % ROWS
    row = seg if col % 2 == 0 else (ROWS - 1 - seg)
    return col, row


def rgb_to_grb(r: int, g: int, b: int) -> tuple[int, int, int]:
    return g, r, b


# ── núcleo de conversión ───────────────────────────────────────────────────────
def convert(image_path: Path, out_stem: str | None = None, verbose: bool = False):
    # Cargar y redimensionar
    img = Image.open(image_path).convert("RGB")
    original_size = img.size
    img = img.resize((COLS, ROWS), Image.LANCZOS)

    if verbose:
        print(f"  Imagen original : {original_size[0]}×{original_size[1]} px")
        print(f"  Redimensionada  : {COLS}×{ROWS} px")

    pixels = img.load()

    # Construir array GRB en orden físico de LEDs
    grb_values: list[str] = []
    for led_idx in range(N_LEDS):
        col, row = pixel_for_led(led_idx)
        r, g, b = pixels[col, row]
        gv, rv, bv = rgb_to_grb(r, g, b)
        grb_values.append(f"{gv:02X}{rv:02X}{bv:02X}")

    # Rutas de salida
    stem = out_stem or image_path.stem
    out_dir = image_path.parent
    grb_path = out_dir / f"{stem}_grb.txt"
    mem_path = out_dir / f"{stem}.mem"

    # Archivo GRB — todos en una línea separados por espacio
    grb_path.write_text(" ".join(grb_values) + "\n", encoding="utf-8")

    # Archivo .mem — un valor por línea (compatible con $readmemh)
    mem_path.write_text("\n".join(grb_values) + "\n", encoding="utf-8")

    return grb_path, mem_path, grb_values


# ── CLI ────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Convierte una imagen a formato WS2812B GRB para matriz 8×32 "
                    "(serpentín por columnas).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  python ws2812_convert.py logo.png
  python ws2812_convert.py logo.png -o frame1
  python ws2812_convert.py anim/*.png --batch
  python ws2812_convert.py logo.png -v --preview
        """,
    )
    parser.add_argument("images", nargs="+", metavar="IMAGEN",
                        help="Archivo(s) de imagen de entrada (PNG, JPG, BMP, GIF…)")
    parser.add_argument("-o", "--output", metavar="NOMBRE",
                        help="Nombre base de salida (sin extensión). "
                             "Solo válido con una imagen.")
    parser.add_argument("-d", "--outdir", metavar="DIR",
                        help="Directorio de salida (por defecto: junto a la imagen)")
    parser.add_argument("--batch", action="store_true",
                        help="Modo lote: procesa múltiples imágenes, nombra por índice "
                             "(frame_000, frame_001, …)")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Mostrar detalles de cada conversión")
    parser.add_argument("--preview", action="store_true",
                        help="Imprimir los primeros 16 valores GRB en consola")
    parser.add_argument("--dump-map", action="store_true",
                        help="Imprimir tabla completa LED→(col,row) y salir")

    args = parser.parse_args()

    # ── dump del mapa de cableado ─────────────────────────────────────────────
    if args.dump_map:
        print(f"{'LED':>4}  {'col':>3}  {'row':>3}  {'dir':>6}")
        print("─" * 22)
        for idx in range(N_LEDS):
            col, row = pixel_for_led(idx)
            direction = "↓ par" if col % 2 == 0 else "↑ impar"
            print(f"{idx:>4}  {col:>3}  {row:>3}  {direction}")
        return

    if args.output and len(args.images) > 1 and not args.batch:
        parser.error("-o/--output solo puede usarse con una sola imagen "
                     "(o agrega --batch para modo lote)")

    images = args.images
    total = len(images)

    for i, img_str in enumerate(images):
        img_path = Path(img_str)

        if not img_path.exists():
            print(f"[AVISO] No se encontró: {img_path}  — omitiendo")
            continue

        # Determinar nombre base de salida
        if args.batch:
            stem = f"frame_{i:03d}"
        elif args.output:
            stem = args.output
        else:
            stem = img_path.stem

        # Directorio de salida
        out_dir = Path(args.outdir) if args.outdir else img_path.parent
        out_dir.mkdir(parents=True, exist_ok=True)

        if args.verbose or total > 1:
            print(f"\n[{i+1}/{total}] {img_path.name}")

        try:
            grb_path, mem_path, grb_values = convert(
                img_path,
                out_stem=str(out_dir / stem),
                verbose=args.verbose,
            )
        except Exception as exc:
            print(f"  ERROR: {exc}")
            continue

        print(f"  GRB → {grb_path}")
        print(f"  MEM → {mem_path}")

        if args.preview:
            preview = grb_values[:16]
            print(f"  Primeros 16 LEDs (GRB): {' '.join(preview)}")

    if total > 1:
        print(f"\n✓ {total} imagen(es) procesada(s).")


# ── punto de entrada ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    main()
