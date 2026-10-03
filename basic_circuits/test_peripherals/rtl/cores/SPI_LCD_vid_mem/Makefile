TARGET = spi_lcd_vid_mem
LCD   ?= ST7789
TOP = spi_lcd_vid_mem
BUILD_DIR ?= build
VID_INIT_FILE ?= video_mem_init.hex
VID_AW ?= 18
VID_BYTES ?= $(shell python3 -c 'print(1 << $(VID_AW))')
HW_OBJS = a_count.v comp_addr.v ctrl.v d_count.v init_mem.v memwr_cmd.v \
          mux_3to1.v spi_tx.v v_count.v video_mem.v spi_lcd_vid_mem.v
HW_DEPS = $(HW_OBJS) init_defs.vh $(wildcard init_mem_*.vh)
HW_PARAMS = chparam -set VID_AW $(VID_AW) -set VID_BYTES $(VID_BYTES) -set VID_INIT_FILE "$(VID_INIT_FILE)" $(TOP)

ifeq ($(TARGET), spi_lcd_vid_mem)
    OBJS = a_count.v comp_addr.v ctrl.v d_count.v init_mem.v memwr_cmd.v \
           mux_3to1.v spi_tx.v v_count.v video_mem.v spi_lcd_vid_mem.v
else ifeq ($(TARGET), ctrl)
    OBJS = ctrl.v
else ifeq ($(TARGET), video_mem)
    OBJS = video_mem.v
else ifeq ($(TARGET), v_count)
    OBJS = v_count.v
else
    OBJS = ${TARGET}.v
endif

sim:
	rm -f a.out *.vcd
	iverilog -DLCD_$(LCD) -DBENCH $(TARGET)_TB.v $(OBJS)
	vvp a.out | tee sim.log
	gtkwave $(TARGET)_TB.vcd 2>/dev/null || true

svg: $(OBJS)
	rm -rf *svg *out *dot *json
	yosys -p "prep -top ${TARGET}; memory -nomap; opt; opt_expr; techmap; abc -g AND,OR,XOR; write_json ${TARGET}.json" ${OBJS}
	python3 -c "import json; d=json.load(open('${TARGET}.json')); [ (m.pop('parameter_default_values',None), [n.pop('signed',None) for n in m.get('netnames',{}).values()]) for m in d['modules'].values() ]; json.dump(d, open('${TARGET}.json','w'))"
	netlist2svg ${TARGET}.json -o ${TARGET}.svg
	google-chrome ${TARGET}.svg

svg-flat: $(OBJS)
	rm -rf *svg *out *dot *json
	yosys -p "prep -top ${TARGET}; proc; memory -nomap; opt; opt_expr; techmap; abc -g AND,OR,XOR; show -format dot -prefix ${TARGET}_out" ${OBJS}
	dot -Tsvg ${TARGET}_out.dot > ${TARGET}_flat.svg
	google-chrome ${TARGET}_flat.svg

clean:
	rm -rf *svg *out *dot a.out *.vcd *json *_synth.v *log *bit *rpt *svf *out.config

check_video_mem:
	@if [ "$(VID_INIT_FILE)" = video_mem_row.hex ]; then python3 gen_color_bars.py --row-only; fi
	@test -f "$(VID_INIT_FILE)" || { printf 'Falta el archivo de imagen: %s\n' "$(VID_INIT_FILE)" >&2; exit 1; }

$(BUILD_DIR):
	mkdir -p "$@"

build_icebreaker: VID_AW = 9
build_icebreaker: VID_BYTES = 480
build_icebreaker: VID_INIT_FILE = video_mem_row.hex
build_icebreaker: HW_PARAMS += ; chparam -set RESET_ACTIVE_LOW 1 -set RECOVERY_TICKS 2880000 $(TOP)
build_icebreaker: check_video_mem $(HW_DEPS) spi_lcd_icebreaker.pcf icebreaker_pre_pack.py | $(BUILD_DIR)
	yosys -l $(BUILD_DIR)/icebreaker.rpt -p 'read_verilog -defer -DLCD_$(LCD) $(HW_OBJS); $(HW_PARAMS); synth_ice40 -dsp -top $(TOP); write_json $(BUILD_DIR)/icebreaker.json'
	nextpnr-ice40 --json $(BUILD_DIR)/icebreaker.json --pcf spi_lcd_icebreaker.pcf --asc $(BUILD_DIR)/icebreaker.asc --pre-pack icebreaker_pre_pack.py --up5k --package sg48 --seed 1
	icepack -s $(BUILD_DIR)/icebreaker.asc $(BUILD_DIR)/icebreaker.bin

configure_icebreaker: build_icebreaker
	iceprog -d i:0x0403:0x6010 $(BUILD_DIR)/icebreaker.bin

build_lattice: check_video_mem $(HW_DEPS) spi_lcd_vid_mem.lpf | $(BUILD_DIR)
	yosys -l $(BUILD_DIR)/lattice.rpt -p 'read_verilog -defer -DLCD_$(LCD) $(HW_OBJS); $(HW_PARAMS); synth_ecp5 -top $(TOP); write_json $(BUILD_DIR)/lattice.json'
	nextpnr-ecp5 --json $(BUILD_DIR)/lattice.json --lpf spi_lcd_vid_mem.lpf --textcfg $(BUILD_DIR)/lattice.config --25k --package CABGA256 --speed 6 --seed 1
	ecppack --bootaddr 0 --compress $(BUILD_DIR)/lattice.config --svf $(BUILD_DIR)/lattice.svf --bit $(BUILD_DIR)/lattice.bit

configure_lattice: build_lattice
	sudo openFPGALoader -c ft232RL --pins=TXD:CTS:DTR:RXD -m $(BUILD_DIR)/lattice.bit

build_tang_primer_25k: check_video_mem $(HW_DEPS) gowin_build.tcl sipeed_tang_primer_25k.cst sipeed_tang_primer_25k.sdc | $(BUILD_DIR)
	@test "$(VID_AW)" = 18 -a "$(VID_INIT_FILE)" = video_mem_init.hex || { printf 'Gowin utiliza los parámetros predeterminados del módulo.\n' >&2; exit 1; }
	LCD=$(LCD) GOWIN_BOARD=primer_25k gw_sh gowin_build.tcl
	cp impl/pnr/project.fs $(BUILD_DIR)/tang_primer_25k.fs

configure_tang_primer_25k: build_tang_primer_25k
	openFPGALoader --cable ft2232 --bitstream $(BUILD_DIR)/tang_primer_25k.fs

build_tang_nano_20k: check_video_mem $(HW_DEPS) gowin_build.tcl sipeed_tang_nano_20k.cst sipeed_tang_nano_20k.sdc | $(BUILD_DIR)
	@test "$(VID_AW)" = 18 -a "$(VID_INIT_FILE)" = video_mem_init.hex || { printf 'Gowin utiliza los parámetros predeterminados del módulo.\n' >&2; exit 1; }
	LCD=$(LCD) GOWIN_BOARD=nano_20k gw_sh gowin_build.tcl
	cp impl/pnr/project.fs $(BUILD_DIR)/tang_nano_20k.fs

configure_tang_nano_20k: build_tang_nano_20k
	openFPGALoader --cable ft2232 --bitstream $(BUILD_DIR)/tang_nano_20k.fs

.PHONY: sim svg svg-flat clean check_video_mem build_icebreaker build_lattice \
        build_tang_primer_25k build_tang_nano_20k configure_icebreaker \
        configure_lattice configure_tang_primer_25k configure_tang_nano_20k
