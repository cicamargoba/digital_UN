set board $env(GOWIN_BOARD)
set constraints sipeed_tang_${board}.cst
set fh [open $constraints r]
set pinmap [read $fh]
close $fh
foreach port {clk rst lcd_sck lcd_dc lcd_cs lcd_rst lcd_sdi} {
    if {![regexp -line "^IO_LOC\\s+\"${port}\"\\s+" $pinmap]} {
        error "Falta asignar $port en $constraints; no se generara el bitstream."
    }
}
if {$board eq "nano_20k"} {
    set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
    set_option -use_sspi_as_gpio 1
} elseif {$board eq "primer_25k"} {
    set_device -name GW5A-25A GW5A-LV25MG121NC1/I0
    set_option -use_i2c_as_gpio 1
    set_option -use_cpu_as_gpio 1
} else {
    error "GOWIN_BOARD no valido: $board"
}
add_file sipeed_tang_${board}.cst
add_file sipeed_tang_${board}.sdc
foreach file {a_count.v comp_addr.v ctrl.v d_count.v init_mem.v memwr_cmd.v mux_3to1.v spi_tx.v v_count.v video_mem.v spi_lcd_vid_mem.v} {
    add_file -type verilog $file
}
set_option -top_module spi_lcd_vid_mem
set_option -verilog_define [list LCD_$env(LCD)]
set_option -use_mspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -rw_check_on_ram 1
run all
