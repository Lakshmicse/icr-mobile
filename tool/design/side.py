"""Side-by-side crop of a design and a render for a band of rows, aligned like strip_diff.py.

python tool/design/side.py DESIGN RENDER Y0 Y1 OUT [--dy N] [--x0 0 --x1 390] [--zoom 1.0] [--stack]

Y0 / Y1 are in dp of the RENDER; --dy shifts the design down by N dp (positive = design content is lower)
so a band that drifted can be lined up by eye. DESIGN is relative to docs/designs/hires/ when it is not a path
that exists; RENDER likewise to build/screens/. Design left, render right (or --stack: design above render).
"""

import argparse
import os

import numpy as np
from PIL import Image, ImageFilter


def load(path):
    im = Image.open(path)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        im = bg
    return im.convert("RGB")


def resolve(path, base):
    if os.path.exists(path):
        return path
    for b in (base, "build/audit/mp"):
        if os.path.exists(os.path.join(b, path)):
            return os.path.join(b, path)
    return os.path.join(base, path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("design")
    ap.add_argument("render")
    ap.add_argument("y0", type=float)
    ap.add_argument("y1", type=float)
    ap.add_argument("out")
    ap.add_argument("--dy", type=float, default=0.0)
    ap.add_argument("--x0", type=float, default=0.0)
    ap.add_argument("--x1", type=float, default=390.0)
    ap.add_argument("--zoom", type=float, default=1.0)
    ap.add_argument("--stack", action="store_true")
    ap.add_argument("--frame-w", type=int, default=0)
    ap.add_argument("--align", default="", help="dx,dy printed by an earlier run: skips the search (fast)")
    a = ap.parse_args()

    d = load(resolve(a.design, "docs/designs/hires"))
    r = load(resolve(a.render, "build/screens"))
    fw = a.frame_w or min(d.width, 1560)
    scale = 780 / fw
    if a.align:
        dx, dy = (int(v) for v in a.align.split(","))
    else:
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
    dy += int(round(a.dy * 2 / scale))
    y0, y1 = int(a.y0 * 2), int(a.y1 * 2)
    x0, x1 = int(a.x0 * 2), int(a.x1 * 2)
    dcrop = d.crop((dx + int(x0 / scale), dy + int(y0 / scale), dx + int(x1 / scale), dy + int(y1 / scale)))
    dcrop = dcrop.resize((x1 - x0, y1 - y0), Image.LANCZOS)
    rcrop = r.crop((x0, y0, x1, y1))
    w, h = dcrop.size
    if a.stack:
        side = Image.new("RGB", (w, h * 2 + 6), (255, 0, 255))
        side.paste(dcrop, (0, 0))
        side.paste(rcrop, (0, h + 6))
    else:
        side = Image.new("RGB", (w * 2 + 6, h), (255, 0, 255))
        side.paste(dcrop, (0, 0))
        side.paste(rcrop, (w + 6, 0))
    if a.zoom != 1.0:
        side = side.resize((int(side.width * a.zoom), int(side.height * a.zoom)), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    side.save(a.out)
    print(f"aligned dx={dx} dy={dy}; wrote {a.out} {side.size}")


if __name__ == "__main__":
    main()
