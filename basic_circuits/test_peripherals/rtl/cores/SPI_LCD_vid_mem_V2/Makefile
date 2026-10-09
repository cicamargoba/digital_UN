TARGET = spi_lcd_vid_mem
LCD ?= ST7789
TOP = spi_lcd_vid_mem
BUILD_DIR ?= build
CLK_HZ ?= 12000000
ROW_MODE ?= 1
GOWIN_SH ?= $(or $(shell command -v gw_sh 2>/dev/null),$(firstword $(wildcard /Work/CAD/IDE/bin/gw_sh)),gw_sh)
YOSYS ?= yosys
OPEN_GOWIN_BIN ?= /Work/CAD/gowin-open/bin
NEXTPNR_GOWIN ?= $(OPEN_GOWIN_BIN)/nextpnr-himbaechel
GOWIN_PACK ?= $(OPEN_GOWIN_BIN)/gowin_pack
PRIMER_FTDI_SERIAL ?= 2025030317
PRIMER_BUILD_DIR ?= $(BUILD_DIR)

ifeq ($(filter $(LCD),ST7789 ILI9341 GC9A01 ILI9488),)
$(error LCD no valido: $(LCD))
endif
LCD_WIDTH = 240
LCD_HEIGHT = 320
BYTES_PER_PIXEL = 2
ifeq ($(LCD),GC9A01)
LCD_HEIGHT = 240
else ifeq ($(LCD),ILI9488)
LCD_WIDTH = 320
LCD_HEIGHT = 480
BYTES_PER_PIXEL = 3
endif

ifeq ($(ROW_MODE),1)
GEOMETRY_VID_BYTES = $(shell python3 -c 'print($(LCD_WIDTH) * $(BYTES_PER_PIXEL))')
GEOMETRY_INIT_FILE = video_mem_row.hex
else
GEOMETRY_VID_BYTES = $(shell python3 -c 'print($(LCD_WIDTH) * $(LCD_HEIGHT) * $(BYTES_PER_PIXEL))')
GEOMETRY_INIT_FILE = video_mem_init.hex
endif
GEOMETRY_VID_AW = $(shell python3 -c 'print(max(1, ($(GEOMETRY_VID_BYTES) - 1).bit_length()))')
VID_INIT_FILE ?= $(GEOMETRY_INIT_FILE)
VID_BYTES ?= $(GEOMETRY_VID_BYTES)
VID_AW ?= $(GEOMETRY_VID_AW)
RTL_DEFINES = -DLCD_$(LCD) -DLCD_CLK_HZ=$(CLK_HZ) -DLCD_ROW_MODE=$(ROW_MODE)
HW_OBJS = a_count.v comp_addr.v ctrl.v d_count.v init_mem.v memwr_cmd.v \
          mux_3to1.v spi_tx.v ctrl_spi.v lsr.v byte_cnt.v f_div.v v_count.v video_mem.v spi_lcd_vid_mem.v
HW_DEPS = $(HW_OBJS) init_defs.vh $(wildcard init_mem_*.vh)
HW_PARAMS = chparam -set VID_AW $(VID_AW) -set VID_BYTES $(VID_BYTES) -set VID_INIT_FILE "$(VID_INIT_FILE)" $(TOP)

ifeq ($(TARGET),spi_lcd_vid_mem)
OBJS = $(HW_OBJS)
else ifeq ($(TARGET),spi_tx)
OBJS = spi_tx.v ctrl_spi.v lsr.v byte_cnt.v f_div.v
else ifeq ($(TARGET),ctrl_spi)
OBJS = ctrl_spi.v
else ifeq ($(TARGET),ctrl)
OBJS = ctrl.v
else ifeq ($(TARGET),video_mem)
OBJS = video_mem.v
else ifeq ($(TARGET),v_count)
OBJS = v_count.v
else
OBJS = $(TARGET).v
endif


check_spi_tx: | $(BUILD_DIR)
	iverilog -g2012 -Wall -s spi_tx_TB -o $(BUILD_DIR)/spi_tx_check spi_tx_TB.v spi_tx.v ctrl_spi.v lsr.v byte_cnt.v f_div.v
	vvp $(BUILD_DIR)/spi_tx_check

