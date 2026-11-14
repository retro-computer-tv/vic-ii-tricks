"""One picture, two ways, for the C64's multicolour bitmap (160 x 200, each pixel two wide): as the chip draws it
normally, and with FLI. Writes the data our display program shows (fli.asm), and previews in the C64's palette.

  python src/fli/convert.py <image> <out-dir> [--crop=x,y,w,h]

The chip's rules, as the program obeys them:
- Each pixel is one of four choices: 00 the background colour (one for the whole screen, black here), 01 and 10 the
  two colours in the screen-memory byte for its cell, 11 the cell's colour in colour RAM.
- Normal: a cell is 4 x 8 pixels, so its eight lines share one screen byte: four colours a cell.
- FLI: a new bad line every line reads a new screen byte for every line (from eight screen matrices, one per line
  of the cell), so each 4 x 1 strip has its own pair; colour RAM can't be switched, so the cell's third colour stays.
- Both versions use the same colour RAM (chosen for the normal picture), so the comparison changes only what FLI
  changes, and the program can switch between them without touching colour RAM.
- Bad lines can't be made below raster line 247, so the bottom row's last four lines share line 4's pair.
- The leftmost three cells of every row show stray colours in FLI (the chip reads $FF there, Bauer 3.14.3), so both
  versions keep them background: a black strip 24 pixels wide on the left.
How: the picture (colour and contrast lifted a little, as C64 artists' conversions do) is first drawn with no rule at
all: each pixel one of the 16 colours, two colours mixed in a 4 x 4 ordered pattern where the true colour lies
between them (the "target"). Then each rule keeps as many of the target's pixels as it can: normal chooses each
cell's three colours, FLI each line's two (with the same colour RAM); a pixel whose colour isn't allowed takes the
nearest allowed one. "kept" is the share of pixels shown in the target's colour.
"""
import argparse
import itertools
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

# the 16 colours as VICE 3.10's x64sc draws them with its default settings (read with the monitor's "palette get"),
# the colours our recordings show
PAL = np.array([
    (0, 0, 0), (255, 255, 255), (171, 60, 101), (135, 240, 203), (178, 61, 239), (94, 214, 56), (58, 49, 255),
    (255, 255, 59), (183, 100, 24), (129, 76, 0), (234, 121, 163), (98, 98, 98), (148, 148, 148), (178, 255, 141),
    (129, 120, 255), (205, 205, 205)], dtype=np.float64)
BG = 0
LEFT = 3  # cells forced to background on the left


def load(path: str, crop: str | None, rotate: int = 0) -> np.ndarray:
    im = Image.open(path).convert("RGB")
    if rotate:
        im = im.rotate(rotate, expand=True)
    if crop:
        x, y, w, h = (int(v) for v in crop.split(","))
        im = im.crop((x, y, x + w, y + h))
    im = im.resize((160, 200), Image.LANCZOS)  # each C64 multicolour pixel is two wide: 160 x 200 fills 320 x 200
    im = ImageEnhance.Color(im).enhance(1.3)
    im = ImageEnhance.Contrast(im).enhance(1.1)
    return np.asarray(im, dtype=np.float64)


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16 + 1 / 32


def target(img: np.ndarray) -> np.ndarray:
    """Each pixel one of the 16 colours: the pair whose mixture comes closest, picked by a 4 x 4 ordered pattern."""
    best_e = np.full(img.shape[:2], np.inf)
    out = np.zeros(img.shape[:2], dtype=np.uint8)
    thr = BAYER[np.arange(200)[:, None] % 4, np.arange(160)[None, :] % 4]
    for a in range(16):
        for b in range(a, 16):
            ca, cb = PAL[a], PAL[b]
            v = cb - ca
            vv = float((v * v).sum())
            t = np.zeros(img.shape[:2]) if vv == 0 else np.clip(((img - ca) * v).sum(-1) / vv, 0, 1)
            t = np.round(t * 4) / 4  # mixtures the pattern can draw: 0, 1/4, 1/2, 3/4, 1
            mix = ca + t[..., None] * v
            e = ((img - mix) ** 2).sum(-1) + 0.1 * vv * t * (1 - t)  # far-apart pairs mixed look grainy: a small cost
            pick = np.where(t > thr, b, a)
            m = e < best_e
            best_e[m] = e[m]
            out[m] = pick[m]
    return out


def dist(px: np.ndarray) -> np.ndarray:
    """Squared distance of each pixel to each of the 16 colours: (..., 16)."""
    return ((px[..., None, :] - PAL) ** 2).sum(-1)


