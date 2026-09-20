TARGET = pwm_led_panel
TOP    = pwm_led_panel

ICE40_SIM_CELLS=$(shell yosys-config --datdir/ice40/cells_sim.v)

COMM_OBJS += pwm_led_panel.v
COMM_OBJS += show_data.v
COMM_OBJS += load_data.v
COMM_OBJS += count.v
COMM_OBJS += count_l.v
COMM_OBJS += ctrl_show.v
COMM_OBJS += lsr_config.v
COMM_OBJS += ctrl_cfg.v

COMM_OBJS += out_lsr.v
COMM_OBJS += memory.v
COMM_OBJS += mux_led.v





SIM_OBJS =  ../../verilog_model/sky130_fd_sc_hd.v
SIM_OBJS += ../../verilog_model/primitives.v

PER_OBJS = perip_sqrt.v $(OBJS)

BUILD_DIR = build

TCL_SCRIPT = auto_generated.tcl
GOWIN_BOARD=primer_25k


ifeq ($(GOWIN_BOARD),nano_20k)
    DEVICE = GW2AR-LV18QN88C8/I7
    FAMILY = GW2AR-18C
else ifeq ($(GOWIN_BOARD),primer_25k)
    DEVICE = GW5A-LV25MG121NC1/I0
    FAMILY = GW5A-25A
else
    $(error GOWIN_BOARD=$(GOWIN_BOARD) no válido. Usa: nano_20k o primer_25k)
endif



all: sim

sim:
	rm -f a.out *.vcd
	iverilog -DBENCH -o a.out $(TARGET)_TB.v $(COMM_OBJS)
	vvp a.out
	gtkwave $(TARGET)_TB.vcd $(TARGET)_sim.gtkw &
sim_per:
	rm -f a.out *.vcd
	iverilog -DBENCH   perip_$(TARGET)_TB.v $(PER_OBJS)
	vvp a.out
	gtkwave perip_$(TARGET)_TB.vcd &
$(TOP).json:
	yosys -v3  -p ' read_verilog $(OBJS);  synth_ice40  -top $(TARGET); write_verilog $(TOP)_synth.v' -l ${TARGET}.rpt

sim_countl:
	iverilog -DBENCH  count_l_TB.v count_l.v
	vvp a.out
	gtkwave count_l_TB.vcd &


sim_out_lsr:
	iverilog -DBENCH  out_lsr_TB.v out_lsr.v
	vvp a.out
	gtkwave out_lsr_TB.vcd &
#	yosys -v3 -l synth.log -p 'synth_ice40 -top $(TOP) -json $(TOP).json; write_verilog -attr2comment $(TOP)_synth.v' $(OBJS)
#	yosys -p "read_verilog $(TOP)_synth.v; read_verilog cells_sim.v; prep -top $(TOP); show -format svg -prefix yosys"  # Visualize


## ---------------------
## post-synth simulation
## ---------------------
sim_post_syn: $(TOP).json $(OBJS)
	iverilog -g2012 -DSYNTH -o $@_PS.vpp -s $(TOP)_TB $(TARGET)_TB.v $(TOP)_synth.v $(ICE40_SIM_CELLS) 
	vvp $@_PS.vpp
	gtkwave $(TOP)_TB.vcd &
sim_post_syn_sky:
	yosys -l synth.log -c synth.tcl
	cp out.v $(TOP)_synth_sky.v 
	iverilog -DFUNCTIONAL -DUNIT_DELAY=#1 -o $@_PS.vpp -s $(TOP)_TB $(TARGET)_TB.v $(TOP)_synth_sky.v ${SIM_OBJS}
	vvp $@_PS.vpp
	./$@_PS.vpp
	gtkwave $(TOP)_TB.vcd &
	#netlistsvg ${TARGET}.json -o ${TARGET}.svg  #--skin default.svg
	

## ---------------------
## post-route simulation
## ---------------------
$(TOP).asc: $(TOP).json
	nextpnr-ice40 --hx8k --package ct256 --json $(TOP).json --pcf $(TOP).pcf --asc $@  --routed-svg $(TOP)_routed.svg --placed-svg $(TOP)_placed.svg #--pcf-allow-unconstrained
sim_post_route: $(TOP).asc $(TOP).pcf
	icebox_vlog -L -n $(TOP) -sp $(TOP).pcf $< > $(TOP)_route.v
	iverilog -o $@.vpp -s $(TOP)_TB $(TARGET)_post_route_TB.v  $(TOP)_route.v  $(ICE40_SIM_CELLS)
	chmod -x $@
	vvp $@.vpp
	gtkwave $(TOP)_TB.vcd &

svg: $(OBJS)
	yosys -p "prep -top ${TARGET}; write_json ${TARGET}.json" ${OBJS}
	netlistsvg ${TARGET}.json -o ${TARGET}.svg  #--skin default.svg
	yosys -p "prep -top ${TARGET} -flatten; write_json ${TARGET}_flat.json" ${OBJS}
	netlistsvg ${TARGET}_flat.json -o ${TARGET}_flat.svg  #--skin default.svg

clean:
	rm -rf *.out *.vcd *.svg *.json $(TOP)_synth.v *.vpp *.asc $(TOP)_route.v synth.log *bin *rpt *asc



########################################################
##                      GOWIN                         ##
##           
########################################################


#  GOWIN TANG NANO
del_tcl_script:
#   GOWIN TANG NANO 20K
	rm -rf $(TCL_SCRIPT)
$(TCL_SCRIPT):del_tcl_script
	@echo "# Script TCL generado automáticamente desde Makefile" > $@
	@echo "# Fecha: $$(date)" >> $@
	@echo "" >> $@
	@echo "# Configurar dispositivo" >> $@
	@echo "set_device -name $(FAMILY) $(DEVICE)" >> $@
	@echo "" >> $@


