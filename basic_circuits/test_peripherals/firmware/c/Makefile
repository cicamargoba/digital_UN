OBJECTS =  test_printf.o
TARGET     = test_printf
#CROSS   = riscv64-unknown-elf
CROSS   = riscv64-unknown-elf
CC      = $(CROSS)-gcc
AS      = $(CROSS)-as
LD      = $(CROSS)-ld
OBJDUMP = $(CROSS)-objdump
LIB_DIR = -Llibfemtorv -L/usr/lib/gcc/riscv64-unknown-elf/14.2.0/rv32i/ilp32/
LIBS    = -lfemtorv -lgcc
LDFLAGS = -m elf32lriscv -b elf32-littleriscv --no-relax --print-memory-usage -Tlinker.ld
AFLAGS  = -march=rv32i -mabi=ilp32
CFLAGS  =  -Ilibfemtorv/include -fno-pic -march=rv32i -mabi=ilp32 -fno-stack-protector -w -Wl,--no-relax
OBJCOPY = $(CROSS)-objcopy
all: firmware.hex
#vpath %S libfemtorv

# Cambiar TARGET para compilar otro programa:
#   make TARGET=test_hwmath
#   make TARGET=test_printf

%.bin: %.elf
#	$(OBJCOPY) -O verilog $< $@
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

firmware.elf: $(TARGET).o
	$(LD) $(LDFLAGS)  -Map firmware.map $(TARGET).o -o $@  ${LIB_DIR}  ${LIBS}
	chmod -x $@
	
firmware.hex: firmware.elf firmware.lst
	../firmware_words_src/firmware_words firmware.elf -ram 8192 -max_addr 8192  -out firmware.hex
	cp firmware.hex ../../rtl
	
firmware.lst: firmware.elf
	$(OBJDUMP) -h -S $< > $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< 
%.o: %.S
	$(AS) $(AFLAGS) -c $< -o $@
clean:
	rm -rf  *.o *.elf *.bin .*~ *~ *.map *.d *.hex *.lst
.PHONY: clean
