TARGET := perip_blink
SIM    := $(TARGET)_TB

.PHONY: all sim wave clean

all: sim

sim:
	iverilog -Wall -o $(SIM).out $(TARGET).v $(SIM).v
	vvp $(SIM).out

wave: sim
	gtkwave $(SIM).gtkw

clean:
	rm -f $(SIM).out $(SIM).vcd
