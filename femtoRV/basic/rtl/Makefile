#   run make TOP=SOC or make TOP=SOC_flash
#   minicom -b 1000000 -D /dev/ttyACM0    #PARA la ICESugar-Pro corriendo Linux 
EFINITY_HOME  = /home/carlos/Embedded/efinity/2023.2/
EFXPT_HOME    = $(EFINITY_HOME)/pt

TARGET=SOC
TOP=SOC

ECP5_SIM_CELLS  = $(shell yosys-config --datdir/ecp5/cells_sim.v)
ECP5_SIM_CELLS += $(shell yosys-config --datdir/ecp5/cells_bb.v)
#ECP5_SIM_CELLS += $(shell yosys-config --datdir/ecp5/cells_map.v)

EFINIX_SIM_CELLS   = sim_models_efx/efx_ff.v  sim_models_efx/efx_dpram_5k.v sim_models_efx/efx_ram_5k.v sim_models_efx/efx_lut4.v sim_models_efx/efx_add.v sim_models_efx/efx_gbufce.v 
ICE40_SIM_CELLS=$(shell yosys-config --datdir/ice40/cells_sim.v)


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

TCL_SCRIPT = auto_generated.tcl

COMM_OBJS+=  cores/cpu/femtorv32_quark_V2.v
COMM_OBJS+= cores/uart/perip_uart.v
COMM_OBJS+= cores/uart/uart.v



COMM_OBJS+= cores/mult_ASM/perip_mult.v
COMM_OBJS+= cores/mult_ASM/mult_32.v
COMM_OBJS+= cores/mult_ASM/acc.v
COMM_OBJS+= cores/mult_ASM/comp.v
COMM_OBJS+= cores/mult_ASM/lsr_mult.v
COMM_OBJS+= cores/mult_ASM/control_mult.v
COMM_OBJS+= cores/mult_ASM/rsr.v


COMM_OBJS+= cores/divider_ASM/peripheral_div.v
COMM_OBJS+= cores/divider_ASM/div_16/div_16.v
COMM_OBJS+= cores/divider_ASM/div_16/control_div.v 
COMM_OBJS+= cores/divider_ASM/div_16/counter_div.v
COMM_OBJS+= cores/divider_ASM/div_16/subtractor.v
COMM_OBJS+= cores/divider_ASM/div_16/lsr_div.v 
            


COMM_OBJS+= cores/sqrt_ASM/addc2.v
COMM_OBJS+= cores/sqrt_ASM/count.v
COMM_OBJS+= cores/sqrt_ASM/lsr.v 
COMM_OBJS+= cores/sqrt_ASM/perip_sqrt.v
COMM_OBJS+= cores/sqrt_ASM/sqrt.v
COMM_OBJS+= cores/sqrt_ASM/lsr2.v
COMM_OBJS+= cores/sqrt_ASM/control.v

COMM_OBJS+=cores/bin2bcd/add_sub_c2.v
COMM_OBJS+=cores/bin2bcd/bin2bcd.v
COMM_OBJS+=cores/bin2bcd/mux2.v
COMM_OBJS+=cores/bin2bcd/count.v
COMM_OBJS+=cores/bin2bcd/ctrl_b2b.v  
COMM_OBJS+=cores/bin2bcd/perip_bin2bcd.v
COMM_OBJS+=cores/bin2bcd/lsr4.v
COMM_OBJS+=cores/bin2bcd/reg_msb.v

COMM_OBJS+=cores/bcd2bin/bcd2bin.v
COMM_OBJS+=cores/bcd2bin/perip_bcd2bin.v
COMM_OBJS+=cores/bcd2bin/rsr4.v
COMM_OBJS += cores/bram/bram.v
COMM_OBJS +=  SOC.v

OBJS += $(COMM_OBJS)

FLASH_OBJS =  $(COMM_OBJS)
FLASH_OBJS += cores/spi_flash/MappedSPIFlash.v
FLASH_OBJS += SOC_flash.v
SIM_OBJS   = cores/sim_spi_flash/spiflash.v



BUILD_DIR = build

all: sim_quark

sim_quark:
	rm -f a.out *.vcd
	iverilog -DBENCH  bench_quark.v $(OBJS)
	vvp a.out
	gtkwave bench.vcd

sim_quark_flash:
	rm -f a.out *.vcd
	iverilog -DBENCH -DSIM -DPASSTHROUGH_PLL -DBOARD_FREQ=27 -DCPU_FREQ=27 bench_quark_flash.v $(FLASH_OBJS) $(SIM_OBJS)
	vvp a.out
	gtkwave bench.vcd

