"""The ink colour of a region, design (sampled from the 4x export, stroke cores) beside the render.
python tool/design/color_at.py DESIGN.png RENDER.png X0 Y0 X1 Y1 [--dy N] [--bg]
2x px of the render; --dy as in word_boxes.py. Prints the mean colour of the darkest 3% of pixels (the text), or with
--bg the median colour of the region (the fill)."""
import argparse
import json
import os

import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("design")
ap.add_argument("render")
ap.add_argument("x0", type=int)
ap.add_argument("y0", type=int)
ap.add_argument("x1", type=int)
ap.add_argument("y1", type=int)
ap.add_argument("--dy", type=int, default=0)
ap.add_argument("--bg", action="store_true")
ap.add_argument("--pct", type=float, default=3)
a = ap.parse_args()
dpath = "docs/designs/hires/" + a.design
cache = json.load(open("build/audit/align_cache.json"))
dx, dy0 = cache[os.path.basename(dpath)]
d = Image.open(dpath)
if d.mode == "RGBA":
    bg = Image.new("RGBA", d.size, (255, 255, 255, 255))
    bg.alpha_composite(d)
    d = bg
d = d.convert("RGB")
r = Image.open("build/screens/" + a.render).convert("RGB")
scale = d.width / 1560 if d.width < 1560 else 1560 / 1560
f = 1560 / 780  # 4x design px per 2x px
dc = d.crop((int(dx + a.x0 * f), int(dy0 + (a.y0 - a.dy) * f), int(dx + a.x1 * f), int(dy0 + (a.y1 - a.dy) * f)))
rc = r.crop((a.x0, a.y0, a.x1, a.y1))


def ink(im):
    arr = np.asarray(im).reshape(-1, 3).astype(float)
    if a.bg:
        return np.median(arr, axis=0)
    lum = arr.mean(axis=1)
    k = max(3, int(len(arr) * a.pct / 100))
    idx = np.argsort(lum)[:k]
    return arr[idx].mean(axis=0)


def hexs(c):
    return "#%02X%02X%02X" % tuple(int(round(v)) for v in c)


print(f"design {hexs(ink(dc))}   render {hexs(ink(rc))}")