check_video_mem_tb: | $(BUILD_DIR)
	iverilog -g2012 -Wall -s video_mem_TB -o $(BUILD_DIR)/video_mem_check video_mem_TB.v video_mem.v
	vvp $(BUILD_DIR)/video_mem_check

check_v_count: | $(BUILD_DIR)
	iverilog -g2012 -Wall -s v_count_TB -o $(BUILD_DIR)/v_count_check v_count_TB.v v_count.v
	vvp $(BUILD_DIR)/v_count_check

CHECK_BYTES ?= 16
CHECK_INIT_FILE ?= video_mem_init_TB.hex
check_lcd: | $(BUILD_DIR)
	iverilog -g2012 -Wall $(RTL_DEFINES) -s spi_lcd_vid_mem_check_TB -Pspi_lcd_vid_mem_check_TB.TEST_BYTES=$(CHECK_BYTES) -Pspi_lcd_vid_mem_check_TB.TEST_INIT_FILE='"$(CHECK_INIT_FILE)"' -o $(BUILD_DIR)/lcd_check spi_lcd_vid_mem_check_TB.v $(HW_OBJS)
	vvp $(BUILD_DIR)/lcd_check

check_synth: CLK_HZ = 12000000
check_synth: MAX_MEM_BYTES = 15360
check_synth: check_memory_size check_video_mem | $(BUILD_DIR)
	yosys -Q -T -q -l $(BUILD_DIR)/v2_synth.rpt -p 'read_verilog -defer $(RTL_DEFINES) $(HW_OBJS); $(HW_PARAMS); synth_ice40 -top $(TOP); check -assert; write_json $(BUILD_DIR)/v2_synth.json'

check_synth_ecp5: CLK_HZ = 25000000
check_synth_ecp5: MAX_MEM_BYTES = 129024
check_synth_ecp5: check_memory_size check_video_mem | $(BUILD_DIR)
	yosys -Q -T -q -l $(BUILD_DIR)/v2_ecp5_synth.rpt -p 'read_verilog -defer $(RTL_DEFINES) $(HW_OBJS); $(HW_PARAMS); synth_ecp5 -top $(TOP); check -assert; write_json $(BUILD_DIR)/v2_ecp5_synth.json'

sim:
	rm -f a.out *.vcd
	iverilog $(RTL_DEFINES) -DBENCH $(TARGET)_TB.v $(OBJS)
	vvp a.out | tee sim.log
	gtkwave $(TARGET)_TB.vcd 2>/dev/null || true

svg: $(OBJS)
	rm -rf *svg *out *dot *json
	yosys -p "prep -top $(TARGET); memory -nomap; opt; opt_expr; techmap; abc -g AND,OR,XOR; write_json $(TARGET).json" $(OBJS)
	python3 -c "import json; d=json.load(open('$(TARGET).json')); [ (m.pop('parameter_default_values',None), [n.pop('signed',None) for n in m.get('netnames',{}).values()]) for m in d['modules'].values() ]; json.dump(d, open('$(TARGET).json','w'))"
	netlist2svg $(TARGET).json -o $(TARGET).svg
	google-chrome $(TARGET).svg

svg-flat: $(OBJS)
	rm -rf *svg *out *dot *json
	yosys -p "prep -top $(TARGET); proc; memory -nomap; opt; opt_expr; techmap; abc -g AND,OR,XOR; show -format dot -prefix $(TARGET)_out" $(OBJS)
	dot -Tsvg $(TARGET)_out.dot > $(TARGET)_flat.svg
	google-chrome $(TARGET)_flat.svg

clean:
	rm -rf *svg *out *dot a.out *.vcd *json *_synth.v *log *bit *rpt *svf *out.config

check_video_mem:
	@if [ "$(VID_INIT_FILE)" = video_mem_row.hex ]; then \
	    python3 gen_color_bars.py --lcd $(LCD) --row-only; \
	elif [ "$(VID_INIT_FILE)" = video_mem_init.hex ]; then \
	    python3 gen_color_bars.py --lcd $(LCD); \
	fi
	@test -f "$(VID_INIT_FILE)" || { printf 'Falta el archivo de imagen: %s\n' "$(VID_INIT_FILE)" >&2; exit 1; }
	@python3 -c 'from pathlib import Path; p=Path("$(VID_INIT_FILE)"); v=p.read_text().split(); assert len(v)==$(VID_BYTES), f"{p}: {len(v)} bytes, se requieren $(VID_BYTES)"; assert all(0 <= int(x,16) <= 255 for x in v), "Entrada fuera de rango"'

