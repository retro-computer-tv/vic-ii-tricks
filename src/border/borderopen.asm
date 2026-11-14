; borderopen: border.asm with the border opened on every frame, for the film's held-open shots.
; Opening the top and bottom border. Eight balls (sprites) swing on a wave from the bottom of the text area down
; into the lower border. For 128 frames the border is left alone and covers them; for the next 128 it is opened,
; and so on. Opening it: a raster interrupt at line 249 switches the screen from 25 rows to 24 (RSEL off). The VIC-II
; switches on the lower border when the raster reaches line 251 with 25 rows, or line 247 with 24 rows, and only on
; that exact line; at 249, with 24 rows set, line 247 has already gone, and line 251 is no longer the one it waits
; for, so the border never comes on. A second interrupt, at line 20, sets 25 rows again for the next frame.
; (Christian Bauer, the VIC-II's border unit and "Hyperscreen", sections 3.9 and 3.14.1.)
; Our own program. SYS 49152. Build: python build.py.

        processor 6502

TOPLINE = 20
BOTLINE = 249
SPRITES = $3000                 ; block 192 of the VIC-II's first 16K
frame   = $fb
phase   = $fc

        org $c000

start   sei
        lda #$7f                ; no CIA interrupts: only the VIC-II's raster interrupt from now on
        sta $dc0d
        lda $dc0d
        ldx #63
.cp     lda ball,x
        sta SPRITES,x
        dex
        bpl .cp
        lda #0
        sta $3fff               ; what the chip shows where it has no characters: nothing
        sta $d010
        sta $d017
        sta $d01d
        sta $d01c
        sta frame
        sta phase
        ldx #7
.sp     lda #SPRITES/64
        sta $07f8,x
        lda colours,x
        sta $d027,x
        dex
        bpl .sp
        ldx #0
        ldy #0
.xs     lda xpos,y
        sta $d000,x
        inx
        inx
        iny
        cpy #8
        bne .xs
        jsr move
        lda #$ff
        sta $d015
        lda #<irq
        sta $0314
        lda #>irq
        sta $0315
        lda #TOPLINE
        sta $d012
        lda #$1b                ; 25 rows, screen on, raster bit 8 clear
        sta $d011
        lda #1
        sta $d01a
        sta $d019
        cli
        jmp *

irq     lda $d019
        sta $d019               ; acknowledge the raster interrupt
        lda $d012
        cmp #128
        bcs bottom
        lda #$1b                ; line 20: 25 rows again
        sta $d011
        lda #BOTLINE
        sta $d012
        jsr move
        jmp $ea81               ; the KERNAL's own exit: registers back, RTI
bottom  lda frame
        nop                     ; held: open on every frame (no closed half)
        nop
        lda #$13                ; frames 128-255: 24 rows, now, at line 249
        sta $d011
.closed lda #TOPLINE
        sta $d012
        jmp $ea81

move    inc frame
        inc phase
        inc phase
        ldx #0
        ldy #0
.my     tya
        asl
        asl
        asl
        asl
        clc
        adc phase
        stx $02
        tax
        lda sine,x
        ldx $02
        sta $d001,x
        inx
        inx
        iny
        cpy #8
        bne .my
        rts

xpos    .byte 40,70,100,130,160,190,220,250
colours .byte 1,7,3,13,10,8,4,15

        include "../gen-ball.inc"
        align 256
        include "../gen-sine-border.inc"
