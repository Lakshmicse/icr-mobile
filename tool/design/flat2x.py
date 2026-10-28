"""Cut a hi-res design's frame out and bring it to 2x (780 px wide) so measure.py / line tools can read it.
python tool/design/flat2x.py DESIGN OUT [--dx 0 --dy 0 --frame-w 1560]   (dx, dy: the frame's offset in the export, as strip_diff.py prints)
"""
import argparse
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("design"); ap.add_argument("out")
ap.add_argument("--dx", type=int, default=0); ap.add_argument("--dy", type=int, default=0)
ap.add_argument("--frame-w", type=int, default=1560)
a = ap.parse_args()
import os
p = a.design if os.path.exists(a.design) else os.path.join("docs/designs/hires", a.design)
im = Image.open(p)
if im.mode == "RGBA":
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255)); bg.alpha_composite(im); im = bg
im = im.convert("RGB")
fw = min(a.frame_w, im.width)
c = im.crop((a.dx, a.dy, a.dx + fw, im.height))
s = 780 / fw
c = c.resize((780, int(c.height * s)), Image.LANCZOS)
c.save(a.out)
print(a.out, c.size)
