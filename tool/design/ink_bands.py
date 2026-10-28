"""Row bands of ink in a column range, design beside render, for finding which element sits a pixel off.
python tool/design/ink_bands.py DESIGN.png RENDER.png X0 X1 [Y0 Y1] [--thr 160] [--gap 2]
Coordinates are 2x px of the render. The design is aligned the way strip_diff.py does (dx/dy search). Bands are
listed in order, design left, render right, with the render's offset (render - design) at the band's top and bottom edge.
Use a column range where one kind of thing sits (a card's text column, a rule), not the whole width.
"""
import argparse
import sys

import numpy as np
from PIL import Image

from drift import aligned


def bands(img, x0, x1, y0, y1, thr, gap, minh):
    g = np.asarray(img.convert("L")).astype(np.int16)[y0:y1, x0:x1]
    dark = (g < thr).sum(axis=1) > 0
    out = []
    i = 0
    n = len(dark)
    while i < n:
        if dark[i]:
            j = i
            last = i
            while j < n and (dark[j] or j - last <= gap):
                if dark[j]:
                    last = j
                j += 1
            if last - i + 1 >= minh:
                out.append((i + y0, last + y0 + 1))
            i = j
        else:
            i += 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("design")
    ap.add_argument("render")
    ap.add_argument("x0", type=int)
    ap.add_argument("x1", type=int)
    ap.add_argument("y0", type=int, nargs="?", default=0)
    ap.add_argument("y1", type=int, nargs="?", default=10**6)
    ap.add_argument("--thr", type=int, default=160)
    ap.add_argument("--gap", type=int, default=2)
    ap.add_argument("--minh", type=int, default=3)
    ap.add_argument("--frame-w", type=int, default=0)
    a = ap.parse_args()
    dd, r = aligned("docs/designs/hires/" + a.design, "build/screens/" + a.render, a.frame_w)
    y1 = min(a.y1, dd.height, r.height)
    bd = bands(dd, a.x0, a.x1, a.y0, y1, a.thr, a.gap, a.minh)
    br = bands(r, a.x0, a.x1, a.y0, y1, a.thr, a.gap, a.minh)
    print(f"design {len(bd)} bands, render {len(br)} bands (x {a.x0}-{a.x1}, y {a.y0}-{y1}); render offset = render - design, 2x px")
    for k in range(max(len(bd), len(br))):
        d = bd[k] if k < len(bd) else None
        e = br[k] if k < len(br) else None
        ds = f"{d[0]:5d}-{d[1]:5d} (h {d[1] - d[0]:3d})" if d else " " * 20
        es = f"{e[0]:5d}-{e[1]:5d} (h {e[1] - e[0]:3d})" if e else " " * 20
        off = f"top {e[0] - d[0]:+3d} bot {e[1] - d[1]:+3d}" if d and e else ""
        print(f"{k:3d}  design {ds}   render {es}   {off}")


if __name__ == "__main__":
    sys.exit(main())
