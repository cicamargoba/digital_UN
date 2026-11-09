.option norvc
.equ PANEL_BASE,  0x00470000
.equ TEXT_ADDR,   0x04
.equ TEXT_DATA,   0x08
.equ SPRITE_ADDR, 0x0C
.equ SPRITE_DATA, 0x10
.equ TEXT_WE,     0x14
.equ SPRITE_WE,   0x18
.ifndef PANEL_FRAME_DELAY
.equ PANEL_FRAME_DELAY, 100000
.endif

.section .text
.global _start
_start:
    li sp, 0x1000
    li sp, 0x1000
    li s0, PANEL_BASE
    sw zero, TEXT_WE(s0)
    sw zero, SPRITE_WE(s0)
    li s1, 0
clear_text:
    mv a0, s1
    li a1, 0x20
    jal ra, write_text
    addi s1, s1, 1
    li t0, 64
    blt s1, t0, clear_text
    li s1, 0
clear_sprites:
    sw s1, SPRITE_ADDR(s0)
    sw zero, SPRITE_DATA(s0)
    jal ra, commit_sprite
    addi s1, s1, 1
    li t0, 8
    blt s1, t0, clear_sprites
    li a0, 10
    li a1, 0x07C8
    jal ra, write_text
    li a0, 11
    li a1, 0x07CF
    jal ra, write_text
    li a0, 12
    li a1, 0x07CC
    jal ra, write_text
    li a0, 13
    li a1, 0x07C1
    jal ra, write_text
    li t0, 1
    sw t0, SPRITE_ADDR(s0)
    li t0, 0x0344181C
    sw t0, SPRITE_DATA(s0)
    jal ra, commit_sprite
    li t0, 2
    sw t0, SPRITE_ADDR(s0)
    li t0, 0x02C1381C
    sw t0, SPRITE_DATA(s0)
    jal ra, commit_sprite
    li s1, 0
    li s2, 1
animate:
    sw zero, SPRITE_ADDR(s0)
    li t0, 0x03C02800
    or t0, t0, s1
    sw t0, SPRITE_DATA(s0)
    jal ra, commit_sprite
    li t0, PANEL_FRAME_DELAY
frame_wait:
    addi t0, t0, -1
    bnez t0, frame_wait
    add s1, s1, s2
    li t0, 56
    beq s1, t0, move_left
    beqz s1, move_right
    j animate
move_left:
    li s2, -1
    j animate
move_right:
    li s2, 1
    j animate

write_text:
    sw zero, TEXT_WE(s0)
    sw a0, TEXT_ADDR(s0)
    sw a1, TEXT_DATA(s0)
    li t0, 1
    sw t0, TEXT_WE(s0)
    li t0, 16
text_wait:
    addi t0, t0, -1
    bnez t0, text_wait
    sw zero, TEXT_WE(s0)
    ret

commit_sprite:
    li t0, 1
    sw t0, SPRITE_WE(s0)
    li t0, 16
sprite_wait:
    addi t0, t0, -1
    bnez t0, sprite_wait
    sw zero, SPRITE_WE(s0)
    ret
