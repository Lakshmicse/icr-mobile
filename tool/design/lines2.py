"""Text lines of a design (flat 2x, from flat2x.py) and a render inside a box (dp), side by side.
python tool/design/lines2.py DESIGN_FLAT RENDER x0,y0,x1,y1 [--thr 200] [--dy 0] [--gap 3] [--minh 3]
A line = a run of rows holding pixels darker than --thr in some channel; its x extent, height and ink (sum of darkness/1000)
are printed in dp / px. Lines are paired in order; ratios are design/render (width) and design/render (ink).
--dy is the render's y offset (dp) when the render has drifted from the design.
Names resolve against build/audit/mp/ (design) and build/screens/ (render).
"""
import argparse, os
import numpy as np
from PIL import Image

def load(p):
    im = Image.open(p)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255)); bg.alpha_composite(im); im = bg
    return np.asarray(im.convert("RGB")).astype(int)

def runs(mask, gap):
    out, s = [], None
    for i, v in enumerate(list(mask) + [False]):
        if v and s is None: s = i
        if not v and s is not None:
            if out and s - out[-1][1] <= gap: out[-1][1] = i
            else: out.append([s, i])
            s = None
    return out

def lines(a, box, thr, gap, minh, invert=False):
    x0, y0, x1, y1 = box
    g = a[y0:y1, x0:x1].min(axis=2)
    dark = (g > thr) if invert else (g < thr)
    res = []
    for s, e in runs(dark.any(axis=1), gap):
        if e - s < minh: continue
        cols = np.where(dark[s:e].any(axis=0))[0]
        seg = (255 - g[s:e, cols.min():cols.max() + 1]) if not invert else (g[s:e, cols.min():cols.max() + 1] - thr)
        res.append(dict(y0=(y0 + s) / 2, y1=(y0 + e) / 2, x0=(x0 + cols.min()) / 2, x1=(x0 + cols.max() + 1) / 2, ink=seg.sum() / 1000))
    return res

ap = argparse.ArgumentParser()
ap.add_argument("design"); ap.add_argument("render"); ap.add_argument("box")
ap.add_argument("--thr", type=int, default=200); ap.add_argument("--dy", type=float, default=0)
ap.add_argument("--gap", type=int, default=3); ap.add_argument("--minh", type=int, default=3)
ap.add_argument("--invert", action="store_true", help="light text on a dark ground: pixels brighter than --thr")
a = ap.parse_args()
D = load(a.design if os.path.exists(a.design) else os.path.join("build/audit/mp", a.design))
R = load(a.render if os.path.exists(a.render) else os.path.join("build/screens", a.render))
x0, y0, x1, y1 = (float(v) for v in a.box.split(","))
bx = tuple(int(v * 2) for v in (x0, y0, x1, y1))
rb = (bx[0], int((y0 + a.dy) * 2), bx[2], int((y1 + a.dy) * 2))
ld, lr = lines(D, bx, a.thr, a.gap, a.minh, a.invert), lines(R, rb, a.thr, a.gap, a.minh, a.invert)
print(f"design {len(ld)} lines, render {len(lr)} lines (dp; render y shown in the design's frame)")
for k in range(max(len(ld), len(lr))):
    d = ld[k] if k < len(ld) else None
    r = lr[k] if k < len(lr) else None
    ds = f"y {d['y0']:7.1f}-{d['y1']:7.1f} x {d['x0']:6.1f}-{d['x1']:6.1f} w {d['x1']-d['x0']:6.1f} ink {d['ink']:6.1f}" if d else " " * 56
    rs = f"y {r['y0']-a.dy:7.1f}-{r['y1']-a.dy:7.1f} x {r['x0']:6.1f}-{r['x1']:6.1f} w {r['x1']-r['x0']:6.1f} ink {r['ink']:6.1f}" if r else ""
    q = ""
    if d and r:
        q = f" | dy {(r['y0']-a.dy)-d['y0']:+5.1f}/{(r['y1']-a.dy)-d['y1']:+5.1f} dx {r['x0']-d['x0']:+5.1f} w x{(d['x1']-d['x0'])/max(r['x1']-r['x0'],.1):.3f} ink x{d['ink']/max(r['ink'],.1):.2f}"
    print(f"{k:2d} D {ds}\n   R {rs}{q}")
