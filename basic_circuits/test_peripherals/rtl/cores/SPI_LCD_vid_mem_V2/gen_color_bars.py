from pathlib import Path
import argparse
import struct
import zlib

LCD_GEOMETRY = {
    'ST7789': (240, 320, 2),
    'ILI9341': (240, 320, 2),
    'GC9A01': (240, 240, 2),
    'ILI9488': (320, 480, 3),
}
COLORS = [(255,255,0), (0,0,255), (255,0,0), (0,255,0), (255,0,255), (255,0,0), (0,0,255), (0,0,0)]


def make_frame(lcd):
    width, height, bytes_per_pixel = LCD_GEOMETRY[lcd]
    frame = bytearray()
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            r, g, b = COLORS[x * len(COLORS) // width]
            rows.extend((r, g, b))
            if bytes_per_pixel == 3:
                frame.extend((b & 0xFC, g & 0xFC, r & 0xFC))
            else:
                value = ((b >> 3) << 11) | ((g >> 2) << 5) | (r >> 3)
                frame.extend((value >> 8, value & 255))
    row = frame[:width * bytes_per_pixel]
    assert len(frame) == width * height * bytes_per_pixel
    assert all(frame[start:start + len(row)] == row
               for start in range(0, len(frame), len(row)))
    return width, height, bytes_per_pixel, frame, row, rows


def make_complex_frame():
    width, height = 240, 160
    frame = bytearray()
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            r = 30 + 140 * x // (width - 1)
            g = 40 + 140 * y // (height - 1)
            b = 60 + 70 * (x + y) // (width + height - 2)
            if x % 30 == 0 or y % 20 == 0:
                r, g, b = 205, 210, 215
            if 12 <= x < 100 and 12 <= y < 84:
                level = 225 if ((x - 12) // 11 + (y - 12) // 9) % 2 else 65
                r, g, b = level, level, level
            radius2 = (x - 170)**2 + (y - 48)**2
            if radius2 <= 30**2:
                r, g, b = 200, 125 + x // 4, 45
            if 26**2 < radius2 <= 30**2:
                r, g, b = 75, 45, 30
            if 104 <= y < 144:
                r, g, b = COLORS[x * len(COLORS) // width]
                if y in (104, 143) or x % 30 == 0:
                    r, g, b = 235, 235, 235
            if x in (0, width - 1) or y in (0, height - 1):
                r, g, b = 235, 235, 235
            rows.extend((r, g, b))
            value = ((b >> 3) << 11) | ((g >> 2) << 5) | (r >> 3)
            frame.extend((value >> 8, value & 255))
    assert len(frame) == width * height * 2
    assert (240 * 320 * 2) % len(frame) == 0
    assert len({bytes(frame[y * width * 2:(y + 1) * width * 2])
                for y in range(height)}) > 1
    return width, height, frame, rows


def chunk(kind, data):
    return (struct.pack('>I', len(data)) + kind + data
            + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))


def write_hex(path, image):
    path.write_text(''.join(f'{byte:02X}\n' for byte in image))
    assert bytes(int(s, 16) for s in path.read_text().split()) == image


IMAGE_SIZE = (240, 160)
IMAGE_BYTES = 76800


def fit_external_image(path):
    from PIL import Image, ImageOps
    with Image.open(path) as source:
        oriented = ImageOps.exif_transpose(source).convert('RGBA')
    fitted = ImageOps.contain(oriented, IMAGE_SIZE, Image.Resampling.LANCZOS)
    canvas = Image.new('RGB', IMAGE_SIZE, 'white')
    offset = ((IMAGE_SIZE[0] - fitted.width) // 2,
              (IMAGE_SIZE[1] - fitted.height) // 2)
    canvas.paste(fitted, offset, fitted.getchannel('A'))
    original = Image.new('RGB', oriented.size, 'white')
    original.paste(oriented, (0, 0), oriented.getchannel('A'))
    return original, canvas


def encode_bgr565(image):
    if image.size != IMAGE_SIZE:
        raise ValueError('La imagen debe medir 240x160 píxeles')
    data = bytearray()
    for r, g, b in image.convert('RGB').getdata():
        pixel = ((b >> 3) << 11) | ((g >> 2) << 5) | (r >> 3)
        data.extend((pixel >> 8, pixel & 255))
    if len(data) != IMAGE_BYTES:
        raise ValueError('La inicialización debe contener 76800 bytes')
    return bytes(data)


def decoded_preview(data):
    from PIL import Image
    if len(data) != IMAGE_BYTES:
        raise ValueError('Longitud BGR565 incorrecta')
    rgb = bytearray()
    for index in range(0, len(data), 2):
        pixel = (data[index] << 8) | data[index + 1]
        r = pixel & 31
        g = (pixel >> 5) & 63
        b = (pixel >> 11) & 31
        rgb.extend(((r << 3) | (r >> 2),
                    (g << 2) | (g >> 4),
                    (b << 3) | (b >> 2)))
    return Image.frombytes('RGB', IMAGE_SIZE, bytes(rgb))


def screen_preview(tile):
    from PIL import Image
    if tile.size != IMAGE_SIZE:
        raise ValueError('El bloque debe medir 240x160 píxeles')
    screen = Image.new('RGB', (240, 320), 'white')
    screen.paste(tile, (0, 0))
    screen.paste(tile, (0, 160))
    return screen


def export_external_image(image, directory):
    import tempfile
    directory = Path(directory)
    if not directory.is_dir():
        raise ValueError(f'No existe el directorio: {directory}')
    data = encode_bgr565(image)
    preview = decoded_preview(data)
    destinations = (directory / 'complex_image.hex', directory / 'complex_image.png')
    temporary = []
    try:
        for destination in destinations:
            with tempfile.NamedTemporaryFile(dir=directory, suffix='.tmp', delete=False) as handle:
                temporary.append(Path(handle.name))
        write_hex(temporary[0], data)
        preview.save(temporary[1], format='PNG')
        temporary[1].replace(destinations[1])
        temporary[0].replace(destinations[0])
    finally:
        for path in temporary:
            if path.exists():
                path.unlink()
    return destinations


class VideoImageApp:
    def __init__(self, directory):
        import tkinter as tk
        from tkinter import ttk
        self.directory = Path(directory)
        self.image = None
        self.original = None
        self.source = None
        self.photos = []
        self.root = tk.Tk()
        self.root.title('Inicialización de vídeo — ST7789 / Primer 25K')
        self.root.geometry('790x620')
        self.root.minsize(740, 600)
        self.root.configure(background='white')
        style = ttk.Style(self.root)
        style.theme_use('clam')
        style.configure('TFrame', background='white')
        style.configure('TLabel', background='white', foreground='#23303f')
        style.configure('Title.TLabel', font=('TkDefaultFont', 14, 'bold'))
        panel = ttk.Frame(self.root, padding=16)
        panel.pack(fill='both', expand=True)
        ttk.Label(panel, text='Imagen para memoria de vídeo', style='Title.TLabel').pack(anchor='w')
        ttk.Label(panel, text='ST7789: 240×320  |  Memoria: 240×160  |  BGR565: 76 800 bytes').pack(anchor='w', pady=(6, 2))
        ttk.Label(panel, text='Ajuste proporcional, sin recorte, sobre blanco. La pantalla repite el bloque dos veces.').pack(anchor='w')
        controls = ttk.Frame(panel)
        controls.pack(fill='x', pady=12)
        ttk.Button(controls, text='Abrir imagen…', command=self.open_image).pack(side='left')
        self.save_button = ttk.Button(controls, text='Generar HEX', command=self.save_image, state='disabled')
        self.save_button.pack(side='left', padx=10)
        previews = ttk.Frame(panel)
        previews.pack(fill='both', expand=True)
        previews.columnconfigure(0, weight=1)
        previews.columnconfigure(1, weight=1)
        ttk.Label(previews, text='Original').grid(row=0, column=0, pady=(0, 6))
        ttk.Label(previews, text='Vista de pantalla: dos copias de 240×160').grid(row=0, column=1, pady=(0, 6))
        self.original_canvas = tk.Canvas(previews, width=340, height=330, background='white', highlightthickness=1, highlightbackground='#c5cbd1')
        self.original_canvas.grid(row=1, column=0, padx=(0, 10))
        self.screen_canvas = tk.Canvas(previews, width=250, height=330, background='white', highlightthickness=1, highlightbackground='#c5cbd1')
        self.screen_canvas.grid(row=1, column=1)
        self.description = tk.StringVar(value='Selecciona una imagen PNG, JPEG, BMP o WebP.')
        ttk.Label(panel, textvariable=self.description, wraplength=730).pack(anchor='w', pady=(10, 4))
        ttk.Label(panel, text=f'Destino: {self.directory / "complex_image.hex"}', wraplength=730).pack(anchor='w')
        ttk.Label(panel, text='Generar el archivo no compila ni programa la FPGA.').pack(anchor='w', pady=(4, 0))
        self.root.protocol('WM_DELETE_WINDOW', self.root.destroy)
        initial = self.directory / 'tux_source.png'
        if initial.is_file():
            self.load_path(initial)

    def load_path(self, path):
        from PIL import Image, ImageTk
        from tkinter import messagebox
        try:
            original, fitted = fit_external_image(path)
            tile = decoded_preview(encode_bgr565(fitted))
            original_thumbnail = original.copy()
            original_thumbnail.thumbnail((330, 320), Image.Resampling.LANCZOS)
            display = screen_preview(tile)
            self.photos = [ImageTk.PhotoImage(original_thumbnail, master=self.root),
                           ImageTk.PhotoImage(display, master=self.root)]
            self.original_canvas.delete('all')
            self.original_canvas.create_image(170, 165, image=self.photos[0])
            self.screen_canvas.delete('all')
            self.screen_canvas.create_image(125, 165, image=self.photos[1])
            self.original = original
            self.image = fitted
            self.source = Path(path)
            self.save_button.configure(state='normal')
            self.description.set(f'{self.source.name}: {original.width}×{original.height} → 240×160, con proporciones conservadas.')
            return True
        except Exception as error:
            messagebox.showerror('No se pudo abrir la imagen', str(error), parent=self.root)
            return False

    def open_image(self):
        from tkinter import filedialog
        filename = filedialog.askopenfilename(
            parent=self.root, title='Seleccionar imagen',
            initialdir=self.directory,
            filetypes=[('Imágenes', '*.png *.jpg *.jpeg *.bmp *.webp'), ('Todos los archivos', '*')])
        if filename:
            self.load_path(filename)

    def save_image(self):
        from tkinter import messagebox
        if self.image is None:
            return False
        existing = [self.directory / name for name in ('complex_image.hex', 'complex_image.png')
                    if (self.directory / name).exists()]
        if existing and not messagebox.askyesno(
                'Reemplazar imagen anterior',
                'Se reemplazarán complex_image.hex y complex_image.png.\n¿Continuar?', parent=self.root):
            return False
        try:
            destinations = export_external_image(self.image, self.directory)
            self.description.set(f'Generados 76 800 bytes desde {self.source.name}. Listo para el objetivo configure_tang_primer_25k_image.')
            messagebox.showinfo('Inicialización generada',
                                '\n'.join(str(path) for path in destinations), parent=self.root)
            return True
        except Exception as error:
            messagebox.showerror('No se pudo generar el archivo', str(error), parent=self.root)
            return False

    def run(self):
        self.root.mainloop()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lcd', choices=LCD_GEOMETRY, default='ST7789')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--row-only', action='store_true')
    mode.add_argument('--complex', action='store_true')
    mode.add_argument('--input', dest='input_image', type=Path,
                      help='Imagen externa para el buffer ST7789 de 240x160')
    mode.add_argument('--gui', action='store_true', help='Abrir la aplicación gráfica')
    parser.add_argument('--output-dir', type=Path,
                        default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    root = args.output_dir
    if not root.is_dir():
        parser.error(f'Output directory does not exist: {root}')
    if args.input_image or args.gui:
        if args.lcd != 'ST7789':
            parser.error('La aplicación está configurada para ST7789 en Primer 25K')
        if args.gui:
            VideoImageApp(root).run()
        else:
            try:
                _, fitted = fit_external_image(args.input_image)
                destinations = export_external_image(fitted, root)
            except Exception as error:
                parser.error(str(error))
            print(f'Created {destinations[0].name}: {IMAGE_BYTES} bytes, BGR565/MSB first; '
                  f'{destinations[1].name}: 240x160, fitted without distortion')
        return
    if args.complex:
        if args.lcd != 'ST7789':
            parser.error('The complex image is configured for ST7789 240x320')
        width, height, frame, rows = make_complex_frame()
        png = (b'\x89PNG\r\n\x1a\n'
               + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
               + chunk(b'IDAT', zlib.compress(rows))
               + chunk(b'IEND', b''))
        (root / 'complex_image.png').write_bytes(png)
        write_hex(root / 'complex_image.hex', frame)
        print(f'Created complex_image.png: {width}x{height}; '
              f'complex_image.hex: {len(frame)} bytes, BGR565, MSB first')
        return
    width, height, bpp, frame, row, rows = make_frame(args.lcd)
    pixel_format = 'BGR666' if bpp == 3 else 'BGR565'
    write_hex(root / 'video_mem_row.hex', row)
    print(f'Created video_mem_row.hex: {len(row)} bytes, {args.lcd}, {pixel_format}')
    if args.row_only:
        return
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(rows))
           + chunk(b'IEND', b''))
    (root / 'color_bars.png').write_bytes(png)
    write_hex(root / 'video_mem_init.hex', frame)
    print(f'Created color_bars.png: {width}x{height}; '
          f'video_mem_init.hex: {len(frame)} bytes, {pixel_format}')


if __name__ == '__main__':
    main()
