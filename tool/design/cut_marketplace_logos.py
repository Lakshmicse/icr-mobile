"""Cut the Marketplace designs' supplier marks out of the logo lockups.

    python tool/design/cut_marketplace_logos.py

The demo lockups (assets/images/demo/marketplace/lockup_*.png, 4x, 612 x 148)
draw a supplier's mark and its name as one picture. A LIVE card draws the
company's logo and its name as text, so the seed uploads the mark alone: the
leftmost group of ink in each lockup, cropped tight, white taken out as
transparency (colour kept at full strength under partial alpha, so the edges
stay clean on the card's white). They are saved at 2x (half the lockup's pixels):
the app draws an API logo at half its pixel size, so the mark lands at the
design's size.

Writes tool/seed/assets/marketplace_logo_<name>.png. Needs Pillow and numpy.
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "images", "demo", "marketplace")
OUT = os.path.join(ROOT, "tool", "seed", "assets")

# lockup file -> output name. GreenGuard and SafeHome share BlueDot's mark.
MARKS = {"bluedot": "bluedot", "innowork": "innowork", "innowork_dark": "innowork_dark", "securetech": "securetech"}

# Columns of ink closer together than this belong to the same mark.
GAP = 12


def mark_of(path):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float64)
    ink = a.min(axis=2) < 235
    cols = np.where(ink.any(axis=0))[0]
    end = cols[0]
    for c in cols[1:]:
        if c - end > GAP:
            break
        end = c
    x0, x1 = cols[0], end
    rows = np.where(ink[:, x0 : x1 + 1].any(axis=1))[0]
    y0, y1 = rows[0], rows[-1]
    crop = a[y0 : y1 + 1, x0 : x1 + 1]
    alpha = 255.0 - crop.min(axis=2)
    alpha = np.clip(alpha * 1.04, 0, 255)
    safe = np.maximum(alpha, 1.0)[..., None] / 255.0
    rgb = np.clip((crop - 255.0 * (1 - safe)) / safe, 0, 255)
    out = np.dstack([rgb, alpha]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    img = img.resize((max(1, round(img.width / 2)), max(1, round(img.height / 2))), Image.LANCZOS)
    return img, (x0, y0, x1, y1)


def main():
    os.makedirs(OUT, exist_ok=True)
    for lockup, name in MARKS.items():
        img, box = mark_of(os.path.join(SRC, f"lockup_{lockup}.png"))
        target = os.path.join(OUT, f"marketplace_logo_{name}.png")
        img.save(target)
        print(f"{name}: lockup box {box} -> {img.size[0]} x {img.size[1]} px ({img.size[0] / 2:g} x {img.size[1] / 2:g} dp)")


if __name__ == "__main__":
    main()
