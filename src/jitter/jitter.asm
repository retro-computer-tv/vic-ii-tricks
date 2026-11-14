; jitter: one raster interrupt, and the wobble it brings. The screen is off, so no
; line is a bad line and every line is 63 cycles: the whole picture is the border's colour. On line 100 a raster
; interrupt draws a yellow bar 60 lines tall: on each line the border colour goes yellow, 30 cycles later back to light
; blue, the loop exactly 63 cycles a line. Where the bar starts across the line is set by when the interrupt's code
; begins, and the processor first finishes the instruction it is in the middle of: the main loop below runs
; instructions of 2 to 7 cycles, so from one picture to the next the bar lands a few cycles (8 pixels each) earlier or
; later, and shivers sideways. stable.asm draws the same bar after two interrupts, and it stands still.
; Our own program. SYS 49152. Build: python build.py

        processor 6502

LINE    = 100
LINES   = 60

        org $c000

start   sei
        lda #$7f                ; no CIA interrupts: only the raster's
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #$35                ; RAM in place of BASIC and the KERNAL, so the interrupt vector is ours
        sta $01
        lda #<irq
        sta $fffe
        lda #>irq
        sta $ffff
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #14                 ; light blue, the C64's own border colour
        sta $d020
        lda #LINE
        sta $d012
        lda #$0b                ; screen off (no bad lines), 25 rows, YSCROLL 3, raster bit 8 clear
        sta $d011
        lda #1
        sta $d01a
        sta $d019
        ldx #0
        cli
main    inc $c200,x             ; 7 cycles
        nop                     ; 2
        lda $c200,x             ; 4
        inx                     ; 2
        bit $ea                 ; 3
        jmp main                ; 3: 21 cycles a pass, so the interrupt finds it at a different point every picture

nmi     rti

irq     pha                     ; 3
        txa                     ; 2
        pha                     ; 3
        ldx #LINES              ; 2
.line   lda #7                  ; 2  yellow
        sta $d020               ; 4
        nop                     ; 30 cycles of yellow
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
        lda #14                 ; 2  light blue again
        sta $d020               ; 4
        nop                     ; 16
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        dex                     ; 2
        bne .line               ; 3: 63 cycles a line
        lda #1
        sta $d019
        pla
        tax
        pla
        rti