def convert(img: np.ndarray):
    tgt = target(img)
    d = dist(img)  # 200 x 160 x 16: the true colour's distance to each, for the pixels a rule can't keep
    pairs = list(itertools.combinations_with_replacement(range(16), 2))
    triples = list(itertools.combinations(range(1, 16), 3))
    normal = np.zeros((200, 160), dtype=np.uint8)
    fli = np.zeros((200, 160), dtype=np.uint8)
    colram = np.zeros((25, 40), dtype=np.uint8)
    scr_n = np.zeros((25, 40), dtype=np.uint8)
    scr_f = np.zeros((8, 25, 40), dtype=np.uint8)
    bits_n = np.zeros((200, 160), dtype=np.uint8)
    bits_f = np.zeros((200, 160), dtype=np.uint8)
    tgt[:, :LEFT * 4] = BG

    def fit(t: np.ndarray, dd: np.ndarray, cols: list[int]) -> tuple[float, np.ndarray]:
        """Pixels kept (more is better), then the error of the rest: as one score, lower better."""
        cols_a = np.array(cols)
        keep = np.isin(t, cols_a)
        pick = dd[..., cols_a].argmin(-1)
        tpos = (t[..., None] == cols_a).argmax(-1)
        pick = np.where(keep, tpos, pick)
        miss = (~keep).sum()
        return miss * 1e7 + float(np.take_along_axis(dd, cols_a[pick][..., None], -1).sum()), pick

    for cy in range(25):
        for cx in range(40):
            ys, xs = slice(cy * 8, cy * 8 + 8), slice(cx * 4, cx * 4 + 4)
            if cx < LEFT:
                continue
            ct, cd = tgt[ys, xs], d[ys, xs]
            present = [c for c in np.unique(ct) if c != BG]
            best = None
            for t3 in triples:
                if len(present) <= 3 and not set(present) <= set(t3):
                    continue
                sc, pk = fit(ct, cd, [BG, *t3])
                if best is None or sc < best[0]:
                    best = (sc, t3, pk)
            _, (a1, b1, c1), pk = best
            cols = np.array([BG, a1, b1, c1])
            normal[ys, xs] = cols[pk]
            bits_n[ys, xs] = pk
            scr_n[cy, cx] = (a1 << 4) | b1
            colram[cy, cx] = c1
            groups = [[ly] for ly in range(8)] if cy < 24 else [[0], [1], [2], [3], [4, 5, 6, 7]]
            for grp in groups:
                ly, n = grp[0], len(grp)
                lt, ld = ct[ly:ly + n], cd[ly:ly + n]
                bl = None
                for p, q in pairs:
                    sc, pk = fit(lt, ld, [BG, p, q, c1])
                    if bl is None or sc < bl[0]:
                        bl = (sc, p, q, pk)
                _, p, q, pk = bl
                lc = np.array([BG, p, q, c1])
                fli[cy * 8 + ly:cy * 8 + ly + n, xs] = lc[pk]
                bits_f[cy * 8 + ly:cy * 8 + ly + n, xs] = pk
                for g in grp:
                    scr_f[g, cy, cx] = (p << 4) | q
    return tgt, normal, fli, colram, scr_n, scr_f, bits_n, bits_f


def pack(bits: np.ndarray) -> bytes:
    out = bytearray(8000)
    for cy in range(25):
        for cx in range(40):
            for ly in range(8):
                row = bits[cy * 8 + ly, cx * 4:cx * 4 + 4]
                out[(cy * 40 + cx) * 8 + ly] = (row[0] << 6) | (row[1] << 4) | (row[2] << 2) | row[3]
    return bytes(out)


def preview(idx: np.ndarray, path: Path) -> None:
    rgb = PAL[idx].astype(np.uint8)
    Image.fromarray(rgb).resize((640, 400), Image.NEAREST).save(path)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("out")
    ap.add_argument("--crop")
    ap.add_argument("--rotate", type=int, default=0, help="degrees anticlockwise, before the crop")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    img = load(a.image, a.crop, a.rotate)
    tgt, normal, fli, colram, scr_n, scr_f, bits_n, bits_f = convert(img)
    area = np.zeros((200, 160), dtype=bool)
    area[:, LEFT * 4:] = True
    err = {k: {"kept": float((v == tgt)[area].mean()), "rgb": float(np.sqrt(((PAL[v] - img) ** 2).sum(-1))[area].mean())}
           for k, v in (("target", tgt), ("normal", normal), ("fli", fli))}
    # colours used per cell, averaged over the cells the picture fills
    used = {}
    for k, v in (("target", tgt), ("normal", normal), ("fli", fli)):
        counts = [len(np.unique(v[cy * 8:cy * 8 + 8, cx * 4:cx * 4 + 4])) for cy in range(25) for cx in range(LEFT, 40)]
        used[k] = {"mean": float(np.mean(counts)), "max": int(max(counts))}
    # the files the display program loads: $4000 the eight FLI screens (1K apart), $6000 the FLI bitmap,
    # $8000 the normal screen, $A000 the normal bitmap; colour RAM's 1,000 values in colram.prg at $3000
    fli_mem = bytearray(0x4000)
    for k in range(8):
        fli_mem[k * 0x400:k * 0x400 + 1000] = scr_f[k].tobytes()
    fli_mem[0x2000:0x2000 + 8000] = pack(bits_f)
    nrm_mem = bytearray(0x4000)
    nrm_mem[0:1000] = scr_n.tobytes()
    nrm_mem[0x2000:0x2000 + 8000] = pack(bits_n)
    (out / "data.prg").write_bytes(bytes([0x00, 0x40]) + bytes(fli_mem) + bytes(nrm_mem))
    (out / "colram.prg").write_bytes(bytes([0x00, 0x30]) + colram.tobytes())  # loads at $3000
    preview(tgt, out / "preview-target.png")
    preview(normal, out / "preview-normal.png")
    preview(fli, out / "preview-fli.png")
    Image.fromarray(img.astype(np.uint8)).resize((640, 400), Image.NEAREST).save(out / "preview-source.png")
    (out / "convert.json").write_text(json.dumps({"image": a.image, "crop": a.crop, "error": err, "coloursPerCell": used}, indent=2))
    print(json.dumps({"error": err, "coloursPerCell": used}))


if __name__ == "__main__":
    main()