sim_verilator: 
	verilator -CFLAGS '-I../libfemtorv32/ -DSTANDALONE_FEMTOELF' -DBENCH -DBOARD_FREQ=10 -DCPU_FREQ=10 -DPASSTHROUGH_PLL -Wno-fatal \
	--top-module SOC -cc -exe sim_main.cpp libfemtorv32/femto_elf.c soc_femto.v
	cd obj_dir; make -f VSOC.mk 
	obj_dir/VSOC

## ---------------------
## post-synth simulation
## ---------------------
sim_post_syn_quark:  $(OBJS)
	rm -f *vpp

#	         yosys -v3 -p  'abc -dff; read_verilog $(OBJS); abc -keepff ;  synth_ecp5  -top $(TARGET); write_verilog $(TOP)_synth.v' -l ${TARGET}.rpt
	yosys -v3 -l synth.log -p ' synth_ecp5 -top $(TOP) -json $(TOP).json; write_verilog -attr2comment $(TOP)_synth.v' ${OBJS}
	iverilog -g2012 -DSYNTH -o $@_PS.vpp -s bench  bench_quark.v $(TOP)_synth.v $(ECP5_SIM_CELLS)
#	yosys -v3  -p ' read_verilog $(OBJS);  synth_ice40  -top $(TARGET); write_verilog $(TOP)_synth.v' -l ${TARGET}.rpt
#	iverilog -g2012 -DSYNTH -o $@_PS.vpp -s bench  bench_quark.v $(TOP)_synth.v $(ICE40_SIM_CELLS)

	vvp $@_PS.vpp
	gtkwave bench.vcd &

sim_post_syn_quark_efx:  $(OBJS)
	rm -f *vpp *.vcd
	yosys -v3 -l synth.log -p ' synth_efinix -top SOC -json $(TOP).json; write_verilog -attr2comment $(TOP)_synth.v' ${OBJS}
	iverilog -DSYNTH -o $@_PS.vpp -s $(TARGET)_TB $(TARGET)_TB.v $(TOP)_synth.v $(EFINIX_SIM_CELLS) 
	vvp $@_PS.vpp
	gtkwave $(TARGET)_TB.vcd
  	
svg: $(OBJS)
	yosys -p "prep -top ${TARGET}; write_json ${TARGET}.json" -DPASSTHROUGH_PLL -DBOARD_FREQ=27 -DCPU_FREQ=27  ${OBJS}
	netlistsvg ${TARGET}.json -o ${TARGET}.svg  #--skin default.svg
	yosys -p "prep -top ${TARGET} -flatten; write_json ${TARGET}_flat.json" ${OBJS}
	netlistsvg ${TARGET}_flat.json -o ${TARGET}_flat.svg  #--skin default.svg



configure: ${TARGET}.fs
	sudo openFPGALoader -b tangprimer20k -m impl/pnr/project.fs
########################
#  LATTICE COLORLIGHT 5A
########################
$(TARGET)_out.config: $(TARGET).json
	nextpnr-ecp5 --json $(BUILD_DIR)/$< --lpf $(TARGET).lpf --textcfg $(BUILD_DIR)/$@ --25k --package CABGA256 --speed 6  --timing-allow-fail --seed 1 --lpf-allow-unconstrained  --log $(TARGET)_pnr.log 
#	nextpnr-ecp5 --json $< --lpf $(TARGET).lpf --textcfg $@ --25k --package CABGA381 --speed 6  --timing-allow-fail --seed 1 --lpf-allow-unconstrained
$(TARGET).json: $(OBJS)
	mkdir -p $(BUILD_DIR)
#	yosys -p 'verilog_defaults -push; verilog_defaults -add -defer; read_verilog -formal $(OBJS); verilog_defaults -pop; attrmap -tocase keep -imap keep="true" keep=1 -imap keep="false" keep=1 -remove keep=0; synth_ecp5 -top $(TARGET); write_json $(BUILD_DIR)/$@' -l $(BUILD_DIR)/${TARGET}.rpt
	yosys -v3 -l synth.log -p 'attrmap -tocase keep -imap keep="true" keep=1  ; synth_ecp5 -top $(TARGET);  write_json  $(BUILD_DIR)/$@' ${OBJS} -l $(BUILD_DIR)/${TARGET}.rpt