ifeq ($(GOWIN_BOARD),nano_20k)
	@echo "add_file sipeed_tang_nano_20k.cst" >> $@
	@echo "add_file sipeed_tang_nano_20k.sdc" >> $@
else ifeq ($(GOWIN_BOARD),primer_25k)
	@echo "add_file sipeed_tang_primer_25k.cst" >> $@
	@echo "add_file sipeed_tang_primer_25k.sdc" >> $@
else
    $(error GOWIN_BOARD=$(GOWIN_BOARD) no válido. Usa: nano_20k o primer_25k)
endif

	@echo "# Agregar archivos fuente" >> $@
	@for file in $(COMM_OBJS); do \
		echo "add_file -type verilog $$file" >> $@; \
	done
	@echo "" >> $@
	@echo "# Configurar opciones del proyecto" >> $@

	@echo "set_option -use_mspi_as_gpio 1" >> $@
ifeq ($(GOWIN_BOARD),nano_20k)
	@echo "set_option -use_sspi_as_gpio 1" >> $@
else ifeq ($(GOWIN_BOARD),primer_25k)
	@echo "set_option -use_i2c_as_gpio 1" >> $@
else
    $(error GOWIN_BOARD=$(GOWIN_BOARD) no válido. Usa: nano_20k o primer_25k)
endif

	@echo "set_option -use_ready_as_gpio 1" >> $@
	@echo "set_option -use_done_as_gpio 1" >> $@
ifeq ($(GOWIN_BOARD),primer_25k)
	@echo "set_option -use_cpu_as_gpio 1" >> $@
endif

	@echo "set_option -rw_check_on_ram 1" >> $@
	@echo "run all" >> $@

configure_tang_nano_20k: clean_gowin $(TCL_SCRIPT)
	gw_sh  $(TCL_SCRIPT)
	openFPGALoader --cable ft2232 --bitstream ./impl/pnr/project.fs

clean_gowin:
	rm -rf impl

configure_tang_primer_25k: $(TCL_SCRIPT)
	gw_sh  $(TCL_SCRIPT)
	openFPGALoader --cable ft2232 --bitstream ./impl/pnr/project.fs






configure_icebreaker: 
#set -e
	yosys -l icebreaker.rpt -p 'verilog_defaults -push; verilog_defaults -add -defer; read_verilog  $(COMM_OBJS); verilog_defaults -pop; attrmap -tocase keep -imap keep="true" keep=1 -imap keep="false" keep=0 -remove keep=0; synth_ice40 -dsp -top ${TOP}; write_json  ${TOP}.json'
	nextpnr-ice40 --json ${TOP}.json --pcf led_panel_icebreaker.pcf --asc icebreaker.asc  --pre-pack icebreaker_pre_pack.py  --up5k --package sg48 --timing-allow-fail --seed 1  --pcf-allow-unconstrained
	icepack -s icebreaker.asc icebreaker.bin 
	iceprog -d i:0x0403:0x6010 icebreaker.bin


########################
#  LATTICE COLORLIGHT 5A
########################
$(TARGET)_out.config: $(TARGET).json
	nextpnr-ecp5 --json $(BUILD_DIR)/$< --lpf $(TARGET).lpf --textcfg $(BUILD_DIR)/$@ --25k --package CABGA256 --speed 6  --timing-allow-fail --seed 1 --lpf-allow-unconstrained  --log $(TARGET)_pnr.log 
#	nextpnr-ecp5 --json $< --lpf $(TARGET).lpf --textcfg $@ --25k --package CABGA381 --speed 6  --timing-allow-fail --seed 1 --lpf-allow-unconstrained
$(TARGET).json: $(OBJS)
	mkdir -p $(BUILD_DIR)
#	yosys -p 'verilog_defaults -push; verilog_defaults -add -defer; read_verilog -formal $(OBJS); verilog_defaults -pop; attrmap -tocase keep -imap keep="true" keep=1 -imap keep="false" keep=1 -remove keep=0; synth_ecp5 -top $(TARGET); write_json $(BUILD_DIR)/$@' -l $(BUILD_DIR)/${TARGET}.rpt
	yosys -v3 -l synth.log -p 'attrmap -tocase keep -imap keep="true" keep=1  ; synth_ecp5 -top $(TARGET);  write_json  $(BUILD_DIR)/$@' ${COMM_OBJS} -l $(BUILD_DIR)/${TARGET}.rpt
$(TARGET).bit: $(TARGET)_out.config
	ecppack --bootaddr 0 --compress $(BUILD_DIR)/$< --svf $(BUILD_DIR)/${TARGET}.svf --bit $(BUILD_DIR)/$@

configure_lattice: ${TARGET}.bit   # TDI:TDO:TCK:TMS TXD:CTS:DTR:RXD
#	sudo openFPGALoader -c ft232RL --pins=0:3:4:1 -m $(BUILD_DIR)/${TARGET}.bit 	
#	sudo openFPGALoader -c ft232RL --pins=RXD:RTS:TXD:CTS -m $(BUILD_DIR)/${TARGET}.bit 	
	sudo openFPGALoader -c ft232RL --pins=TXD:CTS:DTR:RXD -m $(BUILD_DIR)/${TARGET}.bit


#export PATH=$PATH:/Work/CAD/IDE/bin/
#export QT_QPA_PLATFORM_PLUGIN_PATH=/Work/CAD/IDE/Programmer/bin/PyQt5/qt-plugins
#export QT_QPA_PLATFORM=xcb
#export QT_XCB_GL_INTEGRATION=none


#https://stackoverflow.com/questions/35927650/is-it-possible-to-create-a-simulation-waveform-from-yosys-output

