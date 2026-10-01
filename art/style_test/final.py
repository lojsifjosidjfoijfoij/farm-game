"""Style test: day and night farm yard with the wood-and-paper HUD (see README.md)."""
import os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scene, hud

ground, objects, pools = scene.scene()
out = {}
OUT = os.path.join(HERE, ".out")
os.makedirs(OUT, exist_ok=True)
for night in (False, True):
    img = scene.compose(ground, objects, night=night, pools=pools, fireflies=16)
    world = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    big = world.resize((scene.W * 3, scene.H * 3), Image.NEAREST)
    big.alpha_composite(hud.draw((scene.W, scene.H), 3, night=night))
    name = "style_test_%s.png" % ("night" if night else "day")
    big.convert("RGB").save(os.path.join(OUT, name))
    out[night] = big
# Side by side with a reference screenshot, if given: reference on top, ours below.
if len(sys.argv) < 2:
    sys.exit(0)
ref = Image.open(sys.argv[1]).convert("RGB")
w = 1600
ref = ref.resize((w, int(ref.height * w / ref.width)), Image.LANCZOS)
ours = out[True].convert("RGB").resize((w, int(out[True].height * w / out[True].width)), Image.NEAREST)
sheet = Image.new("RGB", (w, ref.height + ours.height + 12), (20, 20, 20))
sheet.paste(ref, (0, 0))
sheet.paste(ours, (0, ref.height + 12))
sheet.save(os.path.join(OUT, "compare_reference.png"))