check_memory_size:
	@test "$(ROW_MODE)" = 0 -o "$(ROW_MODE)" = 1
	@test "$(CLK_HZ)" -gt 0
	@python3 -c 'assert 0 < $(VID_BYTES) <= $(MAX_MEM_BYTES), "La memoria solicitada excede la BRAM disponible"; assert $(VID_AW) > 0 and $(VID_BYTES) <= (1 << $(VID_AW)), "VID_AW insuficiente"'

check_gowin_params:
	@test "$(VID_AW)" = "$(GEOMETRY_VID_AW)" -a "$(VID_BYTES)" = "$(GEOMETRY_VID_BYTES)" -a "$(VID_INIT_FILE)" = "$(GEOMETRY_INIT_FILE)" || { printf 'Gowin deriva la memoria de LCD y ROW_MODE; no admite sobrescrituras VID_* independientes.\n' >&2; exit 1; }

$(BUILD_DIR):
	mkdir -p "$@"

build_icebreaker: CLK_HZ = 12000000
build_icebreaker: MAX_MEM_BYTES = 15360
build_icebreaker: HW_PARAMS += ; chparam -set RESET_ACTIVE_LOW 1 -set RECOVERY_TICKS 2880000 $(TOP)
build_icebreaker: check_memory_size check_video_mem $(HW_DEPS) spi_lcd_icebreaker.pcf icebreaker_pre_pack.py | $(BUILD_DIR)
	yosys -l $(BUILD_DIR)/icebreaker.rpt -p 'read_verilog -defer $(RTL_DEFINES) $(HW_OBJS); $(HW_PARAMS); synth_ice40 -dsp -top $(TOP); write_json $(BUILD_DIR)/icebreaker.json'
	nextpnr-ice40 --json $(BUILD_DIR)/icebreaker.json --pcf spi_lcd_icebreaker.pcf --asc $(BUILD_DIR)/icebreaker.asc --pre-pack icebreaker_pre_pack.py --up5k --package sg48 --seed 1
	icepack -s $(BUILD_DIR)/icebreaker.asc $(BUILD_DIR)/icebreaker.bin
	iceprog -d i:0x0403:0x6010 $(BUILD_DIR)/icebreaker.bin

configure_icebreaker: build_icebreaker

build_lattice: CLK_HZ = 25000000
build_lattice: MAX_MEM_BYTES = 129024
build_lattice: check_memory_size check_video_mem $(HW_DEPS) spi_lcd_vid_mem.lpf | $(BUILD_DIR)
	yosys -l $(BUILD_DIR)/lattice.rpt -p 'read_verilog -defer $(RTL_DEFINES) $(HW_OBJS); $(HW_PARAMS); synth_ecp5 -top $(TOP); write_json $(BUILD_DIR)/lattice.json'
	nextpnr-ecp5 --json $(BUILD_DIR)/lattice.json --lpf spi_lcd_vid_mem.lpf --textcfg $(BUILD_DIR)/lattice.config --25k --package CABGA256 --speed 6 --seed 1
	ecppack --bootaddr 0 --compress $(BUILD_DIR)/lattice.config --svf $(BUILD_DIR)/lattice.svf --bit $(BUILD_DIR)/lattice.bit

configure_lattice: build_lattice
	sudo openFPGALoader -c ft232RL --pins=TXD:CTS:DTR:RXD -m $(BUILD_DIR)/lattice.bit

image_app:
	python3 gen_color_bars.py --lcd ST7789 --gui

complex_image:
	python3 gen_color_bars.py --lcd ST7789 --complex

