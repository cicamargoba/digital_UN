.section .text
.globl start 
.globl blinker
.globl put_hello

calculator:

loopM:	
   li   sp,0x1000
   li   sp,0x1000


    la    t0, isr           # mtvec <- dirección de la rutina de interrupción
    csrw  mtvec, t0
    li    s2, 0             # contador de interrupciones
    csrsi mstatus, 8        # MIE = 1: habilita las interrupciones
	

	la   a0, number
	call putstring
	call get_number      # first number
	call bcd2bin
    add  t1, a0, zero    # mv instructions doesn't works fine

	la   a0, operator
	call putstring 
	call getchar         # Operator
	add  t2, a0, zero

    li   t4,94
    beq  t2, t4, OP3

	call putchar

	la   a0, number
	call putstring
	call get_number      # second number
	call bcd2bin
    add  t3, a0, zero    # mv instructions doesn't works fine

    li   t4, 42      # *
    bne  t2, t4, OP1
	add  a0, t1, zero
	add  a1, t3, zero
	call mult
	j    print_result
OP1:
    li   t4, 47       #  /
    bne  t2, t4, OP2
	add  a0, t1, zero
	add  a1, t3, zero
	call div
	j    print_result
OP2:
    li   t4, 43       #  +
#    bne  t2, t4, OP3
	add  a0, t1, t3
	j    print_result
OP3:
    add  a0, t1, zero
    call sqrt
print_result:
#    la   a0, result
	call bin2bcd


	j    loopM

isr:
    addi  s2, s2, 1         # una interrupción más
    mret


.section .data
number:
	.asciz "\n\rNumber: "
operator:
	.asciz "\n\rOperator "
result:
	.asciz "\n\rResult = "
