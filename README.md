# VIC-II tricks

The Commodore 64 programs from Retro Computer TV's film about the C64's graphics chip, the VIC-II: a frame that is never switched on, 48 sprites from eight, the stripes that break at every row of text, what the picture costs, the start-up screen bouncing, a colour on every line, and the wobble of a raster interrupt and how two of them stop it.

They are made for a PAL (European) C64, where every line of the picture is 63 cycles; the timed ones won't line up on an NTSC machine (65 cycles a line).

## Run them

Everything is on one disk: **run/vic-ii-tricks.d64**. It starts with a menu: type a number and press RETURN. To try another, reset the machine and load the menu again.

- **In an emulator:** VICE (vice-emu.sourceforge.io), its C64 in PAL (x64sc's default): drag the .d64 onto the window, or `x64sc -autostart run/vic-ii-tricks.d64`. Other emulators: attach the .d64 as drive 8 and type `LOAD"MENU",8` then `RUN`.
- **On a real C64:** copy the .d64 to an SD2IEC, a Pi1541 or a 1541 Ultimate (or write it to a floppy), then `LOAD"MENU",8` and `RUN`. Each program also has its own loader on the disk: `LOAD"BORDER",8` and `RUN`, for example.

| Menu | Loader | What you see | Source |
|---|---|---|---|
| 1 | BORDER | Eight balls swing down into the bottom border: for 128 pictures the border covers them, for the next 128 it never comes on | src/border/border.asm |
| 2 | BORDER OPEN | The same, with the border held open | src/border/borderopen.asm |
| 3 | 48 BALLS | One row of eight sprites, then a row more every 40 pictures, to six rows: 48 balls from the chip's eight | src/multiplex/multiplex.asm |
| 4 | STRIPES | A loop of exactly 63 cycles paints stripes: straight with the screen off, stepped at every row of text with it on | src/stripes/stripes.asm |
| 5 | COUNT | Counts as fast as it can for one second, three times: screen off, screen on, eight sprites on as well | src/count/count.asm, src/count/measure.bas |
| 6 | BOUNCE | Whatever is on the screen bounces up and down, and not one byte of screen memory changes (FLD) | src/fld/fld.asm |
| 7 | PENCILS | A picture of coloured pencils, normal and FLI in turn, switching every three seconds | src/fli/fli.asm |
| 8 | PENCILS FLI | The same picture held in FLI | src/fli/fliheld.asm |
| 9 | JITTER | A yellow bar from one raster interrupt: its left edge shivers from picture to picture | src/jitter/jitter.asm |
| 10 | STABLE | The same bar after two raster interrupts: it stands still | src/jitter/stable.asm |

run/ also holds each program's machine code on its own (`border.prg` and so on, all at $C000), and the pencil picture's data (`fli-colours.prg` at $3000, `fli-picture.prg` at $4000), for anyone loading them by hand: `LOAD"…",8,1`, then `NEW`, then `SYS 49152` (the pencils need both data files loaded first).

## How they work

Each source file starts with a description of the trick, and the comments say what each part does and why. The chip's behaviour they rely on is described in Christian Bauer's article on the VIC-II ("The MOS 6567/6569 video controller (VIC-II) and its application in the Commodore 64"), cited by section in the sources.

## Building

`python build.py` rebuilds run/ from src/. It needs [dasm](https://dasm-assembler.github.io) (download a release) and VICE's `petcat` and `c1541`, which come with VICE, on the PATH or named by the DASM, PETCAT and C1541 environment variables.

The tables the programs include (src/gen-*.inc) are made by `python src/gen.py`. The pencil picture's data (src/fli/pencils) was made by `python src/fli/convert.py <image> <out-dir> --crop=…` (it needs numpy and Pillow) from a photograph by Mahbod Akhzami on Unsplash (unsplash.com/photos/Fe3xy9C9wow), cropped to 300,0,5300,3313.

## Licence

The code is MIT licensed (LICENSE). The pencil picture is a conversion of Mahbod Akhzami's photograph, used under the Unsplash License.