build_tang_primer_25k_image: LCD = ST7789
build_tang_primer_25k_image: ROW_MODE = 0
build_tang_primer_25k_image: VID_BYTES = 76800
build_tang_primer_25k_image: VID_AW = 17
build_tang_primer_25k_image: VID_INIT_FILE = complex_image.hex
build_tang_primer_25k_image: PRIMER_BUILD_DIR = $(BUILD_DIR)/primer25k_image
build_tang_primer_25k build_tang_primer_25k_image: CLK_HZ = 50000000
build_tang_primer_25k build_tang_primer_25k_image: MAX_MEM_BYTES = 129024
build_tang_primer_25k build_tang_primer_25k_image: check_memory_size check_video_mem $(HW_DEPS) sipeed_tang_primer_25k.cst sipeed_tang_primer_25k.sdc | $(BUILD_DIR)
	mkdir -p "$(PRIMER_BUILD_DIR)"
	"$(YOSYS)" -Q -T -q -l $(PRIMER_BUILD_DIR)/tang_primer_25k_synth.log -p 'read_verilog -defer $(RTL_DEFINES) $(HW_OBJS); $(HW_PARAMS); synth_gowin -family gw5a -strict-gw5a-dffs -nolutram -top $(TOP) -json $(PRIMER_BUILD_DIR)/tang_primer_25k_synth.json; check -assert'
	"$(NEXTPNR_GOWIN)" --device GW5A-LV25MG121NC1/I0 --top $(TOP) --json $(PRIMER_BUILD_DIR)/tang_primer_25k_synth.json --write $(PRIMER_BUILD_DIR)/tang_primer_25k_pnr.json --sdc sipeed_tang_primer_25k.sdc --freq $(shell python3 -c 'print($(CLK_HZ) / 1000000)') --vopt cst=sipeed_tang_primer_25k.cst --vopt i2c_as_gpio --vopt sspi_as_gpio --seed 1 --report $(PRIMER_BUILD_DIR)/tang_primer_25k_report.json --log $(PRIMER_BUILD_DIR)/tang_primer_25k_pnr.log
	"$(GOWIN_PACK)" -d GW5A-25A --cpu_as_gpio --i2c_as_gpio --sspi_as_gpio --mspi_as_gpio --ready_as_gpio --done_as_gpio -o $(PRIMER_BUILD_DIR)/tang_primer_25k.fs $(PRIMER_BUILD_DIR)/tang_primer_25k_pnr.json

configure_tang_primer_25k_image: PRIMER_BUILD_DIR = $(BUILD_DIR)/primer25k_image
configure_tang_primer_25k_image: build_tang_primer_25k_image
	openFPGALoader --board tangprimer25k --ftdi-serial "$(PRIMER_FTDI_SERIAL)" --bitstream $(PRIMER_BUILD_DIR)/tang_primer_25k.fs

configure_tang_primer_25k: build_tang_primer_25k
	openFPGALoader --board tangprimer25k --ftdi-serial "$(PRIMER_FTDI_SERIAL)" --bitstream $(PRIMER_BUILD_DIR)/tang_primer_25k.fs

build_tang_nano_20k: CLK_HZ = 27000000
build_tang_nano_20k: MAX_MEM_BYTES = 105984
build_tang_nano_20k: check_memory_size check_gowin_params check_video_mem $(HW_DEPS) gowin_build.tcl sipeed_tang_nano_20k.cst sipeed_tang_nano_20k.sdc | $(BUILD_DIR)
	LCD=$(LCD) CLK_HZ=$(CLK_HZ) ROW_MODE=$(ROW_MODE) GOWIN_BOARD=nano_20k "$(GOWIN_SH)" gowin_build.tcl
	cp impl/pnr/project.fs $(BUILD_DIR)/tang_nano_20k.fs

configure_tang_nano_20k: build_tang_nano_20k
	openFPGALoader --cable ft2232 --bitstream $(BUILD_DIR)/tang_nano_20k.fs

.PHONY: sim svg svg-flat clean check_video_mem check_memory_size check_gowin_params \
        check_spi_tx check_video_mem_tb check_v_count check_lcd check_synth check_synth_ecp5 \
        image_app complex_image build_tang_primer_25k_image configure_tang_primer_25k_image \
        build_icebreaker build_lattice build_tang_primer_25k build_tang_nano_20k \
        configure_icebreaker configure_lattice configure_tang_primer_25k configure_tang_nano_20k


#export PATH=$PATH:/Work/CAD/IDE/bin/
#export QT_QPA_PLATFORM_PLUGIN_PATH=/Work/CAD/IDE/Programmer/bin/PyQt5/qt-plugins
#export QT_QPA_PLATFORM=xcb
#export QT_XCB_GL_INTEGRATION=none


#https://stackoverflow.com/questions/35927650/is-it-possible-to-create-a-simulation-waveform-from-yosys-output
