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

PANEL_BUILD_DIR ?= build/panel
PANEL_FRAME_DELAY ?= 100000
PANEL_CFLAGS = -std=c11 -Os -march=rv32i -mabi=ilp32 -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -msmall-data-limit=0 -mno-relax -ffunction-sections -fdata-sections -Wall -Wextra

.PHONY: panel_firmware

panel_firmware:
	mkdir -p "$(PANEL_BUILD_DIR)"
	$(CC) $(PANEL_CFLAGS) -DPANEL_FRAME_DELAY=$(PANEL_FRAME_DELAY) -c panel_test.c -o "$(PANEL_BUILD_DIR)/panel_test.o"
	$(AS) -march=rv32i -mabi=ilp32 -o "$(PANEL_BUILD_DIR)/panel_start.o" panel_start.S
	$(LD) -m elf32lriscv --no-relax --gc-sections --print-memory-usage -T panel_linker.ld -Map "$(PANEL_BUILD_DIR)/panel.map" -o "$(PANEL_BUILD_DIR)/panel.elf" "$(PANEL_BUILD_DIR)/panel_start.o" "$(PANEL_BUILD_DIR)/panel_test.o"
	$(OBJDUMP) -d "$(PANEL_BUILD_DIR)/panel.elf" > "$(PANEL_BUILD_DIR)/panel.lst"
	../firmware_words_src/firmware_words "$(PANEL_BUILD_DIR)/panel.elf" -ram 4096 -max_addr 4096 -out "$(PANEL_BUILD_DIR)/firmware.hex"
	cp "$(PANEL_BUILD_DIR)/firmware.hex" ../../rtl/firmware.hex
