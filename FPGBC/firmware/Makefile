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
DAPLINK_REPO  ?= https://github.com/XIVN1987/DAPLink.git
DAPLINK_DIR   ?= ../DAPLink
SDK_ROOT      := $(DAPLINK_DIR)/CH32V203
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

.PHONY: all clean check daplink help program

all: $(PROGRAM_FILE)

# 1. GCC compila los fuentes locales, startup, periféricos y USB del SDK.
# 2. El linker script de CH32V203 produce build/firmware.elf.
$(TARGET): $(SOURCES) $(LINKER_SCRIPT) | $(BUILD_DIR)
	$(CC) $(ARCH_FLAGS) $(CPPFLAGS) $(CFLAGS) $(SOURCES) \
		$(LDFLAGS) $(LDLIBS) -o $@
	$(SIZE) $@

# 3. objcopy elimina la información ELF y genera la imagen binaria grabable.
$(PROGRAM_FILE): $(TARGET)
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR):
	mkdir -p $@

check:
	$(CC) $(ARCH_FLAGS) $(CPPFLAGS) $(CFLAGS) -fsyntax-only \
		$(LOCAL_SOURCES)

# Descarga el SDK/base DAPLink requerido por este firmware.
daplink:
	@if [ -f "$(LINKER_SCRIPT)" ]; then \
		echo "DAPLink disponible en $(DAPLINK_DIR)"; \
	elif [ -e "$(DAPLINK_DIR)" ]; then \
		echo "Error: $(DAPLINK_DIR) existe, pero no contiene CH32V203/link.ld."; \
		exit 1; \
	else \
		git clone "$(DAPLINK_REPO)" "$(DAPLINK_DIR)"; \
	fi

help:
	@echo "Preparación y compilación:" 
	@echo "  make daplink   Descarga $(DAPLINK_REPO) en $(DAPLINK_DIR)"
	@echo "  make           Crea $(TARGET) y después $(PROGRAM_FILE)"
	@echo "  make check     Verifica la sintaxis de los fuentes locales"
	@echo "  make program   Graba $(PROGRAM_FILE) mediante WCH-LinkE/wlink"
	@echo ""
	@echo "Conversión de firmware:" 
	@echo "  fuentes C/ASM + CH32V203 SDK -> GCC/linker -> firmware.elf"
	@echo "  firmware.elf -> objcopy -O binary -> firmware.bin"

# Programa el CH32V203 mediante WCH-LinkE usando la herramienta wlink.
program:
	@test -f "$(PROGRAM_FILE)" || { \
		echo "Error: no existe $(PROGRAM_FILE)."; \
		exit 1; \
	}
	$(WLINK) flash --address $(FLASH_ADDRESS) "$(PROGRAM_FILE)"

clean:
	rm -rf $(BUILD_DIR)
