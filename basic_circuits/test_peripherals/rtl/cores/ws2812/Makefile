TARGET = DEMO_ws2812_led_array
ICE40_SIM_CELLS=./lattice_sim/cells_sim_ecp5.v

ifeq ($(TARGET), ws2812)
    OBJS = comp_ws.v  count_ws.v  ctrl_ws.v  mux_ws.v  ws2812.v
else ifeq ($(TARGET), ws2812_led)
    OBJS = comp_ws.v  count_ws.v  ctrl_ws.v  mux_ws.v  ws2812.v 
	       lsr_wsled.v count_wsled.v ctrl_wsled.v ws2812_led.v
else ifeq ($(TARGET), ws2812_led_array)
    OBJS = comp_ws.v  count_ws.v  ctrl_ws.v  mux_ws.v  ws2812.v \
	lsr_wsled.v count_wsled.v ctrl_wsled.v ws2812_led.v         \
	led_mem.v count_addr.v ctrl_ws_arr.v comp_ws_arr.v ws2812_led_array.v
else ifeq ($(TARGET), DEMO_ws2812_led_array)
    OBJS = comp_ws.v  count_ws.v  ctrl_ws.v  mux_ws.v  ws2812.v \
	lsr_wsled.v count_wsled.v ctrl_wsled.v ws2812_led.v         \
	led_mem.v count_addr.v ctrl_ws_arr.v comp_ws_arr.v ws2812_led_array.v \
	DEMO_ws2812_led_array.v
else
    OBJS = ${TARGET}.v
endif

sim:
	rm -f a.out *.vcd
	iverilog  -DBENCH $(TARGET)_TB.v $(OBJS)
	vvp a.out
	gtkwave $(TARGET)_TB.vcd
sim_post_syn:
	yosys -v3 -l synth.log -p 'synth_ecp5 -top $(TARGET) -json $(TARGET).json; write_verilog -attr2comment $(TARGET)_synth.v' $(OBJS)
	iverilog  -I ./lattice_sim  $(TARGET)_TB.v $(TARGET)_synth.v $(ICE40_SIM_CELLS) 
	vvp a.out
	gtkwave $(TARGET)_TB.vcd
svg: $(OBJS)
	rm -rf *svg *out *dot
	yosys -p "prep -top ${TARGET}; memory -nomap; opt; opt_expr; techmap; abc -g AND,OR,XOR; write_json ${TARGET}.json" ${OBJS}
	yosys -p "read_verilog ${TARGET}.v; proc; memory -nomap; opt; opt_expr; techmap; abc -g AND,OR,XOR; show -format dot -prefix ${TARGET}_out"
	netlistsvg ${TARGET}.json -o ${TARGET}.svg
	google-chrome ${TARGET}.svg

#LATTICE COLORLIGHT 5A
$(TARGET).json : $(BUILD_DIR)
	yosys -v3 -q -l synth.log -p 'attrmap -tocase keep -imap keep="true" keep=1; synth_ecp5 -top $(TARGET) -json $(TARGET).json; write_verilog -attr2comment  $(TARGET)_synth.v ' $(OBJS) -l  $(TARGET).rpt
$(TARGET)_out.config : $(TARGET).json
	nextpnr-ecp5 --json $(TARGET).json --lpf $(TARGET).lpf --textcfg $(TARGET)_out.config --25k --package CABGA256 --speed 6 --timing-allow-fail --seed 1 --lpf-allow-unconstrained --log  $(TARGET)_pnr.log
$(TARGET).bit :  $(TARGET)_out.config
	ecppack --bootaddr 0 --compress $(TARGET)_out.config --svf $(TARGET).svf --bit $@

configure_lattice: $(TARGET).bit   # TDI:TDO:TCK:TMS TXD:CTS:DTR:RXD
#	sudo openFPGALoader -c ft232RL --pins=0:3:4:1 -m  ${TARGET}.bit 	
#	sudo openFPGALoader -c ft232RL --pins=RXD:RTS:TXD:CTS -m  ${TARGET}.bit 	
	sudo openFPGALoader -c ft232RL --pins=TXD:CTS:DTR:RXD -m  ${TARGET}.bit	

clean:
	rm -rf *svg *out *dot a.out *.vcd *json *_synth.v *log *bit *rpt *svf *out.config
