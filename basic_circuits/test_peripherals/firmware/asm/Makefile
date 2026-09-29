# *************************************************
# IMPORTANTE PARA PODER COMPILAR ESTE EJEMPLO:
# En el archivo:litex/litex/soc/software/common.mak
# cambiar de:
# ifeq ($(LTO), 1)
# COMMONFLAGS += -flto
# endif
# a:
# COMMONFLAGS += -flto
# *************************************************
#OBJECTS =  get_number.o bin2bcd.o bcd2bin.o bin_to_bcd.o sqrt.o mult.o div.o wait.o putchar.o getchar.o calculator.o putstring.o#hello.o 
#OBJS =  calculator.o #cambiar por todas las unidades .o del proyecto
#OBJS    = for.o # cambiar por el main del proyecto
#OBJECTS = for.o

#export PATH=$(PATH):/Work/Embedded/toolchain/bin/



TARGET  = for
#OBJS    = call_$(TARGET).o get_number.o bin2bcd.o bcd2bin.o bin_to_bcd.o putchar.o getchar.o putstring.o
#OBJECTS = $(OBJS) $(TARGET).o
OBJS    = for.o
OBJECTS = $(OBJS)

CROSS   = riscv32-unknown-elf
CC      = $(CROSS)-gcc
AS      = $(CROSS)-as
LD      = $(CROSS)-ld
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump
AFLAGS  = -march=rv32i -mabi=ilp32
BRed    =\033[1;31m         # Red
Color_Off=\033[0m       # Text Reset

all: install_toolchain firmware.hex 

install_toolchain:
	echo "${BRed} DON'T FORGET TYPE:  ${Red} export PATH=$PATH:/xxxx_xxxx/toolchain/bin/ ${Color_Off}"

firmware.bin: firmware.elf
	$(OBJCOPY) -O verilog $< firmware_flash.hex
	$(OBJCOPY) -O ihex $< firmware_flash_intel.hex
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

firmware.elf: $(OBJECTS) bram.ld
	$(LD) $(LDFLAGS) -T bram.ld  -m elf32lriscv -nostdlib -Map firmware.map -N -o $@ $(OBJECTS)
	chmod -x $@
	
firmware.hex: firmware.elf firmware.lst firmware.bin
	../firmware_words_src/firmware_words firmware.elf -ram 16384 -max_addr 16384  -out firmware.hex
	cp firmware.hex ../../rtl
	cp firmware_flash.hex ../../rtl

firmware.lst: firmware.elf
	$(OBJDUMP) -h -S $< > $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< 
%.o: %.S
	$(AS) $(AFLAGS) -c $< -o $@
clean:
	rm -rf  $(OBJECTS) *.elf *.bin .*~ *~ *.map *.d *.hex *.o *.lst
.PHONY: clean bram.ld

# Generar bram.ld directamente desde Makefile
bram.ld:
	@echo "MEMORY {"                         >  bram.ld
	@echo "   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x4000  /* 6kB RAM */" >> bram.ld
	@echo "}"                                >> bram.ld
	@echo "SECTIONS"                         >> bram.ld
	@echo "{"                                >> bram.ld
	@echo "    everything :"                 >> bram.ld
	@echo "    {"                            >> bram.ld
	@echo "        . = ALIGN(4);"            >> bram.ld
	@echo "        $(OBJS)(.text)"          >> bram.ld
	@echo "        *(.*)"                    >> bram.ld
	@echo "    } >BRAM"                      >> bram.ld
	@echo "}"                                >> bram.ld


#export PATH=$PATH:/home/carlos/Embedded/litex_work/learn-fpga/FemtoRV/FIRMWARE/TOOLCHAIN/riscv64-unknown-elf-gcc-8.3.0-2020.04.0-x86_64-linux-ubuntu14/bin/
