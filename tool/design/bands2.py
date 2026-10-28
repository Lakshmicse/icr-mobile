"""Row bands of a design (flat 2x, from flat2x.py) and a render side by side, in dp.
python tool/design/bands2.py DESIGN_FLAT RENDER Y0 Y1 [--x0 0 --x1 390 --thr 235 --gap 2 --minh 2]
Pairs bands in order; shows top/bottom of each and the render-minus-design delta (dp). When counts differ the pairing
drifts, so narrow the y range / x range to something that has the same elements in both.
"""
import argparse, os
import numpy as np
from PIL import Image

def load(p):
    im = Image.open(p)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255)); bg.alpha_composite(im); im = bg
    return im.convert("RGB")

def bands(a, thr, gap, minh):
    ink = (a.min(axis=2) < thr).any(axis=1)
    out, i, n = [], 0, len(ink)
    while i < n:
        if ink[i]:
            j = i
            while j < n and ink[j]: j += 1
            out.append([i, j])
            i = j
        else:
            i += 1
    m = []
    for b in out:
        if m and b[0] - m[-1][1] <= gap: m[-1][1] = b[1]
        else: m.append(b)
    return [b for b in m if b[1] - b[0] >= minh]

ap = argparse.ArgumentParser()
ap.add_argument("design"); ap.add_argument("render")
ap.add_argument("y0", type=float); ap.add_argument("y1", type=float)
ap.add_argument("--x0", type=float, default=0); ap.add_argument("--x1", type=float, default=390)
ap.add_argument("--thr", type=int, default=235); ap.add_argument("--gap", type=int, default=2); ap.add_argument("--minh", type=int, default=2)
ap.add_argument("--dy", type=float, default=0, help="render y offset (dp) of the render range relative to the design's")
a = ap.parse_args()
D = np.asarray(load(a.design if os.path.exists(a.design) else os.path.join("build/audit/mp", a.design))).astype(int)
R = np.asarray(load(a.render if os.path.exists(a.render) else os.path.join("build/screens", a.render))).astype(int)
x0, x1 = int(a.x0 * 2), int(a.x1 * 2)
y0, y1 = int(a.y0 * 2), int(a.y1 * 2)
bd = bands(D[y0:y1, x0:x1], a.thr, a.gap, a.minh)
ry0, ry1 = int((a.y0 + a.dy) * 2), int((a.y1 + a.dy) * 2)
br = bands(R[ry0:ry1, x0:x1], a.thr, a.gap, a.minh)
print(f"design {len(bd)} bands, render {len(br)} bands (dp, y absolute in the design's frame)")
for k in range(max(len(bd), len(br))):
    d = bd[k] if k < len(bd) else None
    r = br[k] if k < len(br) else None
    ds = f"{(d[0]+y0)/2:7.1f}-{(d[1]+y0)/2:7.1f} ({(d[1]-d[0])/2:5.1f})" if d else " " * 24
    rs = f"{(r[0]+ry0)/2:7.1f}-{(r[1]+ry0)/2:7.1f} ({(r[1]-r[0])/2:5.1f})" if r else " " * 24
    dl = ""
    if d and r:
        dl = f"top {((r[0]+ry0)-(d[0]+y0))/2:+5.1f}  bot {((r[1]+ry0)-(d[1]+y0))/2:+5.1f}  h {((r[1]-r[0])-(d[1]-d[0]))/2:+5.1f}"
    print(f"{k:3d} D {ds}   R {rs}   {dl}")
