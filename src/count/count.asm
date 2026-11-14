; How much of the processor's time the picture takes: a loop counts as fast as it can for exactly fifty frames
; (one second on a PAL C64), timed by a CIA timer, which counts every clock cycle whether the processor runs or not.
; The VIC-II stops the processor on bad lines and for sprite fetches, so the count falls by the cycles it took.
;
; SYS 49152 counts; the result is left in $FB/$FC (low, high) for BASIC to PEEK. The loop takes 15 cycles on both
; paths (checked in VICE's monitor), so CPU cycles = count x 15, of 50 x 19,656 = 982,800 in the second.
; CIA 1 timer A underflows every 19,656 cycles (latch 19,655: one PAL frame of 312 lines x 63 cycles); timer B
; counts 50 of its underflows (loaded with 49) and its underflow interrupts the loop. The handler puts back the
; KERNAL's own timer settings (timer A $4025, its 60 Hz interrupt) and returns to BASIC.
; Our own program. Build: python build.py.

        processor 6502

lo      = $fb
hi      = $fc

        org $c000

start   sei
        tsx
        stx savesp
        lda #$7f                ; CIA 1: every interrupt source off
        sta $dc0d
        lda $dc0d               ; and any pending one cleared
        lda #<irq
        sta $0314
        lda #>irq
        sta $0315
        lda #0
        sta lo
        sta hi
        lda #49                 ; timer B: 50 underflows of timer A
        sta $dc06
        lda #0
        sta $dc07
        lda #<19655             ; timer A: one PAL frame, 19,656 cycles
        sta $dc04
        lda #>19655
        sta $dc05
        lda #$59                ; timer B: start, one-shot, load, count timer A underflows
        sta $dc0f
        lda #$82                ; interrupt on timer B only
        sta $dc0d
        lda #$11                ; timer A: start, continuous, load
        sta $dc0e
        cli

; 15 cycles a pass on either path (the branch stays in its page)
loop    inc lo                  ; 5
        bne same                ; 2, or 3 taken
        inc hi                  ; 5
        jmp loop                ; 3: 5 + 2 + 5 + 3 = 15
same    nop                     ; 2
        nop                     ; 2
        jmp loop                ; 3: 5 + 3 + 2 + 2 + 3 = 15

irq     lda $dc0d               ; acknowledge (reading clears it)
        lda #$7f
        sta $dc0d
        lda #$08                ; timer B stopped, one-shot (the KERNAL's setting)
        sta $dc0f
        lda #$25                ; the KERNAL's PAL timer A, 60 interrupts a second
        sta $dc04
        lda #$40
        sta $dc05
        lda #$11
        sta $dc0e
        lda #$81
        sta $dc0d
        lda #$31                ; the KERNAL's own interrupt handler again
        sta $0314
        lda #$ea
        sta $0315
        ldx savesp              ; drop the interrupt's frame: back to SYS's caller
        txs
        cli
        rts

savesp  .byte 0

        if >loop != >same
        echo "the loop's branch crosses a page"
        err
        endif
