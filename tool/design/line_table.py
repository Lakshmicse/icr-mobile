"""Every matched text line of a render against its design, with its vertical drift.
python tool/design/line_table.py DESIGN.png RENDER.png [--min-ink 150] [--y0 0 --y1 99999] [--all]
(names relative to docs/designs/hires/ and build/screens/, as line_match.py.)
Columns: y (2x px, render), design x0..x1, render x0..x1, width ratio design/render, ink ratio, dy (render - design, 2x px).
A line whose dy changes against the previous line says what sits between them is taller or shorter than the design's.
"""
import argparse
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, __file__.rsplit("tool", 1)[0] + "tool/design")


def load(p):
    im = Image.open(p)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        im = bg
    return im.convert("RGB")


def find_lines(a):
    g = a.min(axis=2)
    H = a.shape[0]
    dark = g < 150
    light_frac = (g > 215).mean(axis=1)
    rows = dark.sum(axis=1) > 2
    rows &= light_frac > 0.55
    out = []
    i = 0
    while i < H:
        if rows[i]:
            j = i
            while j < H and rows[j]:
                j += 1
            if 6 <= j - i <= 26:
                cols = np.where(dark[i:j].any(axis=0))[0]
                seg = g[i:j, cols.min() : cols.max() + 1]
                out.append(dict(y0=i, y1=j, x0=cols.min(), x1=cols.max(), ink=(255 - seg).sum() / 1000))
            i = j
        else:
            i += 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("design")
    ap.add_argument("render")
    ap.add_argument("--min-ink", type=float, default=150)
    ap.add_argument("--y0", type=int, default=0)
    ap.add_argument("--y1", type=int, default=10**6)
    ap.add_argument("--all", action="store_true", help="also list unmatched render lines")
    a = ap.parse_args()
    D0 = load("docs/designs/hires/" + a.design)
    R = load("build/screens/" + a.render)
    fw = min(D0.width, 1560)
    rs = np.asarray(R.filter(ImageFilter.GaussianBlur(1.0))).astype(np.int16)
    best = None
    for dx in range(0, D0.width - fw + 1, 4) if D0.width > fw else [0]:
        for dy in range(0, 80, 2):
            c = np.asarray(
                D0.crop((dx, dy, dx + fw, dy + int(360 / (780 / fw)))).resize((780, 360), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0))
            ).astype(np.int16)
            e = np.abs(c - rs[:360]).mean()
            if best is None or e < best[0]:
                best = (e, dx, dy)
    _, dx, dy = best
    D = D0.crop((dx, dy, dx + fw, D0.height))
    D = D.resize((780, int(D.height * 780 / fw)), Image.LANCZOS)
    A = np.asarray(D).astype(float)
    B = np.asarray(R).astype(float)
    la, lb = find_lines(A), find_lines(B)
    used = set()
    print(f"aligned dx={dx} dy={dy}; {len(la)} design lines, {len(lb)} render lines")
    print("   y(render) dp   design x0-x1   render x0-x1   w(d/r)  ink(d/r)   dy(2x px)")
    for m_i, m in enumerate(lb):
        if not (a.y0 <= m["y0"] <= a.y1):
            continue
        best = None
        for k, l in enumerate(la):
            if k in used:
                continue
            if abs((l["y0"] + l["y1"]) / 2 - (m["y0"] + m["y1"]) / 2) <= 22 and abs(l["x0"] - m["x0"]) <= 14:
                d = abs(l["y0"] - m["y0"]) * 0.5 + abs(l["x0"] - m["x0"])
                if best is None or d < best[0]:
                    best = (d, k)
        if best:
            used.add(best[1])
            l = la[best[1]]
            wd, wr = l["x1"] - l["x0"], m["x1"] - m["x0"]
            if m["ink"] > a.min_ink:
                print(
                    f"  {m['y0']:5d} {m['y0'] / 2:7.1f}   {l['x0']:4d}-{l['x1']:4d}   {m['x0']:4d}-{m['x1']:4d}   "
                    f"{wd / max(wr, 1):5.3f}  {l['ink'] / max(m['ink'], 0.01):5.2f}    {m['y0'] - l['y0']:+3d}"
                )
        elif a.all and m["ink"] > a.min_ink:
            print(f"  {m['y0']:5d} {m['y0'] / 2:7.1f}   (no match)  render {m['x0']}-{m['x1']}  ink {m['ink']:.0f}")


if __name__ == "__main__":
    main()
