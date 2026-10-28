"""Colour along one row (x runs), design (4x columns) beside render. python tool/design/row_profile.py DESIGN RENDER Y X0 X1 [--tol 20]
(2x px of the render; prints runs in dp)"""
import argparse, json, os
from PIL import Image
ap = argparse.ArgumentParser()
ap.add_argument("design"); ap.add_argument("render")
ap.add_argument("y", type=int); ap.add_argument("x0", type=int); ap.add_argument("x1", type=int)
ap.add_argument("--dy", type=int, default=0)
ap.add_argument("--tol", type=int, default=20)
a = ap.parse_args()
dp = "docs/designs/hires/" + a.design
dx, dy0 = json.load(open("build/audit/align_cache.json"))[os.path.basename(dp)]
d = Image.open(dp)
if d.mode == "RGBA":
    bg = Image.new("RGBA", d.size, (255, 255, 255, 255)); bg.alpha_composite(d); d = bg
d = d.convert("RGB")
r = Image.open("build/screens/" + a.render).convert("RGB")
def runs(get, n0, n1):
    out = []; prev = None; start = n0
    for i in range(n0, n1):
        c = get(i)
        if prev is None or max(abs(c[k] - prev[k]) for k in range(3)) > a.tol:
            if prev is not None: out.append((start, i, prev))
            start = i; prev = c
    out.append((start, n1, prev)); return out
dr = runs(lambda i: d.getpixel((dx + i, dy0 + (a.y - a.dy) * 2)), a.x0 * 2, a.x1 * 2)
rr = runs(lambda i: r.getpixel((i, a.y)), a.x0, a.x1)
print("design:", "  ".join(f"{s/4:.2f}-{e/4:.2f}:{c[0]},{c[1]},{c[2]}" for s, e, c in dr))
print("render:", "  ".join(f"{s/2:.2f}-{e/2:.2f}:{c[0]},{c[1]},{c[2]}" for s, e, c in rr))
