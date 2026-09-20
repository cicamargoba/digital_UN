# Script TCL generado automáticamente desde Makefile
# Fecha: Mon Nov 24 09:28:34 PM -05 2025

# Configurar dispositivo
set_device -name GW5A-25A GW5A-LV25MG121NC1/I0

add_file sipeed_tang_primer_25k.cst
add_file sipeed_tang_primer_25k.sdc
# Agregar archivos fuente
add_file -type verilog count.v
add_file -type verilog ctrl_lp4k.v
add_file -type verilog pwm_led_panel.v
add_file -type verilog memory.v
add_file -type verilog comp.v
add_file -type verilog lsr_led.v
add_file -type verilog mux_led.v

# Configurar opciones del proyecto
set_option -use_mspi_as_gpio 1
set_option -use_i2c_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -rw_check_on_ram 1
run all
