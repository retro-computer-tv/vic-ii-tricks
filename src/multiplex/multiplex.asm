; More than eight sprites: the VIC-II has eight, and draws each one only on the 21 lines below its Y position. Once
; a row of eight has been drawn, a raster interrupt moves all eight further down the screen, gives them new X
; positions and colours, and the chip draws them again. Here: one row of eight balls for the first 150 frames, then
; a row more every 40 frames, to six rows, 48 balls, each row swaying on its own. The bottom line of the screen
; counts the balls drawn. Our own program. SYS 49152. Build: python build.py.

        processor 6502

ROWS    = 6
TOPLINE = 255                   ; below the last row: work out the next frame, set up row 0
SPRITES = $3000
COUNTAT = $0400+24*40+19        ; the number's two digits on the bottom line

hold    = $fb
phase   = $fd
band    = $fe
nb      = $02                   ; rows drawn this frame
t0      = $03
t1      = $04
t2      = $05

        org $c000

start   sei
        lda #$7f
        sta $dc0d
        lda $dc0d
        ldx #63
.cp     lda ball,x
        sta SPRITES,x
        dex
        bpl .cp
        ldx #0                  ; the bottom line's words, in screen codes
.tx     lda label,x
        beq .txd
        sta $0400+24*40,x
        lda #1
        sta $d800+24*40,x
        inx
        bne .tx
.txd    lda #1                  ; the count's two digits white too
        sta $d800+24*40+19
        sta $d800+24*40+20
        ldx #ROWS*8-1           ; each ball's colour, once
.cl     txa
        and #7
        tay
        lda palette,y
        sta col,x
        dex
        bpl .cl
        lda #150
        sta hold
        lda #0
        sta phase
        sta $d017
        sta $d01d
        sta $d01c
        ldx #7
.sp     lda #SPRITES/64
        sta $07f8,x
        dex
        bpl .sp
        lda #1
        sta nb
        jsr calc
        jsr row0
        lda #$ff
        sta $d015
        lda #<irq
        sta $0314
        lda #>irq
        sta $0315
        lda #TOPLINE
        sta $d012
        lda #$1b
        sta $d011
        lda #1
        sta $d01a
        sta $d019
        cli
        jmp *

irq     lda $d019
        sta $d019
        lda band
        bne .row
        jsr calc                ; line 255: the next frame
        jsr row0
        jmp $ea81
.row    jsr setrow              ; just after row band-1 has been drawn: move the eight down to row band
        jmp $ea81

row0    lda #0
        sta band
        jsr setrow
        rts

; put the eight sprites at row "band", then set the next interrupt
setrow  ldy band
        ldx rowoff,y
        lda rowy,y
        sta $d001
        sta $d003
        sta $d005
        sta $d007
        sta $d009
        sta $d00b
        sta $d00d
        sta $d00f
        lda xlo,x
        sta $d000
        lda xlo+1,x
        sta $d002
        lda xlo+2,x
        sta $d004
        lda xlo+3,x
        sta $d006
        lda xlo+4,x
        sta $d008
        lda xlo+5,x
        sta $d00a
        lda xlo+6,x
        sta $d00c
        lda xlo+7,x
        sta $d00e
        lda msb,y
        sta $d010
        lda col,x
        sta $d027
        lda col+1,x
        sta $d028
        lda col+2,x
        sta $d029
        lda col+3,x
        sta $d02a
        lda col+4,x
        sta $d02b
        lda col+5,x
        sta $d02c
        lda col+6,x
        sta $d02d
        lda col+7,x
        sta $d02e
        iny
        cpy nb
        bcs .last
        sty band
        lda rowy,y
        sec
        sbc #8                  ; one line after the row above has finished (rows 30 lines apart, 21 tall)
        sta $d012
        rts
.last   lda #0
        sta band
        lda #TOPLINE
        sta $d012
        rts

; the X positions of all 48 balls for the next frame, the rows in use, the count on screen
calc    inc phase
        inc phase
        dec hold                ; rows: 1 for 150 frames, then one more every 40, to ROWS
        bne .keep
        lda #40
        sta hold
        ldx nb
        cpx #ROWS
        bcs .keep
        inx
        stx nb
.keep   ldx nb
        lda counts,x            ; the count, two screen-code digits
        sta COUNTAT
        lda counts+8,x
        sta COUNTAT+1
        ldy #0                  ; each row
.r      tya
        asl
        asl
        asl
        asl
        asl
        clc
        adc phase
        tax
        lda sway,x              ; this row's offset, 0 to 40
        clc
        adc #40                 ; the row's first ball at x 40 to 80
        sta t0
        lda #0
        sta t1                  ; X bit 8 of the ball
        sta t2                  ; the row's bit 8s, a bit a sprite
        tya
        asl
        asl
        asl
        tax
        lda #1
        sta msbbit
.b      lda t0
        sta xlo,x
        lda t1
        beq .nomsb
        lda t2
        ora msbbit
        sta t2
.nomsb  asl msbbit
        lda t0
        clc
        adc #34                 ; balls 34 pixels apart
        sta t0
        bcc .nc
        inc t1
.nc     inx
        txa
        and #7
        bne .b
        lda t2
        sta msb,y
        iny
        cpy #ROWS
        bne .r
        rts

msbbit  .byte 0
rowy    .byte 62,92,122,152,182,212
rowoff  .byte 0,8,16,24,32,40
palette .byte 1,7,3,13,10,8,4,15
counts  .byte 48,48,49,50,51,52,52,53     ; tens: ball counts 0, 8, 16, 24, 32, 40, 48, (56)
        .byte 48,56,54,52,50,48,56,54     ; units
label   .byte 19,16,18,9,20,5,19,32,15,14,32,19,3,18,5,5,14,58,0   ; SPRITES ON SCREEN:
xlo     ds ROWS*8
msb     ds ROWS
col     ds ROWS*8

        include "../gen-ball.inc"
        align 256
        include "../gen-sine-sway.inc"
