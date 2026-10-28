"""Where does a render drift from its design? Usage: python tool/design/drift.py DESIGN RENDER [--win 120] [--step 60] [--max 24] [--save build/audit/name]

Both go to 2x as in strip_diff.py (the design is aligned by the same small search). For each window of
rows of the render the design is slid up and down; the offset with the least difference is printed
(2x px; positive = the content sits LOWER in the render than in the design). Where the offset changes
between two windows, something between them is taller or shorter than the design's.
--save writes the aligned 2x design as <save>_design.png.
"""

import argparse
import sys

import numpy as np
from PIL import Image, ImageFilter

from strip_diff import load


def _cache_path():
    import os

    os.makedirs("build/audit", exist_ok=True)
    return "build/audit/align_cache.json"


def aligned(design_path, render_path, frame_w=0):
    """The design cut to its frame at 2x. The frame's place inside the export is found once per design
    (against the render of the day) and kept in build/audit/align_cache.json, so later renders are
    compared with the same crop; delete the file (or the design's entry) to search again."""
    import json
    import os

    d = load(design_path)
    r = load(render_path)
    fw = frame_w or min(d.width, 1560)
    scale = 780 / fw
    cache = {}
    if os.path.exists(_cache_path()):
        try:
            cache = json.load(open(_cache_path()))
        except Exception:
            cache = {}
    key = os.path.basename(design_path)
    if key in cache:
        dx, dy = cache[key]
        hh = int((d.height - dy) * scale)
        dd = d.crop((dx, dy, dx + fw, dy + int(hh / scale))).resize((780, hh), Image.LANCZOS)
        return dd, r
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
    cache[key] = [dx, dy]
    json.dump(cache, open(_cache_path(), "w"))
    hh = int((d.height - dy) * scale)
    dd = d.crop((dx, dy, dx + fw, dy + int(hh / scale))).resize((780, hh), Image.LANCZOS)
    return dd, r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("design")
    ap.add_argument("render")
    ap.add_argument("--win", type=int, default=120)
    ap.add_argument("--step", type=int, default=60)
    ap.add_argument("--max", type=int, default=24)
    ap.add_argument("--save", default=None)
    ap.add_argument("--frame-w", type=int, default=0)
    a = ap.parse_args()
    dd, r = aligned(a.design, a.render, a.frame_w)
    if a.save:
        dd.save(a.save + "_design.png")
    A = np.asarray(dd.convert("L").filter(ImageFilter.GaussianBlur(0.8))).astype(np.int16)
    B = np.asarray(r.convert("L").filter(ImageFilter.GaussianBlur(0.8))).astype(np.int16)
    h = min(A.shape[0], B.shape[0])
    print(f"design {A.shape[0]} px, render {B.shape[0]} px (2x)")
    prev = None
    for y in range(a.max, h - a.win - a.max, a.step):
        w = B[y : y + a.win]
        if w.std() < 6:
            continue
        best = None
        for off in range(-a.max, a.max + 1):
            seg = A[y - off : y - off + a.win] if y - off >= 0 and y - off + a.win <= A.shape[0] else None
            if seg is None:
                continue
            e = np.abs(seg - w).mean()
            if best is None or e < best[0]:
                best = (e, off)
        if best is None:
            continue
        flag = "" if prev is None or best[1] == prev else f"   <-- change {best[1] - prev:+d}"
        print(f"y={y:5d} ({y / 2:7.1f} dp)  render lower by {best[1]:+3d} px ({best[1] / 2:+.1f} dp)  err {best[0]:5.1f}{flag}")
        prev = best[1]


if __name__ == "__main__":
    sys.exit(main())
