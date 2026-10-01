"""Contact sheet of rendered sprites on grass, enlarged with crisp pixels.

    python3 art/blender/preview.py out.png name1 name2 ...   (names in .renders/preview)
"""

import os
import sys

from PIL import Image, ImageDraw

PREVIEW = os.path.join(os.path.dirname(__file__), ".renders", "preview")
GRASS = (111, 168, 62, 255)


def sheet(out, names, scale=5, pad=6):
    sprites = [Image.open(os.path.join(PREVIEW, n + ".png")).convert("RGBA") for n in names]
    width = sum(s.width + pad for s in sprites) + pad
    height = max(s.height for s in sprites) + pad * 2 + 6
    canvas = Image.new("RGBA", (width, height), GRASS)
    x = pad
    for s in sprites:
        canvas.alpha_composite(s, (x, height - pad - s.height))
        x += s.width + pad
    big = canvas.resize((width * scale, height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(big)
    x = pad
    for n, s in zip(names, sprites):
        draw.text((x * scale, 2), n, fill=(255, 255, 255, 255))
        x += s.width + pad
    big.save(out)


if __name__ == "__main__":
    sheet(sys.argv[1], sys.argv[2:])
