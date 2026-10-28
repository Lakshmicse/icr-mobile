"""Stack the design's native 4x crop over the render's crop scaled to the same size, for judging weight and shape.
python tool/design/zoomcmp.py DESIGN RENDER x0 y0 x1 y1 OUT [--dx 32 --dy 28] [--rdy 0] [--side]
Box in dp of the design's frame; --dx/--dy are the frame's offset in the export (strip_diff.py prints them);
--rdy shifts the render's crop (dp) when the render has drifted. DESIGN is under docs/designs/hires/, RENDER under build/screens/.
"""
import argparse, os
from PIL import Image

def load(p):
    im = Image.open(p)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255)); bg.alpha_composite(im); im = bg
    return im.convert("RGB")

ap = argparse.ArgumentParser()
ap.add_argument("design"); ap.add_argument("render")
for n in ("x0", "y0", "x1", "y1"): ap.add_argument(n, type=float)
ap.add_argument("out")
ap.add_argument("--dx", type=int, default=32); ap.add_argument("--dy", type=int, default=28)
ap.add_argument("--rdy", type=float, default=0.0)
ap.add_argument("--side", action="store_true")
a = ap.parse_args()
dp = a.design if os.path.exists(a.design) else os.path.join("docs/designs/hires", a.design)
rp = a.render if os.path.exists(a.render) else os.path.join("build/screens", a.render)
d, r = load(dp), load(rp)
dc = d.crop((int(a.dx + a.x0 * 4), int(a.dy + a.y0 * 4), int(a.dx + a.x1 * 4), int(a.dy + a.y1 * 4)))
rc = r.crop((int(a.x0 * 2), int((a.y0 + a.rdy) * 2), int(a.x1 * 2), int((a.y1 + a.rdy) * 2))).resize(dc.size, Image.LANCZOS)
if a.side:
    o = Image.new("RGB", (dc.width * 2 + 8, dc.height), (255, 0, 255)); o.paste(dc, (0, 0)); o.paste(rc, (dc.width + 8, 0))
else:
    o = Image.new("RGB", (dc.width, dc.height * 2 + 8), (255, 0, 255)); o.paste(dc, (0, 0)); o.paste(rc, (0, dc.height + 8))
o.save(a.out); print(o.size)
