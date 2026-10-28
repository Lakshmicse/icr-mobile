"""Cut the Councils design's six cover photos out of the export, clean.

    python tool/design/cut_council_covers.py

The design (docs/designs/councils.png, 283 px wide) carries each cover with the
glyph tile, the pills and the rounded card corners baked in. The app draws its
own tile and pills over the cover, so those are painted out (OpenCV inpainting)
and the card's border and corners are trimmed away.

Two sets come out:

  assets/images/demo/councils/cover_<name>.png    the cover as the design shows
      it (its darkening included), for the bundled demo content;
  tool/seed/assets/council_photo_<name>.png       the same with the app's own
      cover darkening (`CouncilsColors.coverScrimTop/Bottom`) taken back out, for
      the seed to upload as the councils' covers: the app darkens a photo it is
      given, so a photo that is already dark would be darkened twice.

Needs Pillow, numpy and opencv-python. Keep SCRIM_* in step with councils_styles.dart.
"""

import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "docs", "designs", "councils.png")
DEMO_DIR = os.path.join(ROOT, "assets", "images", "demo", "councils")
SEED_DIR = os.path.join(ROOT, "tool", "seed", "assets")

# The app's darkening over a cover photo (councils_styles.dart): colour 0B1329,
# alpha from the top row to the bottom row.
SCRIM_RGB = np.array([0x0B, 0x13, 0x29], dtype=np.float64)
SCRIM_TOP = 0x1A / 255.0
SCRIM_BOTTOM = 0x33 / 255.0

# The export's pixels per dp, and where each cover starts (first row of its band)
# with the baked pills' left edge, in the cover's own pixels.
COVERS = {
    "sustainability": dict(y0=563, h=56, pills_x=142),  # OFFICIAL COUNCIL + Est. 2023
    "cxo": dict(y0=755, h=56, pills_x=167),  # JOINED + Executive
    "smart_buildings": dict(y0=945, h=57, pills_x=183),  # CHARTERED 2024
    "legal": dict(y0=1136, h=57, pills_x=179),  # OFFICIAL COUNCIL
    "construction": dict(y0=1336, h=56, pills_x=183),  # CHARTERED 2024
    "real_estate": dict(y0=1540, h=57, pills_x=179),  # OFFICIAL COUNCIL
}
LEFT, RIGHT = 17, 271  # the card's interior in the export (its 1 px border is at 16 and 271)


def flatten(path):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    return np.asarray(bg.convert("RGB"))


def clean(strip, pills_x):
    """Paint out the baked tile, pills and rounded corners of a cover strip (RGB)."""
    h, w, _ = strip.shape
    mask = np.zeros((h, w), np.uint8)
    # strip x = export x - LEFT; the baked tile sat 13 dp in, the pills ended 10 dp from the right.
    mask[4 : 33, 5 : 35] = 255  # the glyph tile
    mask[4 : 26, pills_x - LEFT + 16 : w] = 255  # the pills
    mask[0:8, 0:8] = 255  # rounded corners
    mask[0:8, w - 8 : w] = 255
    return cv2.inpaint(strip, mask, 4, cv2.INPAINT_TELEA)


def unscrim(strip):
    """Take the app's darkening back out of a strip: p = raw * (1 - a) + scrim * a."""
    h = strip.shape[0]
    t = (np.arange(h) + 0.5) / h
    a = (SCRIM_TOP + (SCRIM_BOTTOM - SCRIM_TOP) * t)[:, None, None]
    raw = (strip.astype(np.float64) - SCRIM_RGB * a) / (1.0 - a)
    return np.clip(np.rint(raw), 0, 255).astype(np.uint8)


def main():
    export = flatten(SRC)
    os.makedirs(SEED_DIR, exist_ok=True)
    for name, c in COVERS.items():
        # Trim the border row at the top and the white row at the bottom.
        strip = export[c["y0"] + 1 : c["y0"] + c["h"] - 1, LEFT:RIGHT].copy()
        strip = clean(strip, c["pills_x"])
        Image.fromarray(strip).save(os.path.join(DEMO_DIR, f"cover_{name}.png"), optimize=True)
        Image.fromarray(unscrim(strip)).save(os.path.join(SEED_DIR, f"council_photo_{name}.png"), optimize=True)
        print(f"{name}: {strip.shape[1]} x {strip.shape[0]}")


if __name__ == "__main__":
    main()
