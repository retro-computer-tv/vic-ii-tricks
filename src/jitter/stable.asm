; stable: the same yellow bar as jitter.asm, drawn after two raster interrupts, as our FLI program starts (fli.asm,
; after Christian Bauer). The first interrupt, on line 99, sets up a second for line 100 and waits in two-cycle NOPs, so
; the second can only be one cycle late; reading the raster line just as it changes evens out that cycle. From there
; every cycle is counted, and the bar starts at the same point of every line of every picture: it stands still, while
; the main loop is the same mix of 2- to 7-cycle instructions that makes jitter.asm's bar shiver.
; Our own program. SYS 49152. Build: python build.py

        processor 6502

LINE    = 99
LINES   = 60
STABLE  = 8                     ; with SBIT: the evening-out read lands on cycle 62 of line 100 when the second interrupt
                                ; is on time (cycle 9), on line 101 when it is a cycle late (measured in VICE's monitor)
PRE     = 8                     ; NOPs before the bar, so it starts across the line where jitter.asm's does
SNOPS   = 0                     ; and SBIT: a cycle's fine tuning of the evening-out read, as fli.asm's
SBIT    = 1

        org $c000

start   sei
        lda #$7f
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #$35
        sta $01
        lda #<irq1
        sta $fffe
        lda #>irq1
        sta $ffff
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #14
        sta $d020
        lda #LINE
        sta $d012
        lda #$0b                ; screen off: no bad lines
        sta $d011
        lda #1
        sta $d01a
        sta $d019
        ldx #0
        cli
main    inc $c200,x             ; the same loop as jitter.asm's
        nop
        lda $c200,x
        inx
        bit $ea
        jmp main

nmi     rti

irq1    pha
        txa
        pha
        lda #<irq2
        sta $fffe
        lda #>irq2
        sta $ffff
        inc $d012               ; the next line
        lda #1
        sta $d019
        tsx
        cli
        nop                     ; the second interrupt arrives during these: 0 or 1 cycle late
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
.even
        REPEAT PRE
        nop
        REPEND
        ldx #LINES
.line   lda #7                  ; from here every cycle is counted
        sta $d020
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
        lda #14
        sta $d020
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        dex
        bne .line
        lda #<irq1
        sta $fffe
        lda #>irq1
        sta $ffff
        lda #LINE
        sta $d012
        lda #1
        sta $d019
        pla
        tax
        pla
        rti