$(TARGET).bit: $(TARGET)_out.config
	ecppack --bootaddr 0 --compress $(BUILD_DIR)/$< --svf $(BUILD_DIR)/${TARGET}.svf --bit $(BUILD_DIR)/$@

configure_lattice: ${TARGET}.bit   # TDI:TDO:TCK:TMS TXD:CTS:DTR:RXD
#	sudo openFPGALoader -c ft232RL --pins=0:3:4:1 -m $(BUILD_DIR)/${TARGET}.bit 	
#	sudo openFPGALoader -c ft232RL --pins=RXD:RTS:TXD:CTS -m $(BUILD_DIR)/${TARGET}.bit 	
	sudo openFPGALoader -c ft232RL --pins=TXD:CTS:DTR:RXD -m $(BUILD_DIR)/${TARGET}.bit	
########################
#  LATTICE COLORLIGHT I5
########################
$(TARGET)_i5.json: $(OBJS)
	mkdir -p $(BUILD_DIR)
	yosys -p 'verilog_defaults -push; verilog_defaults -add -defer; read_verilog -formal $(OBJS); verilog_defaults -pop; attrmap -tocase keep -imap keep="true" keep=1 -imap keep="false" keep=0 -remove keep=0; synth_ecp5 -top $(TARGET); write_json $(BUILD_DIR)/$@' -l $(BUILD_DIR)/${TARGET}.rpt

$(TARGET)_i5_out.config: $(TARGET)_i5.json
	nextpnr-ecp5 --json $(BUILD_DIR)/$< --lpf $(TARGET)_i5.lpf --textcfg $(BUILD_DIR)/$@ --25k --package CABGA381 --speed 6  --timing-allow-fail --seed 1 --lpf-allow-unconstrained

$(TARGET)_i5.bit: $(TARGET)_i5_out.config
	ecppack --bootaddr 0 --compress $(BUILD_DIR)/$< --svf $(BUILD_DIR)/${TARGET}.svf --bit $(BUILD_DIR)/$@

configure_i5: ${TARGET}_i5.bit   # TDI:TDO:TCK:TMS
	sudo openFPGALoader -b colorlight-i5 -m $(BUILD_DIR)/${TARGET}_i5.bit 

.PHONY: clean

########################
#  LATTICE SUGAR-PRO v1.3
########################
$(TARGET)_sugar.json: $(OBJS)
	mkdir -p $(BUILD_DIR)
	yosys -p 'verilog_defaults -push; verilog_defaults -add -defer; read_verilog -formal $(OBJS); verilog_defaults -pop; attrmap -tocase keep -imap keep="true" keep=1 -imap keep="false" keep=0 -remove keep=0; synth_ecp5 -top $(TARGET); write_json $(BUILD_DIR)/$@' -l $(BUILD_DIR)/${TARGET}.rpt

$(TARGET)_sugar_out.config: $(TARGET)_sugar.json
	nextpnr-ecp5 --json $(BUILD_DIR)/$< --lpf $(TARGET)_sugar.lpf --textcfg $(BUILD_DIR)/$@ --25k --package CABGA256 --speed 6  --timing-allow-fail --seed 1 --lpf-allow-unconstrained

$(TARGET)_sugar.bit: $(TARGET)_sugar_out.config
	ecppack --bootaddr 0 --compress $(BUILD_DIR)/$< --svf $(BUILD_DIR)/${TARGET}.svf --bit $(BUILD_DIR)/$@

configure_sugar: ${TARGET}_sugar.bit   # TDI:TDO:TCK:TMS
	sudo openFPGALoader -b colorlight-i5 -m $(BUILD_DIR)/${TARGET}_sugar.bit 



########################
#  LATTICE COLORLIGHT I9
########################
$(TARGET)_i9.json: $(OBJS)
	mkdir -p $(BUILD_DIR)
	yosys -p 'verilog_defaults -push; verilog_defaults -add -defer; read_verilog -formal $(OBJS); verilog_defaults -pop; attrmap -tocase keep -imap keep="true" keep=1 -imap keep="false" keep=0 -remove keep=0; synth_ecp5 -top $(TARGET); write_json $(BUILD_DIR)/$@' -l $(BUILD_DIR)/${TARGET}.rpt

$(TARGET)_i9_out.config: $(TARGET)_i9.json
	nextpnr-ecp5 --json $(BUILD_DIR)/$< --lpf $(TARGET)_i9.lpf --textcfg $(BUILD_DIR)/$@ --45k --package CABGA381 --speed 6  --timing-allow-fail --seed 1 --lpf-allow-unconstrained

