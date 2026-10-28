"""Measure a design export.

The designs arrive as PNGs of a 390 dp-wide frame, usually at 2x (780 px).
This prints the picture's structure so a screen can be built to the pixel:

  python tool/design/measure.py IMAGE [--scale 2] [--y0 0] [--y1 H]
      Bands of non-white rows, and inside each band the boxes of non-white
      columns, with their dominant colour. Sizes are given in dp.

  python tool/design/measure.py IMAGE --ink x0,y0,x1,y1 [--dark 150] [--gap 6]
      The boxes of dark pixels (text, icons) inside a region, word by word.

  python tool/design/measure.py IMAGE --colors x0,y0,x1,y1
      The darkest and the most common non-white colours in a region.

  python tool/design/measure.py IMAGE --crop x0,y0,x1,y1 --out crop.png [--zoom 3]
      A zoomed crop to look at.

  python tool/design/measure.py IMAGE --flatten --out flat.png [--frame x0,y0,x1,y1]
      Composites a transparent export over white (and cuts the phone frame out).

Needs Pillow and numpy.
"""

import argparse

import numpy as np
from PIL import Image


def load(path, flatten=True):
    im = Image.open(path)
    if flatten and im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        im = bg
    return im.convert("RGB")


def segments(mask):
    """Runs of True in a 1-D boolean array, as (start, end) inclusive."""
    out, start = [], None
    for i, v in enumerate(list(mask) + [False]):
        if v and start is None:
            start = i
        if not v and start is not None:
            out.append([start, i - 1])
            start = None
    return out


def merge(segs, gap):
    merged = []
    for s in segs:
        if merged and s[0] - merged[-1][1] <= gap:
            merged[-1][1] = s[1]
        else:
            merged.append(list(s))
    return merged


def dominant(block, white):
    m = block.reshape(-1, 3)
    nw = m[m.min(axis=1) < white]
    if len(nw) == 0:
        return None
    vals, counts = np.unique(nw, axis=0, return_counts=True)
    return tuple(int(v) for v in vals[counts.argmax()])


def bands(a, y0, y1, scale, white, gap):
    sub = a[y0:y1]
    nonwhite = sub.min(axis=2) < white
    for b0, b1 in segments(nonwhite.any(axis=1)):
        rows = nonwhite[b0 : b1 + 1]
        parts = []
        for x0, x1 in merge(segments(rows.any(axis=0)), gap):
            blk = sub[b0 : b1 + 1, x0 : x1 + 1]
            ys = np.where(blk.min(axis=2) < white)[0]
            yy0, yy1 = y0 + b0 + ys.min(), y0 + b0 + ys.max()
            parts.append(
                f"x{x0}-{x1}({(x1 - x0 + 1) / scale:g}) y{yy0}-{yy1}({(yy1 - yy0 + 1) / scale:g}) {dominant(blk, white)}"
            )
        print(f"band y{y0 + b0}-{y0 + b1} ({(b1 - b0 + 1) / scale:g}dp): " + " | ".join(parts))


def ink(a, box, scale, dark, gap):
    x0, y0, x1, y1 = box
    blk = a[y0 : y1 + 1, x0 : x1 + 1]
    m = blk.max(axis=2) < dark
    for sx0, sx1 in merge(segments(m.any(axis=0)), gap):
        ys = np.where(m[:, sx0 : sx1 + 1].any(axis=1))[0]
        bx0, bx1, by0, by1 = x0 + sx0, x0 + sx1, y0 + ys.min(), y0 + ys.max()
        print(
            f"x{bx0}-{bx1} y{by0}-{by1}  dp: left {bx0 / scale:g} right {(bx1 + 1) / scale:g} "
            f"w {(bx1 - bx0 + 1) / scale:g} top {by0 / scale:g} bottom {(by1 + 1) / scale:g} h {(by1 - by0 + 1) / scale:g}"
        )


def colors(a, box, white):
    x0, y0, x1, y1 = box
    blk = a[y0 : y1 + 1, x0 : x1 + 1].reshape(-1, 3)
    darkest = blk[blk.sum(axis=1).argmin()]
    print("darkest", tuple(int(v) for v in darkest), "#%02X%02X%02X" % tuple(int(v) for v in darkest))
    nw = blk[blk.min(axis=1) < white]
    if len(nw):
        vals, counts = np.unique(nw, axis=0, return_counts=True)
        order = counts.argsort()[::-1][:6]
        for i in order:
            c = tuple(int(v) for v in vals[i])
            print("common", c, "#%02X%02X%02X" % c, counts[i])


def main():
    p = argparse.ArgumentParser()
    p.add_argument("image")
    p.add_argument("--scale", type=float, default=2)
    p.add_argument("--y0", type=int, default=0)
    p.add_argument("--y1", type=int)
    p.add_argument("--white", type=int, default=248)
    p.add_argument("--dark", type=int, default=150)
    p.add_argument("--gap", type=int, default=3)
    p.add_argument("--ink")
    p.add_argument("--colors")
    p.add_argument("--crop")
    p.add_argument("--zoom", type=float, default=3)
    p.add_argument("--flatten", action="store_true")
    p.add_argument("--frame")
    p.add_argument("--out")
    args = p.parse_args()

    im = load(args.image)
    box = lambda s: tuple(int(v) for v in s.split(","))
    if args.flatten:
        if args.frame:
            im = im.crop(box(args.frame))
        im.save(args.out)
        print("saved", args.out, im.size)
        return
    if args.crop:
        c = im.crop(box(args.crop))
        c = c.resize((int(c.width * args.zoom), int(c.height * args.zoom)), Image.LANCZOS)
        c.save(args.out)
        print("saved", args.out, c.size)
        return
    a = np.asarray(im)
    if args.ink:
        ink(a, box(args.ink), args.scale, args.dark, args.gap)
    elif args.colors:
        colors(a, box(args.colors), args.white)
    else:
        bands(a, args.y0, args.y1 or a.shape[0], args.scale, args.white, args.gap)


if __name__ == "__main__":
    main()
