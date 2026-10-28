"""Lay a device screenshot beside its design, both at the design's 2x scale.

    python tool/design/devcompare.py <device.png> <design.png> <out.png> [--design-y N] [--device-y N] [--height N]

The device capture is 390 dp wide at density 443 (1080 px); it is scaled to the
design's width. --design-y / --device-y pick where to start in each image (in
2x pixels of the scaled image), so a scrolled capture can be matched to the
part of a long design it shows.
"""
import argparse
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument('device')
ap.add_argument('design')
ap.add_argument('out')
ap.add_argument('--design-y', type=int, default=0)
ap.add_argument('--device-y', type=int, default=0)
ap.add_argument('--height', type=int, default=1700)
a = ap.parse_args()

dev = Image.open(a.device).convert('RGB')
des = Image.open(a.design).convert('RGB')
W = des.size[0]
dev = dev.resize((W, round(dev.size[1] * W / dev.size[0])), Image.LANCZOS)
h = a.height
d1 = dev.crop((0, a.device_y, W, min(dev.size[1], a.device_y + h)))
d2 = des.crop((0, a.design_y, W, min(des.size[1], a.design_y + h)))
H = max(d1.size[1], d2.size[1])
m = Image.new('RGB', (W * 2 + 12, H), (255, 0, 255))
m.paste(d2, (0, 0))      # design on the left
m.paste(d1, (W + 12, 0))  # device on the right
m.save(a.out)
print(m.size)