$(TARGET)_i9.bit: $(TARGET)_i9_out.config
	ecppack --bootaddr 0 --compress $(BUILD_DIR)/$< --svf $(BUILD_DIR)/${TARGET}.svf --bit $(BUILD_DIR)/$@

configure_i9: ${TARGET}_i9.bit   # TDI:TDO:TCK:TMS
	sudo openFPGALoader -b colorlight-i9 -m $(BUILD_DIR)/${TARGET}_i9.bit 


.PHONY: clean

##########################
#    ICEBREAKER
##########################

configure_icebreaker: 
#set -e
	yosys -l icebreaker.rpt -p 'verilog_defaults -push; verilog_defaults -add -defer; read_verilog  $(OBJS); verilog_defaults -pop; attrmap -tocase keep -imap keep="true" keep=1 -imap keep="false" keep=0 -remove keep=0; synth_ice40 -dsp -top ${TOP}; write_json  ${TOP}.json'
	nextpnr-ice40 --json ${TOP}.json --pcf SOC_icebreaker.pcf --asc icebreaker.asc  --pre-pack icebreaker_pre_pack.py  --up5k --package sg48 --timing-allow-fail --seed 1 
	icepack -s icebreaker.asc icebreaker.bin 
	iceprog -d i:0x0403:0x6010 icebreaker.bin






##########################
#    EFINIX ECB_T20_T113
#    Files:
#    SOC_peri.xml   pines
#    SOC.xml        source code
##########################
EFINITY_HOME=/Work/CAD/efinity/2024.2/
EFXPT_HOME=$(EFINITY_HOME)/pt
create_files:
#	export EFINITY_HOME=/Work/CAD/efinity/2024.2/
#	export PATH=$$PATH:/Work/CAD/efinity/2024.2/bin
#	export EFXPT_HOME=$(EFINITY_HOME)/pt
	$(EFINITY_HOME)/bin/python3  femtorv32.py
synth_efinix: create_files
	efx_map --project "$(TOP)" --root "$(TOP)" --write-efx-verilog "outflow/$(TOP).map.v" --write-premap-module "outflow/$(TOP).elab.vdb" --binary-db "outflow/$(TOP).vdb" --device "T20Q144" --family "Trion" --veri_option "verilog_mode=verilog_2k,vhdl_mode=vhdl_2008" --work-dir "work_syn" --output-dir "outflow" --project-xml "$(TOP).xml" --I "."
place_and_route_efinix: synth_efinix
#	efx_run_pt.py  "$(TOP)"  "Trion"  "T20Q144"
	efx_pnr --circuit "$(TOP)" --family "Trion" --device "T20Q144" --operating_conditions "C3" --pack --place --vdb_file "outflow/$(TOP).vdb" --use_vdb_file "on" --place_file "outflow/$(TOP).place" --route_file "outflow/$(TOP).route" --sdc_file "$(TOP).sdc" --sync_file "outflow/$(TOP).interface.csv" --seed "1" --placer_effort_level "2" --max_threads "-1" --print_critical_path "10" --work_dir "work_pnr" --output_dir "outflow" --timing_analysis "on" --load_delay_matrix
	efx_pnr --circuit "$(TOP)" --family "Trion" --device "T20Q144" --operating_conditions "C3" --route --vdb_file "outflow/$(TOP).vdb" --use_vdb_file "on" --place_file "outflow/$(TOP).place" --route_file "outflow/$(TOP).route" --sdc_file "$(TOP).sdc" --sync_file "outflow/$(TOP).interface.csv" --seed "1" --placer_effort_level "2" --max_threads "-1" --print_critical_path "10" --work_dir "work_pnr" --output_dir "outflow" --timing_analysis "on" --load_delay_matrix
bitstream_efinix: place_and_route_efinix
	$(EFINITY_HOME)/bin/efx_pgm --source "work_pnr/$(TOP).lbf" --dest "outflow/$(TOP).hex" --device "T20Q144" --family "Trion" --periph "outflow/$(TOP).lpf" --interface_designer_settings "outflow/$(TOP)_or.ini" --enable_external_master_clock "off" --oscillator_clock_divider "DIV8" --active_capture_clk_edge "posedge" --spi_low_power_mode "on" --io_weak_pullup "on" --enable_roms "smart" --mode "active" --width "1" --release_tri_then_reset "on"
configure_efinix: bitstream_efinix
	openFPGALoader -b trion_t120_bga576  outflow/$(TOP).bit
