; Moving the whole screen without moving memory (FLD, "flexible line distance"). The VIC-II starts each text row on a
; bad line: a line where the low three bits of the raster line equal the vertical scroll (YSCROLL, bits 0-2 of
; $D011). At line 40, above the first row, this program adds one to YSCROLL at the start of every line for N lines,
; so the two never match and the first row's bad line is put off; when it stops, the row starts N lines lower and
; the rest follow. N rises and falls with each frame, so the start-up screen bounces. Rows pushed below line 247 are
; not drawn (no bad lines there). An interrupt at line 250 sets YSCROLL back for the next frame. Nothing in screen
; memory moves. (Christian Bauer, section 3.14.2.) Our own program. SYS 49152.

        processor 6502

TOPLINE = 40
BOTLINE = 250
phase   = $fb

        org $c000

start   sei
        lda #$7f
        sta $dc0d
        lda $dc0d
        lda #0
        sta $3fff               ; between rows the chip shows this byte's pattern: nothing
        sta phase
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
        lda $d012
        cmp #128
        bcs bottom
        inc phase
        lda phase
        and #63
        tax
        ldy bounce,x
        beq .done
.line   lda $d012               ; wait for the next raster line
.wait   cmp $d012
        beq .wait
        lda $d011               ; YSCROLL one more, so it never equals the raster's low bits
        clc
        adc #1
        and #7
        ora #$18
        sta $d011
        dey
        bne .line
.done   lda #BOTLINE
        sta $d012
        jmp $ea81
bottom  lda #$1b                ; YSCROLL 3 again
        sta $d011
        lda #TOPLINE
        sta $d012
        jmp $ea81

        include "../gen-bounce.inc"
