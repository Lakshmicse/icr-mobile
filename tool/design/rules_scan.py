"""Thin horizontal rules (1 dp lines of a border colour) down one column, design beside render, in dp.
python tool/design/rules_scan.py DESIGN RENDER X [--y0 0 --y1 99999] [--col 226,232,240] [--tol 10]
(X in 2x px of the render.) A line is a run of 0.5 to 1.75 dp whose colour is within tol of --col (default: the slate-200
rules, and the card border grey 229,231,232). Use a column that crosses no text."""
import argparse, json, os
from PIL import Image
ap = argparse.ArgumentParser()
ap.add_argument("design"); ap.add_argument("render"); ap.add_argument("x", type=int)
ap.add_argument("--y0", type=int, default=0); ap.add_argument("--y1", type=int, default=10**6)
ap.add_argument("--col", default="226,232,240;229,231,232;233,237,242")
ap.add_argument("--tol", type=int, default=8)
a = ap.parse_args()
cols = [tuple(int(v) for v in c.split(",")) for c in a.col.split(";")]
dp = "docs/designs/hires/" + a.design
dx, dy0 = json.load(open("build/audit/align_cache.json"))[os.path.basename(dp)]
d = Image.open(dp)
if d.mode == "RGBA":
    bg = Image.new("RGBA", d.size, (255, 255, 255, 255)); bg.alpha_composite(d); d = bg
d = d.convert("RGB")
r = Image.open("build/screens/" + a.render).convert("RGB")
def hit(c): return any(max(abs(c[i] - k[i]) for i in range(3)) <= a.tol for k in cols)
def scan(get, n, unit):
    out = []; run = None
    for i in range(n):
        h = hit(get(i))
        if h and run is None: run = i
        if not h and run is not None:
            ln = (i - run) / unit
            if 0.5 <= ln <= 1.75: out.append(round(run / unit, 2))
            run = None
    return out
y1 = min(a.y1, r.height, (d.height - dy0) // 2)
dl = [v for v in scan(lambda i: d.getpixel((dx + a.x * 2, dy0 + i)), y1 * 2, 4) if a.y0 / 2 <= v <= y1 / 2]
rl = [v for v in scan(lambda i: r.getpixel((a.x, i)), y1, 2) if a.y0 / 2 <= v <= y1 / 2]
print("design:", dl)
print("render:", rl)
