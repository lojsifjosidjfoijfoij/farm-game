"""Style test: the day scene with the breeze, as a looping GIF (see README.md)."""

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hud  # noqa: E402
import scene  # noqa: E402

FPS, SECONDS, SCALE = 10, 4.8, 2
OUT = os.path.join(HERE, ".out")
os.makedirs(OUT, exist_ok=True)

ground, objects, pools = scene.scene()
overlay = hud.draw((scene.W, scene.H), SCALE)
frames = []
for i in range(int(FPS * SECONDS)):
    img = scene.compose(ground, objects, t=i / FPS)
    world = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    big = world.resize((scene.W * SCALE, scene.H * SCALE), Image.NEAREST)
    big.alpha_composite(overlay)
    frames.append(big.convert("RGB"))
# One shared palette, so colours don't flicker between frames.
palette = frames[0].quantize(colors=255, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
gif = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
gif[0].save(os.path.join(OUT, "style_test_breeze.gif"), save_all=True, append_images=gif[1:],
            duration=int(1000 / FPS), loop=0, optimize=False, disposal=1)
