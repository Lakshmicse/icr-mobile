"""Size and tracking that give a text's ink box (width AND height) a measured size.
python tool/design/fitbox.py "Smart Campuses" 83 10.5 [--family Plex --weights 400,500]
Both numbers in dp (lines2.py prints them as w and y1-y0). Height fixes the size, so the difference
between the width at that size and the measured width is tracking (letter-spacing, dp per gap).
"""
import argparse, os, sys
sys.stdout.reconfigure(encoding="utf-8")
from PIL import ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "..", "assets", "fonts")
F = {"Work": {400: "WorkSans-Regular.ttf", 500: "WorkSans-Medium.ttf", 600: "WorkSans-SemiBold.ttf", 700: "WorkSans-Bold.ttf"},
     "Plex": {400: "IBMPlexSans-Regular.ttf", 500: "IBMPlexSans-Medium.ttf", 600: "IBMPlexSans-SemiBold.ttf", 700: "IBMPlexSans-Bold.ttf"}}
ap = argparse.ArgumentParser()
ap.add_argument("text"); ap.add_argument("width", type=float); ap.add_argument("height", type=float)
ap.add_argument("--family", default="Plex"); ap.add_argument("--weights", default="400,500,600,700")
a = ap.parse_args()
for w in (int(x) for x in a.weights.split(",")):
    font = ImageFont.truetype(os.path.join(FONTS, F[a.family][w]), 400)
    l, t, r, b = font.getbbox(a.text)
    size = a.height / ((b - t) / 400)
    natural = (r - l) / 400 * size
    gaps = max(len(a.text) - 1, 1)
    print(f"{a.family}{w}: size {size:5.2f} natural width {natural:6.1f} vs {a.width} -> tracking {(a.width - natural) / gaps:+.3f} dp/gap")
