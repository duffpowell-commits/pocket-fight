#!/usr/bin/env python3
"""Pack a folder of PNGs into one atlas sheet for phones (fewer draw calls, less memory).

Usage: python3 tools/pack_atlas.py SRC_DIR OUT_BASE [--pad 2]
  -> OUT_BASE.png + OUT_BASE.json ({"name": [x, y, w, h]}), read in game with Atlas.tex(OUT_BASE, name).
Shelf packing, tallest first, power-of-two width. Needs Pillow. Runs in the cloud, never on the phone.
"""
import json, os, sys
from PIL import Image

def main():
    args = sys.argv[1:]
    pad = 2
    if "--pad" in args:
        i = args.index("--pad"); pad = int(args[i + 1]); del args[i:i + 2]
    src, out = args
    imgs = []
    for f in sorted(os.listdir(src)):
        if f.lower().endswith(".png"):
            imgs.append((os.path.splitext(f)[0], Image.open(os.path.join(src, f)).convert("RGBA")))
    if not imgs:
        sys.exit("no PNGs in " + src)
    imgs.sort(key=lambda t: -t[1].height)
    area = sum((im.width + pad) * (im.height + pad) for _, im in imgs)
    width = 64
    while width * width < area or width < max(im.width + pad for _, im in imgs):
        width *= 2
    x = y = shelf = 0
    rects = {}
    for name, im in imgs:
        if x + im.width + pad > width:
            x, y, shelf = 0, y + shelf, 0
        rects[name] = [x, y, im.width, im.height]
        x += im.width + pad
        shelf = max(shelf, im.height + pad)
    height = y + shelf
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for name, im in imgs:
        sheet.paste(im, tuple(rects[name][:2]))
    sheet.save(out + ".png")
    with open(out + ".json", "w") as fh:
        json.dump(rects, fh, indent=1, sort_keys=True)
    print("%s.png %dx%d, %d images" % (out, width, height, len(rects)))

if __name__ == "__main__":
    main()
