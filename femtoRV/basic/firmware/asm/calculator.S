.section .text
.globl start 
.globl blinker
.globl put_hello

calculator:

loopM:	
   li   sp,0x2000

	la   a0, number
	call putstring
	call get_number      # first number
	call bcd2bin
    add  t1, a0, zero    # 

	la   a0, operator
	call putstring 
	call getchar         # Operator
	add  t2, a0, zero
	call putchar

	la   a0, number
	call putstring
	call get_number      # second number
	call bcd2bin
    add  t3, a0, zero   

	add  a0, t1, zero
	add  a1, t3, zero
	call mult
	j    print_result
print_result:
#    la   a0, result
	call bin2bcd
	j    loopM

.section .data
number:
	.asciz "\n\rNumber: "
operator:
	.asciz "\n\rOperator "
result:
	.asciz "\n\rResult = "