clean_efinix:
	rm -rf work_pnr work_pt work_syn outflow $(TOP).peri.xml


##########################
#    EFINIX TI60
##########################

#EFINITY_HOME=/home/carlos/Embedded/efinity/2023.2/
#EFXPT_HOME=$(EFINITY_HOME)/pt

svg_flash: $(FLASH_OBJS)
	yosys -p "prep -top ${TARGET}; write_json ${TARGET}.json" -DPASSTHROUGH_PLL -DBOARD_FREQ=27 -DCPU_FREQ=27  ${FLASH_OBJS}
	netlistsvg ${TARGET}.json -o ${TARGET}_flash.svg  #--skin default.svg
	yosys -p "prep -top ${TARGET} -flatten; write_json ${TARGET}_flat.json" ${FLASH_OBJS}
	netlistsvg ${TARGET}_flat.json -o ${TARGET}_flat_flash.svg  #--skin default.svg



create_files_flash:
	$(EFINITY_HOME)/bin/python3  femtorv32_flash.py
synth_flash: create_files_flash
	$(EFINITY_HOME)/bin/efx_map --project "$(TOP)" --root "$(TOP)" --write-efx-verilog "outflow/$(TOP).map.v" --write-premap-module "outflow/$(TOP).elab.vdb" --binary-db "outflow/$(TOP).vdb" --device "T20Q144" --family "Trion" --veri_option "verilog_mode=verilog_2k,vhdl_mode=vhdl_2008" --work-dir "work_syn" --output-dir "outflow" --project-xml "$(TOP).xml" --I "."
place_and_route_flash: synth_flash
	$(EFINITY_HOME)/bin/python3  "/home/carlos/Embedded/efinity/2023.2/scripts/efx_run_pt.py"  "$(TOP)"  "Trion"  "T20Q144"
	$(EFINITY_HOME)/bin/efx_pnr --circuit "$(TOP)" --family "Trion" --device "T20Q144" --operating_conditions "C3" --pack --place --vdb_file "outflow/$(TOP).vdb" --use_vdb_file "on" --place_file "outflow/$(TOP).place" --route_file "outflow/$(TOP).route" --sdc_file "$(TOP).sdc" --sync_file "outflow/$(TOP).interface.csv" --seed "1" --placer_effort_level "2" --max_threads "-1" --print_critical_path "10" --work_dir "work_pnr" --output_dir "outflow" --timing_analysis "on" --load_delay_matrix
	$(EFINITY_HOME)/bin/efx_pnr --circuit "$(TOP)" --family "Trion" --device "T20Q144" --operating_conditions "C3" --route --vdb_file "outflow/$(TOP).vdb" --use_vdb_file "on" --place_file "outflow/$(TOP).place" --route_file "outflow/$(TOP).route" --sdc_file "$(TOP).sdc" --sync_file "outflow/$(TOP).interface.csv" --seed "1" --placer_effort_level "2" --max_threads "-1" --print_critical_path "10" --work_dir "work_pnr" --output_dir "outflow" --timing_analysis "on" --load_delay_matrix
bitstream_flash: place_and_route_flash
	$(EFINITY_HOME)/bin/efx_pgm --source "work_pnr/$(TOP).lbf" --dest "outflow/$(TOP).hex" --device "T20Q144" --family "Trion" --periph "outflow/$(TOP).lpf" --interface_designer_settings "outflow/$(TOP)_or.ini" --enable_external_master_clock "off" --oscillator_clock_divider "DIV8" --active_capture_clk_edge "posedge" --spi_low_power_mode "on" --io_weak_pullup "on" --enable_roms "smart" --mode "active" --width "1" --release_tri_then_reset "on"
configure_efinix_flash: outflow/$(TOP).bit
	openFPGALoader -b trion_t120_bga576  outflow/$(TOP).bit
clean_efinix_flash:
	rm -rf work_pnr work_pt work_syn outflow $(TOP).peri.xml

clean: clean_efinix_flash  clean_efinix clean_gowin
	rm -rf impl obj_dir *svg a.out *.vcd *.json *.bit build


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




#Install netlistsvg for svg generation



# export PATH=$PATH:/Work/CAD/IDE/bin/
# export QT_QPA_PLATFORM_PLUGIN_PATH=/Work/CAD/IDE/Programmer/bin/PyQt5/qt-plugins
# export QT_QPA_PLATFORM=xcb
# export QT_XCB_GL_INTEGRATION=none