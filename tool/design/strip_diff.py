"""Score a render against its design strip by strip. Usage: python tool/design/strip_diff.py DESIGN RENDER [--top 8 --out dir]

python strips.py DESIGN RENDER [--strip 60] [--top 8] [--out side_dir]
Design is the owner's hi-res export (about 4x; the frame may sit inside a shadow margin);
render is a 2x golden export (780 px wide = 390 dp). Both go to 2x, the design is aligned by a
small search, and each strip of rows gets a mean difference (0 = identical, 255 = opposite).
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageFilter


def load(path):
    im = Image.open(path)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        im = bg
    return im.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("design")
    ap.add_argument("render")
    ap.add_argument("--strip", type=int, default=60, help="strip height in 2x px")
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--out", default=None)
    ap.add_argument("--frame-w", type=int, default=0, help="frame width in design px (default: 4x of 390 dp = 1560, or the width when it is smaller)")
    a = ap.parse_args()

    d = load(a.design)
    r = load(a.render)
    fw = a.frame_w or min(d.width, 1560)
    scale = 780 / fw
    # Align: try offsets of the frame inside the design, minimising the difference over the first 360 render rows.
    rs = np.asarray(r.filter(ImageFilter.GaussianBlur(1.0))).astype(np.int16)
    best = None
    dx_range = range(0, max(1, d.width - fw) + 1, 4) if d.width > fw else [0]
    for dx in dx_range:
        for dy in range(0, 80, 2):
            crop = d.crop((dx, dy, dx + fw, dy + int(360 / scale)))
            c = np.asarray(crop.resize((780, 360), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0))).astype(np.int16)
            e = np.abs(c - rs[:360]).mean()
            if best is None or e < best[0]:
                best = (e, dx, dy)
    _, dx, dy = best
    hh = min(int((d.height - dy) * scale), r.height)
    dd = d.crop((dx, dy, dx + fw, dy + int(hh / scale))).resize((780, hh), Image.LANCZOS)
    rr = r.crop((0, 0, 780, hh))
    A = np.asarray(dd.filter(ImageFilter.GaussianBlur(1.0))).astype(np.int16)
    B = np.asarray(rr.filter(ImageFilter.GaussianBlur(1.0))).astype(np.int16)
    diff = np.abs(A - B).max(axis=2)
    print(f"align dx={dx} dy={dy}; design frame -> {dd.size}, render {r.size}; heights dp design {int((d.height - dy) * scale / 2)} render {r.height // 2}")
    rows = []
    for y in range(0, hh, a.strip):
        m = diff[y : y + a.strip].mean()
        rows.append((m, y))
    overall = float(np.mean([m for m, _ in rows]))
    bad = sorted(rows, reverse=True)[: a.top]
    print(f"overall mean diff {overall:.2f}; worst strips (2x y, dp y, mean diff):")
    for m, y in bad:
        print(f"  y={y:5d} ({y // 2:5d} dp)  {m:6.2f}")
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        stem = os.path.splitext(os.path.basename(a.render))[0]
        for i, (m, y) in enumerate(bad[:4]):
            y0 = max(0, y - 40)
            y1 = min(hh, y + a.strip + 40)
            side = Image.new("RGB", (780 * 2 + 12, y1 - y0), (255, 0, 255))
            side.paste(dd.crop((0, y0, 780, y1)), (0, 0))
            side.paste(rr.crop((0, y0, 780, y1)), (792, 0))
            side.save(os.path.join(a.out, f"{stem}_{i}_y{y}.png"))


if __name__ == "__main__":
    sys.exit(main())
