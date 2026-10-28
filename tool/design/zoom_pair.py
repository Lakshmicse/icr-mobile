"""Design above, render below, one region, enlarged. python tool/design/zoom_pair.py DESIGN RENDER x0 y0 x1 y1 OUT [--zoom 2]
Coordinates are 2x px of the render; the design is the same crop of the aligned design (see drift.py)."""
import argparse
import sys

from PIL import Image

from drift import aligned

ap = argparse.ArgumentParser()
ap.add_argument("design")
ap.add_argument("render")
ap.add_argument("x0", type=int)
ap.add_argument("y0", type=int)
ap.add_argument("x1", type=int)
ap.add_argument("y1", type=int)
ap.add_argument("out")
ap.add_argument("--zoom", type=float, default=2)
ap.add_argument("--dy", type=int, default=0, help="shift the design crop by this many 2x px (to line the two up)")
ap.add_argument("--frame-w", type=int, default=0)
a = ap.parse_args()
dd, r = aligned("docs/designs/hires/" + a.design, "build/screens/" + a.render, a.frame_w)
w, h = a.x1 - a.x0, a.y1 - a.y0
z = a.zoom
top = dd.crop((a.x0, a.y0 - a.dy, a.x1, a.y1 - a.dy)).resize((int(w * z), int(h * z)), Image.LANCZOS)
bot = r.crop((a.x0, a.y0, a.x1, a.y1)).resize((int(w * z), int(h * z)), Image.LANCZOS)
im = Image.new("RGB", (int(w * z), int(h * z) * 2 + 6), (255, 0, 255))
im.paste(top, (0, 0))
im.paste(bot, (0, int(h * z) + 6))
im.save(a.out)
