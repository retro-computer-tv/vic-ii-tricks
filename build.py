"""Rebuild run/ from src/: every program assembled with dasm, the BASIC loaders tokenised with VICE's petcat, and
the disk of them all written with VICE's c1541.

  python build.py

Needs dasm (https://dasm-assembler.github.io) and VICE's petcat and c1541 (https://vice-emu.sourceforge.io) on the
PATH, or named by DASM, PETCAT and C1541. The tables the programs include (src/gen-*.inc) are made by src/gen.py
and are already here; the pencil picture's data (src/fli/pencils) by src/fli/convert.py.
"""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC, RUN = HERE / "src", HERE / "run"
DASM = os.environ.get("DASM") or shutil.which("dasm") or "dasm"
PETCAT = os.environ.get("PETCAT") or shutil.which("petcat") or "petcat"
C1541 = os.environ.get("C1541") or shutil.which("c1541") or "c1541"

# (source, run file): every program, assembled to load where it runs ($C000, SYS 49152)
PROGRAMS = [
    ("border/border.asm", "border.prg"),
    ("border/borderopen.asm", "borderopen.prg"),
    ("multiplex/multiplex.asm", "multiplex.prg"),
    ("stripes/stripes.asm", "stripes.prg"),
    ("count/count.asm", "count.prg"),
    ("fld/fld.asm", "fld.prg"),
    ("fli/fli.asm", "fli.prg"),
    ("fli/fliheld.asm", "fliheld.prg"),
    ("jitter/jitter.asm", "jitter.prg"),
    ("jitter/stable.asm", "stable.prg"),
]
# the pencil picture both FLI programs show: colour memory's values at $3000, the screens and bitmaps at $4000
DATA = [("fli/pencils/colram.prg", "fli-colours.prg"), ("fli/pencils/data.prg", "fli-picture.prg")]

# The disk: a menu first (what an emulator starts), then a loader for each program, which loads its machine code
# (<name>.bin, and the picture) with LOAD"…",8,1 and starts it. L counts the loads: a LOAD inside a program runs it again from
# the top with its variables kept.
LOAD = '{n} if l={k} then l={k1}:load"{f}",8,1\n'
LOADERS = {
    "border": ("border", 'print"{clr}":sys 49152\n'),
    "border open": ("borderopen", 'print"{clr}":sys 49152\n'),
    "48 balls": ("multiplex", 'print"{clr}":sys 49152\n'),
    "stripes": ("stripes", 'print"{clr}"\npoke 53265,27:sys 49152\npoke 53265,11:sys 49152:poke 53265,27\n'
                           'poke 53265,27:sys 49152\npoke 53280,14:poke 53281,6\n'),
    "count": ("count", 'print"{clr}{wht}counting for one second..."\n'
                       'poke 53265,11:sys 49152:b=peek(251)+256*peek(252):poke 53265,27\n'
                       'poke 53265,27:sys 49152:a=peek(251)+256*peek(252)\n'
                       'for i=832 to 894:poke i,255:next\n'
                       'for i=0 to 7:poke 2040+i,13:poke 53248+2*i,40+28*i:poke 53249+2*i,150:next\n'
                       'poke 53269,255:sys 49152:c=peek(251)+256*peek(252)\n'
                       'print:print "screen off     ";b\nprint "screen on      ";a\nprint "8 sprites too  ";c\n'),
    "bounce": ("fld", 'sys 49152\n'),
    "pencils": ("fli", 'sys 49152\n'),
    "pencils fli": ("fliheld", 'sys 49152\n'),
    "jitter": ("jitter", 'sys 49152\n'),
    "stable": ("stable", 'sys 49152\n'),
}
MENU = [
    ("border", "the frame shut, then open"),
    ("border open", "the frame held open"),
    ("48 balls", "48 sprites from eight"),
    ("stripes", "the stripes and bad lines"),
    ("count", "what the picture costs"),
    ("bounce", "the screen bouncing"),
    ("pencils", "normal, then fli, in turn"),
    ("pencils fli", "the fli picture held"),
    ("jitter", "one raster interrupt"),
    ("stable", "two raster interrupts"),
]


def loader(name: str) -> str:
    base, body = LOADERS[name]
    files = (["fli-colours", "fli-picture"] if base.startswith("fli") else []) + [base]
    out = "".join(LOAD.format(n=10 * (k + 1), k=k, k1=k + 1, f=f"{f}.bin") for k, f in enumerate(files))
    n = 10 * (len(files) + 1)
    for line in body.splitlines():
        out += f"{n} {line}\n"
        n += 10
    return out


def menu() -> str:
    out = '10 print"{clr}{wht}vic-ii tricks, retro computer tv":print\n'
    for k, (name, what) in enumerate(MENU, 1):
        out += f'{10 + 10 * k} print"{k:2d} {name}: {what}"\n'
    n = 20 + 10 * len(MENU)
    out += f'{n} print:input"which";k:if k<1 or k>{len(MENU)} then {n}\n'
    for k, (name, _) in enumerate(MENU, 1):
        out += f'{n + 10 * k} if k={k} then load"{name}",8\n'
    return out


def run(*args, cwd=None):
    r = subprocess.run([str(a) for a in args], cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"{' '.join(map(str, args))}: failed\n{r.stdout}\n{r.stderr}")


def main() -> None:
    RUN.mkdir(exist_ok=True)
    for src, out in PROGRAMS:
        s = SRC / src
        run(DASM, s.name, "-f1", f"-o{(RUN / out).resolve()}", cwd=s.parent)
    for src, out in DATA:
        shutil.copyfile(SRC / src, RUN / out)
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        prgs = []
        for name in ["menu", *LOADERS]:
            (t / "x.bas").write_text(menu() if name == "menu" else loader(name), encoding="ascii")
            run(PETCAT, "-w2", "-o", t / f"{len(prgs)}.prg", "--", t / "x.bas")
            prgs.append((t / f"{len(prgs)}.prg", name))
        disk = RUN / "vic-ii-tricks.d64"
        disk.unlink(missing_ok=True)
        cmd = [C1541, "-format", "vic-ii tricks,rc", "d64", disk]
        for p, name in prgs:
            cmd += ["-write", p, name]
        for _, out in PROGRAMS + DATA:
            cmd += ["-write", RUN / out, f"{out[:-4]}.bin"]
        run(*cmd)
    for f in sorted(RUN.iterdir()):
        print(f"run/{f.name}: {f.stat().st_size} bytes")


if __name__ == "__main__":
    main()
