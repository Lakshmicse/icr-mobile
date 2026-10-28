"""Colour of one column, design (4x rows, printed per 2x px as two samples) beside the render. Finds edges to the 1/4 dp.
python tool/design/col_profile.py DESIGN RENDER X Y0 Y1 [--dy N]   (2x px of the render; prints only where the colour changes)"""
import argparse, json, os
from PIL import Image
ap = argparse.ArgumentParser()
ap.add_argument("design"); ap.add_argument("render")
ap.add_argument("x", type=int); ap.add_argument("y0", type=int); ap.add_argument("y1", type=int)
ap.add_argument("--dy", type=int, default=0)
ap.add_argument("--tol", type=int, default=6)
a = ap.parse_args()
dp = "docs/designs/hires/" + a.design
dx, dy0 = json.load(open("build/audit/align_cache.json"))[os.path.basename(dp)]
d = Image.open(dp)
if d.mode == "RGBA":
    bg = Image.new("RGBA", d.size, (255, 255, 255, 255)); bg.alpha_composite(d); d = bg
d = d.convert("RGB")
r = Image.open("build/screens/" + a.render).convert("RGB")
def runs(get, n0, n1, step):
    out = []; prev = None; start = n0
    for i in range(n0, n1):
        c = get(i)
        if prev is None or max(abs(c[k] - prev[k]) for k in range(3)) > a.tol:
            if prev is not None: out.append((start, i, prev))
            start = i; prev = c
    out.append((start, n1, prev)); return out
dr = runs(lambda i: d.getpixel((dx + a.x * 2, dy0 + (i - a.dy) * 2)) if True else None, a.y0, a.y1, 1)
# sample design at 4x rows: i is in quarter-dp units? use 2x px *2 rows -> iterate over 4x rows
dr = runs(lambda i: d.getpixel((dx + a.x * 2, dy0 + i - a.dy * 2)), a.y0 * 2, a.y1 * 2, 1)
rr = runs(lambda i: r.getpixel((a.x, i)), a.y0, a.y1, 1)
print("design (dp, from 4x rows):")
for s, e, c in dr: print(f"  {s/4:8.2f}-{e/4:8.2f} dp  {c}")
print("render (dp, from 2x rows):")
for s, e, c in rr: print(f"  {s/2:8.2f}-{e/2:8.2f} dp  {c}")
