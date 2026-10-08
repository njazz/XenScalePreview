#!/usr/bin/env python3
"""Fit real screenshots onto App Store Connect's exact sizes, opaque (no alpha), as PNG.

  pip install pillow
  python3 Tools/appstore_screenshots.py mac    shots/*.png      -> AppStore/screenshots/mac/    2880x1800
  python3 Tools/appstore_screenshots.py iphone shots/*.png      -> AppStore/screenshots/iphone/ 1320x2868 (or 2868x1320)
  python3 Tools/appstore_screenshots.py ipad   shots/*.png      -> AppStore/screenshots/ipad/   2064x2752 (or 2752x2064)

Take the screenshots from the real app (Quick Look in Finder / Files, on a Mac, a device or the Simulator):
App Review wants screenshots that show the app in use (guideline 2.3.3). This tool only resizes and pads;
it adds nothing to the picture. Padding uses --bg, or the colour of each screenshot's top-left pixel."""
import argparse, os, sys
from PIL import Image

SIZES = {"mac": [(2880, 1800)], "iphone": [(1320, 2868), (2868, 1320)], "ipad": [(2064, 2752), (2752, 2064)]}

def fit(path, device, bg, margin):
    im = Image.open(path).convert("RGBA")
    sizes = SIZES[device]
    W, H = sizes[0] if im.width * sizes[0][1] >= im.height * sizes[0][0] or len(sizes) == 1 else sizes[1]
    if len(sizes) == 2 and im.width > im.height: W, H = sizes[1]
    if len(sizes) == 2 and im.width <= im.height: W, H = sizes[0]
    color = bg or tuple(im.getpixel((0, 0))[:3])
    scale = min((W * (1 - margin)) / im.width, (H * (1 - margin)) / im.height) if margin else min(W / im.width, H / im.height)
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H), color)
    canvas.paste(im, ((W - im.width) // 2, (H - im.height) // 2), im)   # flattens alpha onto the canvas
    return canvas

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("device", choices=SIZES)
    ap.add_argument("images", nargs="+")
    ap.add_argument("--bg", help="padding colour as #rrggbb (default: each image's top-left pixel)")
    ap.add_argument("--margin", type=float, default=0.0, help="fraction of empty border, e.g. 0.06")
    ap.add_argument("--out", help="output folder (default AppStore/screenshots/<device>)")
    a = ap.parse_args()
    if len(a.images) > 10: sys.exit("App Store Connect takes at most 10 screenshots per device size.")
    bg = tuple(int(a.bg.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) if a.bg else None
    out = a.out or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AppStore", "screenshots", a.device)
    os.makedirs(out, exist_ok=True)
    for i, p in enumerate(a.images, 1):
        img = fit(p, a.device, bg, a.margin)
        dest = os.path.join(out, f"{i:02d}-{os.path.splitext(os.path.basename(p))[0]}.png")
        img.save(dest); print(dest, img.size, img.mode)

if __name__ == "__main__":
    main()
