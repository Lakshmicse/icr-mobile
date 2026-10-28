"""Lay a rendered screen beside its design and list where their rows differ.

  python tool/design/compare.py DESIGN.png RENDER.png --out side.png [--y0 0 --y1 H] [--scale 2]

The render comes from the golden tests (`flutter test --tags golden` writes
build/screens/<name>.png at 2x). Both images must be the same width. The
output is the two side by side, and the console lists each image's bands of
non-white rows (top, bottom, height in dp) so a misplaced element shows up as
a band that starts on a different row.
"""

import argparse

import numpy as np
from PIL import Image


def load(path):
    im = Image.open(path)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        im = bg
    return im.convert("RGB")


def bands(im, y0, y1, white=248):
    a = np.asarray(im)[y0:y1]
    rows = (a.min(axis=2) < white).any(axis=1)
    out, start = [], None
    for i, v in enumerate(list(rows) + [False]):
        if v and start is None:
            start = i
        if not v and start is not None:
            # A band one pixel tall is an upscaling artefact, not an element.
            if i - start >= 2:
                out.append((y0 + start, y0 + i - 1))
            start = None
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("design")
    p.add_argument("render")
    p.add_argument("--out", required=True)
    p.add_argument("--y0", type=int, default=0)
    p.add_argument("--y1", type=int)
    p.add_argument("--scale", type=float, default=2)
    args = p.parse_args()

    d, r = load(args.design), load(args.render)
    w = min(d.width, r.width)
    y1 = args.y1 or min(d.height, r.height)
    h = y1 - args.y0
    side = Image.new("RGB", (w * 2 + 10, h), (255, 0, 255))
    side.paste(d.crop((0, args.y0, w, y1)), (0, 0))
    side.paste(r.crop((0, args.y0, w, y1)), (w + 10, 0))
    side.save(args.out)
    print("saved", args.out)

    db, rb = bands(d, args.y0, y1), bands(r, args.y0, y1)
    s = args.scale
    print(f"{'design band':>24}    {'render band':>24}")
    for i in range(max(len(db), len(rb))):
        left = f"y{db[i][0]}-{db[i][1]} ({(db[i][1] - db[i][0] + 1) / s:g}dp)" if i < len(db) else ""
        right = f"y{rb[i][0]}-{rb[i][1]} ({(rb[i][1] - rb[i][0] + 1) / s:g}dp)" if i < len(rb) else ""
        mark = "" if i < len(db) and i < len(rb) and db[i][0] == rb[i][0] else "  <-"
        print(f"{left:>24}    {right:>24}{mark}")


if __name__ == "__main__":
    main()
