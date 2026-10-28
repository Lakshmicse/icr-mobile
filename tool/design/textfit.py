"""Find the family, weight, size and tracking that draw one line of text the way a design does.

python tool/design/textfit.py DESIGN_FLAT "x0,y0,x1,y1" "The text" --fam plex --sizes 10.4:11.6:0.1 --weights 400,500,600,700 --spacings 0
    [--color auto|RRGGBB] [--bg FFFFFF] [--top 8] [--keep]

DESIGN_FLAT is a 2x flat design (flat2x.py) or any 2x image; the box (dp) holds the one line, nothing else.
Every candidate is drawn by the app's own text stack (tool/design/lab/text_lab_test.dart, needs flutter), each
cut to its ink box, laid over the design's at the top-left of the ink and scored by mean absolute difference
(0 = identical) after a +-1 px search. A candidate whose ink box differs in width scores worse because the glyphs
drift, so width, height and weight are all judged at once. Prints the best candidates with the width and height
ratio design/candidate (1.000 = exact).
"""
import argparse, itertools, json, os, subprocess, sys
import numpy as np
from PIL import Image, ImageFilter

def load(p):
    im = Image.open(p)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255)); bg.alpha_composite(im); im = bg
    return im.convert("RGB")

def darkness(img, bg):
    a = np.asarray(img).astype(float)
    b = np.array(bg, dtype=float)
    d = np.abs(a - b).sum(axis=2) / 3.0
    return d

def ink_box(d, frac=0.18):
    m = d > d.max() * frac
    ys = np.where(m.any(axis=1))[0]; xs = np.where(m.any(axis=0))[0]
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("design"); ap.add_argument("box"); ap.add_argument("text")
    ap.add_argument("--fam", default="plex"); ap.add_argument("--sizes", default="10:12:0.1")
    ap.add_argument("--weights", default="400,500,600,700"); ap.add_argument("--spacings", default="0")
    ap.add_argument("--color", default="auto"); ap.add_argument("--bg", default="FFFFFF")
    ap.add_argument("--top", type=int, default=8); ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()
    d = load(a.design if os.path.exists(a.design) else os.path.join("build/audit/mp", a.design))
    x0, y0, x1, y1 = (float(v) for v in a.box.split(","))
    crop = d.crop((int(x0 * 2), int(y0 * 2), int(x1 * 2), int(y1 * 2)))
    bg = tuple(int(a.bg[i:i + 2], 16) for i in (0, 2, 4))
    dd = darkness(crop.filter(ImageFilter.GaussianBlur(0.5)), bg)
    bx = ink_box(dd)
    dd = dd[bx[1]:bx[3], bx[0]:bx[2]]
    if a.color == "auto":
        arr = np.asarray(crop).astype(int)
        flat = arr.reshape(-1, 3)
        lum = flat.sum(axis=1)
        dark = flat[lum <= np.percentile(lum, 1.5)]
        col = "".join("%02X" % int(v) for v in dark.mean(axis=0))
    else:
        col = a.color
    lo, hi, st = (float(v) for v in a.sizes.split(":"))
    sizes = [round(lo + i * st, 3) for i in range(int(round((hi - lo) / st)) + 1)]
    weights = [int(v) for v in a.weights.split(",")]
    spacings = [float(v) for v in a.spacings.split(",")]
    specs = []
    for w, s, sp in itertools.product(weights, sizes, spacings):
        specs.append(dict(id=f"v_{w}_{s}_{sp}".replace(".", "p").replace("-", "m"), text=a.text, fam=a.fam, w=w, size=s, sp=sp, color=col, bg=a.bg))
    os.makedirs("build/lab", exist_ok=True)
    for f in os.listdir("build/lab"):
        if f.startswith("v_"): os.remove(os.path.join("build/lab", f))
    json.dump(specs, open("build/lab/spec.json", "w"))
    r = subprocess.run(["flutter", "test", "--no-pub", "tool/design/lab/text_lab_test.dart"], capture_output=True, text=True, shell=(os.name == "nt"))
    if "All tests passed" not in r.stdout:
        print(r.stdout[-2000:], r.stderr[-1000:]); sys.exit(1)
    res = []
    for sp in specs:
        v = load(f"build/lab/{sp['id']}.png")
        vd = darkness(v.filter(ImageFilter.GaussianBlur(0.5)), bg)
        vb = ink_box(vd)
        vd = vd[vb[1]:vb[3], vb[0]:vb[2]]
        H = max(vd.shape[0], dd.shape[0]) + 2; W = max(vd.shape[1], dd.shape[1]) + 2
        best = 1e9
        for dy, dx in itertools.product((-1, 0, 1), (-1, 0, 1)):
            A = np.zeros((H, W)); B = np.zeros((H, W))
            A[1:1 + dd.shape[0], 1:1 + dd.shape[1]] = dd
            y = 1 + dy; x = 1 + dx
            ys0, xs0 = max(y, 0), max(x, 0)
            B[ys0:ys0 + vd.shape[0], xs0:xs0 + vd.shape[1]] = vd[: H - ys0, : W - xs0] if False else vd[: min(vd.shape[0], H - ys0), : min(vd.shape[1], W - xs0)]
            best = min(best, np.abs(A - B).mean())
        res.append((best, sp, dd.shape[1] / vd.shape[1], dd.shape[0] / vd.shape[0], dd.sum() / max(vd.sum(), 1)))
    res.sort(key=lambda t: t[0])
    print(f"design ink box {dd.shape[1] / 2:.1f} x {dd.shape[0] / 2:.1f} dp, colour {col}; candidates {len(res)}")
    for sc, sp, wr, hr, ir in res[: a.top]:
        print(f"  score {sc:6.2f}  {a.fam}{sp['w']} size {sp['size']:<6} spacing {sp['sp']:<5}  width x{wr:.3f}  height x{hr:.3f}  ink x{ir:.2f}")
    if not a.keep:
        for sp in specs:
            try: os.remove(f"build/lab/{sp['id']}.png")
            except OSError: pass

if __name__ == "__main__":
    main()
