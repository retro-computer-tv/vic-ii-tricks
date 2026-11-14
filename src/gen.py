"""Tables and sprite shapes our VIC-II programs include (written as dasm source, gen-*.inc beside this file).

  python src/gen.py
"""
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent


def rows(name: str, data: list[int]) -> str:
    out = [f"{name}"]
    for i in range(0, len(data), 16):
        out.append("        .byte " + ",".join(f"${b:02x}" for b in data[i:i + 16]))
    return "\n".join(out) + "\n"


def ball() -> list[int]:
    """A filled circle 21 pixels across in a 24 x 21 sprite (63 bytes, then one spare)."""
    data = []
    for y in range(21):
        bits = 0
        for x in range(24):
            if (x - 10.5) ** 2 + (y - 10) ** 2 <= 10.4 ** 2 and x < 22:
                bits |= 1 << (23 - x)
        data += [(bits >> 16) & 255, (bits >> 8) & 255, bits & 255]
    return data + [0]


def sine(n: int, mid: float, amp: float) -> list[int]:
    return [round(mid + amp * math.sin(2 * math.pi * i / n)) for i in range(n)]


(HERE / "gen-ball.inc").write_text(rows("ball", ball()), newline="\n")
# the border program: the balls' tops swing between y 180 and 250 (a sprite y is 8 bits; the lower border starts
# at line 251, so at 250 a ball is almost all in it)
(HERE / "gen-sine-border.inc").write_text(rows("sine", sine(256, 215, 35)), newline="\n")
print("ok")
# the multiplexer: each row of balls sways by 0 to 40 pixels
(HERE / "gen-sine-sway.inc").write_text(rows("sway", sine(256, 20, 20)), newline="\n")
print("ok")
# FLD: how many lines the first text row is held back, frame by frame (0 to 96 and back, 64 frames)
(HERE / "gen-bounce.inc").write_text(rows("bounce", [round(96 * abs(math.sin(math.pi * i / 64))) for i in range(64)]), newline="\n")
print("ok")
