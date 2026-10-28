"""Word boxes (column runs of ink) inside a row band, design beside render.
python tool/design/word_boxes.py DESIGN.png RENDER.png X0 Y0 X1 Y1 [--dy N] [--gap 9] [--thr 170]
2x px of the render. --dy shifts the design's rows (design y = y - dy) when the line sits that much higher/lower there.
Prints each box's x-range and width in both, and the width ratio design/render."""
import argparse

import numpy as np

from drift import aligned

ap = argparse.ArgumentParser()
ap.add_argument("design")
ap.add_argument("render")
ap.add_argument("x0", type=int)
ap.add_argument("y0", type=int)
ap.add_argument("x1", type=int)
ap.add_argument("y1", type=int)
ap.add_argument("--dy", type=int, default=0)
ap.add_argument("--gap", type=int, default=9)
ap.add_argument("--thr", type=int, default=170)
ap.add_argument("--frame-w", type=int, default=0)
a = ap.parse_args()
dd, r = aligned("docs/designs/hires/" + a.design, "build/screens/" + a.render, a.frame_w)


def boxes(img, y0, y1):
    g = np.asarray(img.convert("L")).astype(np.int16)[y0:y1, a.x0 : a.x1]
    cols = (g < a.thr).any(axis=0)
    out = []
    i = 0
    n = len(cols)
    while i < n:
        if cols[i]:
            j = i
            last = i
            while j < n and (cols[j] or j - last <= a.gap):
                if cols[j]:
                    last = j
                j += 1
            out.append((i + a.x0, last + a.x0 + 1))
            i = j
        else:
            i += 1
    ys = np.where((g < a.thr).any(axis=1))[0]
    return out, (int(ys.min() + y0), int(ys.max() + y0 + 1)) if len(ys) else None


bd, yd = boxes(dd, a.y0 - a.dy, a.y1 - a.dy)
br, yr = boxes(r, a.y0, a.y1)
print(f"design rows {yd}, render rows {yr}; {len(bd)} vs {len(br)} words")
tot_d = tot_r = 0
for k in range(max(len(bd), len(br))):
    d = bd[k] if k < len(bd) else None
    e = br[k] if k < len(br) else None
    ds = f"{d[0]:4d}-{d[1]:4d} w{d[1]-d[0]:4d}" if d else " " * 14
    es = f"{e[0]:4d}-{e[1]:4d} w{e[1]-e[0]:4d}" if e else " " * 14
    ratio = f"{(d[1]-d[0])/(e[1]-e[0]):.3f}" if d and e else ""
    print(f"{k:2d} design {ds}   render {es}   x{ratio}")
