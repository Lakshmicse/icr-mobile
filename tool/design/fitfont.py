"""Which font size draws a word as wide as the design does.

  python tool/design/fitfont.py "Recommended" 86.5
  python tool/design/fitfont.py "Senior Facilities Manager" 160 --px --scale 1

Prints the size, for Work Sans and IBM Plex Sans at each bundled weight,
that makes the text's ink as wide as the measured width (in dp, or in image
pixels with --px and --scale). Size by width, not by cap height: the mocks
are set in a slightly narrower face, and matching widths is what keeps line
breaks and layout where the design has them.
"""

import argparse
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

from PIL import ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "..", "assets", "fonts")
FAMILIES = {
    "Work": {400: "WorkSans-Regular.ttf", 500: "WorkSans-Medium.ttf", 600: "WorkSans-SemiBold.ttf", 700: "WorkSans-Bold.ttf"},
    "Plex": {
        400: "IBMPlexSans-Regular.ttf",
        500: "IBMPlexSans-Medium.ttf",
        600: "IBMPlexSans-SemiBold.ttf",
        700: "IBMPlexSans-Bold.ttf",
    },
}


def implied(text, width_dp):
    out = []
    for family, weights in FAMILIES.items():
        for weight, file in weights.items():
            font = ImageFont.truetype(os.path.join(FONTS, file), 200)
            left, _, right, _ = font.getbbox(text)
            out.append(f"{family}{weight}:{width_dp / ((right - left) / 200):5.1f}")
    return "  ".join(out)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("text")
    p.add_argument("width", type=float)
    p.add_argument("--px", action="store_true", help="width is in image pixels")
    p.add_argument("--scale", type=float, default=2)
    args = p.parse_args()
    width = args.width / args.scale if args.px else args.width
    print(f"{args.text!r} {width:g}dp ->", implied(args.text, width))


if __name__ == "__main__":
    main()
