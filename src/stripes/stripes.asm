; The stolen cycles made visible: the processor paints the border and the background two colours, as fast as it
; can, for FRAMES frames. Each colour lasts as long as the instructions between the writes, so the picture shows
; the processor's own time: where the VIC-II stops it for a bad line (about 43 cycles, at the first pixel line of
; each text row), one colour stays on for a long bar. With the screen switched off (BASIC clears DEN first) there
; are no bad lines and no bars. The pattern is the same every frame: after each bad line the processor starts
; again at the same cycle. Our own program. SYS 49152. Build: python build.py.

        processor 6502

FRAMES  = 150
COL1    = 6                     ; blue
COL2    = 14                    ; light blue

        org $c000

start   jsr timed_start
        ldx #COL1
        ldy #COL2
; One pass is exactly one raster line (63 cycles on a PAL machine), so each colour change falls at the same place
; on every line: straight vertical stripes, four to a line, 16 cycles (128 pixels) apart. On a bad line the
; processor is stopped from about cycle 12 to cycle 54, the changes due then wait, and one colour runs on.
loop    stx $d020               ; 4
        stx $d021               ; 4
        nop                     ; 2
        nop                     ; 2
        bit $ea                 ; 3
        sty $d020               ; 4
        sty $d021               ; 4
        nop                     ; 2
        nop                     ; 2
        bit $ea                 ; 3
        stx $d020               ; 4
        stx $d021               ; 4
        nop                     ; 2
        nop                     ; 2
        bit $ea                 ; 3
        sty $d020               ; 4
        sty $d021               ; 4
        nop                     ; 2
        nop                     ; 2
        bit $ea                 ; 3
        jmp loop                ; 3: 4 x (8 + 7) + 3 = 63 cycles a pass, one PAL raster line

        include "../timed.inc"
