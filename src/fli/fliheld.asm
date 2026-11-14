; fliheld: fli.asm with the picture held in FLI (no switching), for the film's closing hold.
; One picture, shown two ways, switching every 150 frames: as the VIC-II draws a multicolour bitmap normally (each
; 4 x 8 cell's colours read once, on its bad line), and with FLI, where the program makes every line from 52 to 247
; a bad line, so the chip reads colours again for every line, each time from another of eight screen matrices.
; How (Christian Bauer, section 3.14.3): on each line, at cycle 14, YSCROLL is set to that line's low three bits,
; which starts a bad line there; just before, $D018 points the chip at that line's matrix. The bad line stops the
; processor until cycle 55, so each line's code (23 cycles) starts at the same place: only the first line has to be
; placed exactly, which a second raster interrupt does (it can only interrupt a NOP, so it starts 0 or 1 cycle late,
; and a read of the raster line at the line's end evens that out).
; Memory: the FLI screens at $4000 (eight, 1K apart) and its bitmap at $6000 (VIC bank 1); the normal screen at
; $8000 and bitmap at $A000 (bank 2); colour RAM's values at $3000, shared. Our own program. SYS 49152.

        processor 6502

IRQLINE = 44
; timing, set by measuring in VICE's monitor: the evening-out read straddles the end of line 45, and the
; first block's write lands at cycle 14 of line 52
STABLE  = 8
SNOPS   = 0
SBIT    = 0
DELAY   = 52
DNOPS   = 0
DBIT    = 1
mode    = $fb                   ; 0 normal, 1 FLI
tick    = $fc

        org $c000

start   sei
        lda #$7f
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #$35                ; RAM in place of BASIC and the KERNAL; I/O stays
        sta $01
        ldx #0
.cr     lda $3000,x             ; colour RAM, 1,000 values
        sta $d800,x
        lda $3100,x
        sta $d900,x
        lda $3200,x
        sta $da00,x
        lda $3300,x
        sta $db00,x
        inx
        bne .cr
        lda #0
        sta $d020
        sta $d021
        sta $d015
        sta tick
        lda #1                  ; held: FLI from the start, never switched back
        sta mode
        lda #$18                ; multicolour, 40 columns
        sta $d016
        lda #<irq1
        sta $fffe
        lda #>irq1
        sta $ffff
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #IRQLINE
        sta $d012
        lda #$3b                ; bitmap, screen on, 25 rows, YSCROLL 3
        sta $d011
        lda #1
        sta $d01a
        sta $d019
        cli
        jmp *

nmi     rti

irq1    pha
        txa
        pha
        tya
        pha
        lda #$08                ; screen at the bank's start, bitmap 8K in
        sta $d018
        lda mode
        bne .fli
        lda $dd00               ; normal: VIC bank 2, $8000-$BFFF
        and #$fc
        ora #$01
        sta $dd00
        lda #1
        sta $d019
        jsr frame
        pla
        tay
        pla
        tax
        pla
        rti
.fli    lda $dd00               ; FLI: VIC bank 1, $4000-$7FFF
        and #$fc
        ora #$02
        sta $dd00
        lda #<irq2
        sta $fffe
        lda #>irq2
        sta $ffff
        inc $d012
        lda #1
        sta $d019
        tsx
        cli
        nop                     ; the second interrupt arrives during these
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop

irq2    txs                     ; back to the first interrupt's stack; its RTI ends this
        ldx #STABLE
.s      dex
        bne .s
        IF SNOPS > 0
        REPEAT SNOPS
        nop
        REPEND
        ENDIF
        IF SBIT
        bit $ea
        ENDIF
        lda $d012
        cmp $d012
        beq .even               ; still the same line: one cycle more
stable
.even   ldx #DELAY              ; from here the timing is exact
.d      dex
        bne .d
        IF DNOPS > 0
        REPEAT DNOPS
        nop
        REPEND
        ENDIF
        IF DBIT
        bit $ea
        ENDIF
; line 51 is an ordinary bad line (YSCROLL 3): it stops us at the first block until cycle 55; then one block a line
L       SET 52
first
        REPEAT 196
        lda #((L-51)&7)*16+8    ; this line's matrix
        sta $d018
        lda #$38+(L&7)          ; bitmap, screen on, 25 rows, YSCROLL = the line's low bits
        nop
        nop
        nop
        nop
        bit $ea
blk     SET .
        sta $d011               ; written at cycle 14: a bad line starts here
L       SET L+1
        REPEND
        lda #$3b                ; lines 248-250 can't be bad lines: the chip keeps line 247's colours
        sta $d011
        lda #<irq1
        sta $fffe
        lda #>irq1
        sta $ffff
        lda #IRQLINE
        sta $d012
        lda #1
        sta $d019
        jsr frame
        pla
        tay
        pla
        tax
        pla
        rti

frame   rts                     ; held: no switching

