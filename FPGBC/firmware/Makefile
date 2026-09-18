CROSS_COMPILE ?= riscv64-unknown-elf-
CC            := $(CROSS_COMPILE)gcc
AR            := $(CROSS_COMPILE)ar
OBJCOPY       := $(CROSS_COMPILE)objcopy
SIZE          := $(CROSS_COMPILE)size
WLINK         ?= wlink

BUILD_DIR     := build
TARGET        := $(BUILD_DIR)/firmware.elf
PROGRAM_FILE  ?= $(BUILD_DIR)/firmware.bin
FLASH_ADDRESS ?= 0x08000000
SDK_ROOT      := ../DAPLink/CH32V203
SDK_SRC       := $(SDK_ROOT)/src
LINKER_SCRIPT := $(SDK_ROOT)/link.ld

LOCAL_SOURCES := main.c gowin_sspi_flash.c platform_ch32v203.c \
		 vcom_serial.c usb_istr_minimal.c memory.c
SDK_SOURCES   := $(SDK_SRC)/Startup/core_riscv.c \
		 $(SDK_SRC)/Startup/system_ch32v20x.c \
		 $(wildcard $(SDK_SRC)/Peripheral/*.c) \
		 $(wildcard $(SDK_SRC)/USBLib/*.c) \
		 $(SDK_SRC)/USBUsr/usb_desc.c \
		 $(SDK_SRC)/USBUsr/usb_prop.c \
		 $(SDK_SRC)/USBUsr/usb_pwr.c
STARTUP       := $(SDK_SRC)/Startup/startup_ch32v20x_D6.S
SOURCES       := $(LOCAL_SOURCES) $(SDK_SOURCES) $(STARTUP)

ARCH_FLAGS    ?= -march=rv32imac_zicsr -mabi=ilp32
CPPFLAGS      ?= -I. -I$(SDK_SRC) -I$(SDK_SRC)/Startup \
		 -I$(SDK_SRC)/Peripheral -I$(SDK_SRC)/USBLib \
		 -I$(SDK_SRC)/USBUsr
CFLAGS        ?= -Os -g3 -std=gnu11 -Wall -Wextra -Wpedantic \
		 -ffreestanding -fno-builtin -ffunction-sections -fdata-sections \
		 -fno-common -msmall-data-limit=8
LDFLAGS       ?= -nostdlib -T$(LINKER_SCRIPT) -Wl,--gc-sections \
		 -Wl,-Map,$(BUILD_DIR)/firmware.map
LDLIBS        ?= -lgcc

.PHONY: all clean check program

all: $(PROGRAM_FILE)

$(TARGET): $(SOURCES) $(LINKER_SCRIPT) | $(BUILD_DIR)
	$(CC) $(ARCH_FLAGS) $(CPPFLAGS) $(CFLAGS) $(SOURCES) \
		$(LDFLAGS) $(LDLIBS) -o $@
	$(SIZE) $@

$(PROGRAM_FILE): $(TARGET)
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR):
	mkdir -p $@

check:
	$(CC) $(ARCH_FLAGS) $(CPPFLAGS) $(CFLAGS) -fsyntax-only \
		$(LOCAL_SOURCES)

# Programa el CH32V203 mediante WCH-LinkE usando la herramienta wlink.
program:
	@test -f "$(PROGRAM_FILE)" || { \
		echo "Error: no existe $(PROGRAM_FILE)."; \
		exit 1; \
	}
	$(WLINK) flash --address $(FLASH_ADDRESS) "$(PROGRAM_FILE)"

clean:
	rm -rf $(BUILD_DIR)
