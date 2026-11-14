; Shared by our programs: run the caller's loop for FRAMES PAL frames, then return to BASIC.
; "jsr timed_start" (with the stack as SYS left it, plus this call) arms CIA 1: timer A underflows every 19,656
; cycles (one PAL frame), timer B counts FRAMES of them and interrupts. The handler puts back the KERNAL's own
; timer and interrupt handler and returns to the SYS's caller. The caller's loop never polls anything, so its
; timing is the loop's alone. Interrupts reach us through the KERNAL's vector at $0314.

timed_start
        sei
        tsx
        inx                     ; the stack as it was before this jsr
        inx
        stx timed_sp
        lda #$7f
        sta $dc0d
        lda $dc0d
        lda #<timed_irq
        sta $0314
        lda #>timed_irq
        sta $0315
        lda #<(FRAMES-1)
        sta $dc06
        lda #>(FRAMES-1)
        sta $dc07
        lda #<19655
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
        rts

timed_irq
        lda $dc0d
        lda #$7f
        sta $dc0d
        lda #$08
        sta $dc0f
        lda #$25                ; the KERNAL's PAL timer A
        sta $dc04
        lda #$40
        sta $dc05
        lda #$11
        sta $dc0e
        lda #$81
        sta $dc0d
        lda #$31
        sta $0314
        lda #$ea
        sta $0315
        ldx timed_sp
        txs
        cli
        rts

timed_sp .byte 0
