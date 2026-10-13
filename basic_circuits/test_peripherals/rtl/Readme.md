# Herramientas abiertas para FPGA Gowin en Linux

Este tutorial instala **Yosys + nextpnr-himbaechel + Apycula + openFPGALoader** para construir y cargar diseños Verilog en FPGA Gowin. No requiere Gowin IDE, `gw_sh` ni una licencia del fabricante.

Dirigido a Debian/Ubuntu y derivados con compilador C++17. Las instrucciones crean una instalación independiente bajo `$HOME`, sin reemplazar las herramientas de otros proyectos.

## 1. Función de cada herramienta

| Herramienta | Función | Salida |
|---|---|---|
| Yosys | Síntesis del Verilog | Netlist JSON |
| nextpnr-himbaechel, arquitectura Gowin | Colocación, ruteo y análisis temporal | JSON ruteado |
| Apycula / `gowin_pack` | Generación del bitstream | Archivo `.fs` |
| openFPGALoader | Programación por JTAG | Configuración de la FPGA |

El ejecutable de place-and-route utilizado aquí es **`nextpnr-himbaechel`**, no `nextpnr-ice40` ni `nextpnr-ecp5`.

## 2. Dependencias del sistema

```bash
sudo apt update
sudo apt install -y \
  build-essential clang lld git make cmake ninja-build pkg-config \
  bison flex gawk libfl-dev libffi-dev libreadline-dev tcl-dev zlib1g-dev \
  libboost-all-dev libeigen3-dev python3 python3-dev python3-venv \
  graphviz iverilog gtkwave openfpgaloader
```

