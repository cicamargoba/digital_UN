#################################################################################

# FemtoRV32 support library

# exit function: display exit code
# on LEDS, or spinning wheel if exit
# code is zero.	
.global exit
.type  exit, @function
exit:   
	
.global abort
.type   abort, @function
abort:	ebreak
	ret
