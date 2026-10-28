"""Lay a rendered card screen beside its design, aligned on the card's corner.

    python tool/design/cardcompare.py <render.png> <design.png> <out.png> [--scale 2]

The render (2x by default) is scaled to 1x, then both are cropped so the card's
top-left corner sits at the same place, and the vertical bands of ink inside the
card are listed for both so rows can be compared in dp.
"""
import argparse
import sys

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
ap = argparse.ArgumentParser()
ap.add_argument("render")
ap.add_argument("design")
ap.add_argument("out")
ap.add_argument("--scale", type=float, default=2)
a = ap.parse_args()


def card_corner(img):
    arr = np.asarray(img.convert("RGB")).astype(int)
    page = arr[0, 0]
    # first row / column that is not the page colour, scanning through the card's middle
    mid_x, mid_y = arr.shape[1] // 2, arr.shape[0] // 2
    col = np.nonzero(np.abs(arr[:, mid_x] - page).sum(axis=1) > 8)[0]
    row = np.nonzero(np.abs(arr[mid_y, :] - page).sum(axis=1) > 8)[0]
    return int(row[0]), int(col[0])


def bands(img, x0, y0, w, h):
    arr = np.asarray(img.convert("RGB")).astype(int)[y0 : y0 + h, x0 : x0 + w]
    bg = arr[h // 2, 30]
    diff = np.abs(arr - bg).sum(axis=2) > 40
    rows = np.nonzero(diff[:, 22 : w - 22].any(axis=1))[0]
    out, s, p = [], rows[0], rows[0]
    for r in rows[1:]:
        if r != p + 1:
            out.append((int(s), int(p)))
            s = r
        p = r
    out.append((int(s), int(p)))
    return out


render = Image.open(a.render).convert("RGB")
render = render.resize((round(render.size[0] / a.scale), round(render.size[1] / a.scale)), Image.LANCZOS)
design = Image.open(a.design).convert("RGB")
rx, ry = card_corner(render)
dx, dy = card_corner(design)
W, H = design.size
rc = render.crop((rx - dx, ry - dy, rx - dx + W, ry - dy + H))
m = Image.new("RGB", (W * 2 + 12, H), (255, 0, 255))
m.paste(design, (0, 0))
m.paste(rc, (W + 12, 0))
m.save(a.out)
print("card corner render", (rx, ry), "design", (dx, dy))
db = bands(design, 0, 0, W, H)
rb = bands(rc, 0, 0, W, H)
print("design bands:", db)
print("render bands:", rb)
if len(db) == len(rb):
    print("offsets (render - design) y0:", [r[0] - d[0] for d, r in zip(db, rb)], " y1:", [r[1] - d[1] for d, r in zip(db, rb)])