`iverilog` y `gtkwave` son para simulación; no intervienen en la generación del bitstream. Si la distribución no ofrece `openfpgaloader`, consultar su [instalación oficial](https://trabucayre.github.io/openFPGALoader/guide/install.html).

## 3. Directorios y entorno Python

Ejecutar los bloques siguientes en la misma sesión de terminal. Si se abre otra sesión, restablecer estas variables.

```bash
export GOWIN_ROOT="$HOME/gowin-open-tools"
export GOWIN_PREFIX="$GOWIN_ROOT/install"
export GOWIN_SRC="$GOWIN_ROOT/src"
mkdir -p "$GOWIN_SRC"
python3 -m venv "$GOWIN_PREFIX"
export PATH="$GOWIN_PREFIX/bin:$PATH"
python -m pip install --upgrade pip setuptools wheel
python -m pip install uv 'apycula==0.34'
```

El entorno evita instalar paquetes Python sobre el Python del sistema. Apycula 0.34 es la versión identificada en la instalación local usada como referencia.

**No instalar Apycula solamente desde un checkout de Git sin comprobar sus bases de datos.** El paquete publicado incluye archivos `*.msgpack.xz`; un checkout de fuentes puede no contenerlos. No es necesario ejecutar los fuzzers ni instalar las herramientas propietarias para utilizar el paquete publicado.

Comprobar las bases de datos antes de compilar nextpnr:

```bash
python - <<'PY'
from pathlib import Path
import apycula
base = Path(apycula.__file__).resolve().parent
for name in ('GW2A-18', 'GW2A-18C', 'GW5A-25A'):
    path = base / (name + '.msgpack.xz')
    print(name, 'OK' if path.is_file() else 'FALTA')
    assert path.is_file(), path
PY
```

## 4. Compilar Yosys

La revisión indicada corresponde al Yosys local identificado como **0.59+62**, con soporte de `gw2a`, `gw5a` y `-strict-gw5a-dffs`. Utilizar directorios nuevos; no sobrescribir un checkout de trabajo existente.

```bash
git clone https://github.com/YosysHQ/yosys.git "$GOWIN_SRC/yosys"
git -C "$GOWIN_SRC/yosys" checkout --detach 9aa2dde7e
git -C "$GOWIN_SRC/yosys" submodule update --init --recursive
make -C "$GOWIN_SRC/yosys" config-clang
make -C "$GOWIN_SRC/yosys" -j2 PREFIX="$GOWIN_PREFIX"
make -C "$GOWIN_SRC/yosys" install PREFIX="$GOWIN_PREFIX"
```

Se limita la compilación a dos trabajos para reducir el consumo de RAM. No se necesita `sudo make install` porque el destino pertenece al usuario.

Comprobar versión y familias disponibles:

```bash
yosys -V
yosys -Q -T -p 'help synth_gowin'
```

La ayuda debe incluir `-family gw2a`, `-family gw5a` y `-strict-gw5a-dffs`. Un Yosys antiguo del gestor de paquetes puede no incluir el soporte requerido para la Primer 25K.

## 5. Compilar nextpnr-himbaechel con Gowin

Se fija la revisión del checkout local de referencia. Se incluyen las bases de datos GW2A-18, GW2A-18C y GW5A-25A: el nombre completo del encapsulado se selecciona posteriormente con `--device`.

```bash
git clone https://github.com/YosysHQ/nextpnr.git "$GOWIN_SRC/nextpnr"
git -C "$GOWIN_SRC/nextpnr" checkout --detach 861c57be9c9a0c38ab60b0eabd19903db37efa22
git -C "$GOWIN_SRC/nextpnr" submodule update --init --recursive

cmake -S "$GOWIN_SRC/nextpnr" -B "$GOWIN_ROOT/build-nextpnr" -G Ninja \
  -DARCH=himbaechel \
  -DHIMBAECHEL_UARCH=gowin \
  -DHIMBAECHEL_GOWIN_DEVICES='GW2A-18;GW2A-18C;GW5A-25A' \
  -DAPYCULA_INSTALL_PREFIX="$GOWIN_PREFIX" \
  -DPython3_EXECUTABLE="$GOWIN_PREFIX/bin/python" \
  -DBUILD_GUI=OFF \
  -DBUILD_PYTHON=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$GOWIN_PREFIX"

cmake --build "$GOWIN_ROOT/build-nextpnr" --parallel 2
cmake --install "$GOWIN_ROOT/build-nextpnr"
```

`APYCULA_INSTALL_PREFIX` hace que la generación de las bases de datos utilice el mismo Python y el mismo Apycula que `gowin_pack`.

`BUILD_PYTHON=OFF` desactiva la integración Python del ejecutable, pero no elimina la necesidad del intérprete Python usado para generar las bases de datos.

Comprobar la instalación:

```bash
nextpnr-himbaechel --version
gowin_pack --help
openFPGALoader --Version
ls "$GOWIN_PREFIX/share/nextpnr/himbaechel/gowin/"
```

Deben aparecer `chipdb-GW2A-18.bin`, `chipdb-GW2A-18C.bin` y `chipdb-GW5A-25A.bin`.

## 6. Familia de síntesis, dispositivo y base de datos

Son tres conceptos distintos:

| FPGA | Familia de Yosys | `--device` de nextpnr | Base de datos / `gowin_pack -d` |
|---|---|---|---|
| GW2AR EQ144 | `gw2a` | `GW2AR-LV18EQ144PC8/I7` | `GW2A-18` o `GW2A-18C`, según revisión del chip |
| Tang Primer 25K | `gw5a` | `GW5A-LV25MG121NC1/I0` | `GW5A-25A` |

**El `C8` de la referencia comercial es un grado de velocidad; no demuestra que la base de datos sea `GW2A-18C`.** La revisión C se identifica mediante el marcado/date code correspondiente. Confirmar la revisión física antes de programar; usar la misma familia en nextpnr y en `gowin_pack`.

El target EQ144 de este proyecto está configurado actualmente con `GW2A-18C`. La instalación de referencia tenía esa base de datos, pero la mera disponibilidad de una base de datos no valida la revisión física de una placa.

## 7. Utilizar las herramientas con este proyecto

Desde la raíz del repositorio `digital_UN`, construir sin programar:

```bash
make -C basic_circuits/test_peripherals/rtl build_gw2ar_eq144 \
  EQ144_OPEN_BIN="$GOWIN_PREFIX/bin" \
  EQ144_YOSYS="$GOWIN_PREFIX/bin/yosys"

make -C basic_circuits/test_peripherals/rtl build_tang_primer_25k \
  PRIMER_OPEN_BIN="$GOWIN_PREFIX/bin" \
  PRIMER_YOSYS="$GOWIN_PREFIX/bin/yosys"
```

Los overrides evitan depender de la ubicación de las herramientas en otra máquina. Las salidas quedan en `build/gw2ar_eq144_open/` y `build/primer25k_open/`, respectivamente.

Antes de programar, comprobar que la construcción terminó sin errores, que existe un `.fs` recién generado y que el análisis temporal pasa para el reloj de la placa. Los warnings de RTL no se corrigen reinstalando herramientas.

### EQ144: pines configurados

| Puerto de SOC | Pin FPGA | Configuración |
|---|---:|---|
| `clk` | 11 | 25 MHz |
| `TXD` | 27 | Salida UART |
| `RXD` | 28 | Entrada UART |
| `resetn` | 38 | Activo bajo, pull-up |
| `interrupt_request` | 39 | Activo alto, pull-down |
| `LEDS` | 45 | Salida LED |

### Programación en SRAM con FT232R/FT232RL

| FT232 | JTAG de la FPGA |
|---|---|
| TXD | TDI |
| CTS | TDO |
| DTR | TCK |
| RXD | TMS |
| GND | GND |

Verificar que los niveles de E/S del adaptador sean compatibles con el banco JTAG; para esta conexión se requieren niveles de 3,3 V. No alimentar una placa ya alimentada desde el adaptador. Este cableado es JTAG, **no** el UART de los pines 27/28.

Solo después de validar el bitstream y el hardware:

```bash
make -C basic_circuits/test_peripherals/rtl configure_gw2ar_eq144 \
  EQ144_OPEN_BIN="$GOWIN_PREFIX/bin" \
  EQ144_YOSYS="$GOWIN_PREFIX/bin/yosys"
```

El target usa `openFPGALoader --cable ft232RL --pins TXD:CTS:DTR:RXD --write-sram`. No escribe la Flash. Si hay varios adaptadores FTDI, seleccionar el programador mediante `EQ144_FTDI_SERIAL`. Aplicar reset a la placa después de cargar el diseño.

## 8. Diagnóstico

| Mensaje | Acción |
|---|---|
| `License verification failed` | Se ejecutó una herramienta propietaria. Este flujo no debe invocar `gw_sh`. |
| `Unable to read chipdb ...` | Comprobar la familia incluida al compilar nextpnr y el directorio de instalación. No cambiar la familia física solamente para evitar el error. |
| `For the GW2A series you need to specify ... family` | Añadir `--vopt family=GW2A-18` o `GW2A-18C`, según el chip. |
| `Unconstrained IO` | Asignar el puerto real en el CST. No ignorar el error ni escoger un pin ocupado. |
| `Invalid constraint: #...` | Eliminar esas líneas o utilizar comentarios compatibles con el parser; no asumir sintaxis de shell en el CST. |
| `Permission denied` al acceder a USB | Revisar reglas udev y permisos del programador siguiendo la documentación de openFPGALoader. No usar permisos globales `777`. |
| El ruteo no termina o se interrumpe | Guardar el log y comprobar la fase donde se detuvo. No afirmar que hay bitstream válido si el empaquetado no terminó. |

## 9. Fuentes y alcance de verificación

- [Yosys: instalación y compilación](https://yosyshq.readthedocs.io/projects/yosys/en/latest/getting_started/installation.html).
- [Yosys, revisión usada como referencia](https://github.com/YosysHQ/yosys/tree/9aa2dde7e).
- [nextpnr, revisión usada como referencia](https://github.com/YosysHQ/nextpnr/tree/861c57be9c9a0c38ab60b0eabd19903db37efa22).
- [Apycula](https://github.com/YosysHQ/apicula), paquete instalado de referencia: 0.34.
- [openFPGALoader: FT232R en bitbang](https://trabucayre.github.io/openFPGALoader/guide/advanced.html).

Revisión del tutorial: 2026-10-13. Versiones y opciones contrastadas con las herramientas y fuentes locales. **No se ejecutó una instalación limpia completa para validar todos los pasos del tutorial.** La compilación/colocación del SoC EQ144 se comprobó durante la preparación; eso no implica validación de programación, revisión física del chip ni funcionamiento del SoC en hardware.
