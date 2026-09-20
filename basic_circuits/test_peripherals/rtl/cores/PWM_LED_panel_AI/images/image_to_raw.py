from PIL import Image
import numpy as np
import sys

# Verificar si se proporcionó el nombre del archivo
if len(sys.argv) < 2:
    print("Uso: python script.py <nombre_imagen.png>")
    sys.exit(1)

nombre_imagen = sys.argv[1]

try:
    im = Image.open(nombre_imagen)
except FileNotFoundError:
    print(f"Error: No se encontró el archivo '{nombre_imagen}'")
    sys.exit(1)

# Convertir a RGB si está en modo paleta
if im.mode == 'P':
    im = im.convert('RGB')

img = np.array(im)

# Verificar dimensiones
if img.shape[0] != 64 or img.shape[1] != 64:
    print(f"Advertencia: La imagen debe ser 64x64. Dimensiones actuales: {img.shape[1]}x{img.shape[0]}")

# Generar nombre de archivo de salida
nombre_salida = "../image.hex"

# Abrir archivo para escritura
with open(nombre_salida, "w") as f:
    for y in range(32):  # Filas 0-31 (mitad superior)
        for x in range(64):  # Todas las columnas
            # Pixel en posición (x, y) - mitad superior
            # INVERTIDO: usar canal azul como rojo y viceversa
            r1 = (img[y, x, 2] >> 4)  # Tomar canal AZUL como rojo
            g1 = (img[y, x, 1] >> 4)  # Verde sin cambios
            b1 = (img[y, x, 0] >> 4)  # Tomar canal ROJO como azul
            
            # Pixel en posición (x, y+32) - mitad inferior
            r2 = (img[y+32, x, 2] >> 4)  # Tomar canal AZUL como rojo
            g2 = (img[y+32, x, 1] >> 4)  # Verde sin cambios
            b2 = (img[y+32, x, 0] >> 4)  # Tomar canal ROJO como azul
            
            # Byte 1: R1[3:0]G1[3:0]
            byte1 = (r1 << 4) | g1
            
            # Byte 2: B1[3:0]R2[3:0]
            byte2 = (b1 << 4) | r2
            
            # Byte 3: G2[3:0]B2[3:0]
            byte3 = (g2 << 4) | b2
            
            # Formato: R1G1B1R2G2B2 como 3 bytes separados
            f.write("%02X%02X%02X\n" % (byte1, byte2, byte3))

print(f"Archivo generado: {nombre_salida}")