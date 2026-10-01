"""Style test: a wood-and-paper HUD in pixel art, drawn at the world's pixel
scale (then enlarged with it), with text set crisply at screen resolution."""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "fonts", "Fredoka.ttf")
if not os.path.exists(FONT):  # see README.md; any bold font will do for a look
    FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


PAL = {
    "k": hexc("2e1e14"), "w": hexc("a8743f"), "W": hexc("cf9a5c"), "v": hexc("7a4a26"),
    "s": hexc("9aa4ad"), "S": hexc("d6dde2"), "d": hexc("5d6670"),
    "y": hexc("f0b83a"), "Y": hexc("ffe07a"), "o": hexc("b97a1e"),
    "g": hexc("5aa83a"), "G": hexc("8fd45a"), "e": hexc("2f6e2a"),
    "b": hexc("4a90d8"), "B": hexc("8cc4f2"), "n": hexc("2a5a9a"),
    "r": hexc("d84a3a"), "R": hexc("f08070"),
    "p": hexc("f3e6c4"), "t": hexc("c8a46a"), "T": hexc("8a6a3e"),
    "h": hexc("f0c090"), "H": hexc("c08a5a"),
}

ICONS = {
    "coin": """
...kkkkk...
..kYYYyyk..
.kYYyyyyok.
kYyyYYyyyok
kYyYyyyyyok
kYyYyyyyyok
kYyyyyyyyok
kyyyyyyyook
.kyyyyyook.
..koooook..
...kkkkk...
""",
    "bolt": """
......kkkk
.....kYYk.
....kYYk..
...kYYk...
..kYYYkkk.
.kYYYYYYk.
.kkkkYYk..
....kYk...
...kYk....
..kYk.....
..kk......
""",
    "star": """
.....k.....
....kYk....
....kYk....
kkkkYYykkkk
kYYYYyyyyok
.kYyyyyyok.
..kyyyyyk..
..kyyoyyk..
.kyyk.kyok.
.kok...kok.
.kk.....kk.
""",
    "sun": """
.....y.....
.y...y...y.
..y.kkk.y..
...kYYyk...
..kYYyyyk..
yykYyyyykyy
..kyyyyok..
...kyyok...
..y.kkk.y..
.y...y...y.
.....y.....
""",
    "moon": """
....kkk....
..kkYYk....
.kYYyk.....
.kYyk......
kYyyk......
kYyyk......
kYyyyk.....
.kyyyykk.kk
.kooyyyykk.
..kkoooook.
....kkkkk..
""",
    "hoe": """
......kkkkk.
.....kSSssdk
.....kssssdk
......kkksdk
.......kwkdk
......kwk.k.
.....kwk....
....kwk.....
...kwk......
..kwk.......
.kwk........
.kk.........
""",
    "seeds": """
....kkkk....
...kTttTk...
....kttk....
...ktpptk...
..kppppppk..
.kpptgGtppk.
.kptgGGgtpk.
.kpptggtppk.
.kpppttpppk.
.kTpppppptk.
..kTTTTTTk..
...kkkkkk...
""",
    "can": """
.....kkk....
....k...k...
...kbbbbbk..
kk.kBBbbbnk.
kbkkBbbbbnk.
.kbbbbbbbnk.
..kbbbbbbnk.
...kbbbbbnk.
...knnnnnnk.
....kkkkkk..
""",
    "sickle": """
....kkkkk...
...kSSSssk..
..kSsk..kdk.
..ksk....kk.
..ksk.......
...ksk......
....ksdk....
.....kwwk...
......kwk...
.......kwk..
........kwk.
.........kk.
""",
    "hand": """
....k.k.....
...khkhk.k..
...khkhkhk..
.k.khkhkhk..
khkkhhhhhk..
khhkhhhhhk..
.khhhhhhhk..
..khhhhhHk..
...khhhHk...
....kHHk....
....kkkk....
""",
    "basket": """
...kkkkkk...
..kw....wk..
.kw......wk.
kkkkkkkkkkkk
kWWWWWWWWWWk
kwWwWwWwWwwk
.kwwwwwwwwk.
.kWwWwWwWwk.
..kwwwwwwk..
..kkkkkkkk..
""",
    "phone": """
..kkkkkk..
.kddddddk.
.kdBBBBdk.
.kdBbbBdk.
.kdBbbBdk.
.kdBBBBdk.
.kddddddk.
.kddSSddk.
.kddddddk.
..kkkkkk..
""",
}


def icon2(img, name, x, y):
    """An icon at twice the size, centred on x, y (for buttons you tap)."""
    rows = ICONS[name].strip("\n").split("\n")
    w, h = max(len(r) for r in rows), len(rows)
    tmp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    icon(tmp, name, 0, 0)
    tmp = tmp.resize((w * 2, h * 2), Image.NEAREST)
    img.alpha_composite(tmp, (x - w, y - h))


def icon(img, name, x, y):
    rows = ICONS[name].strip("\n").split("\n")
    px = img.load()
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != "." and 0 <= x + i < img.width and 0 <= y + j < img.height:
                px[x + i, y + j] = PAL[ch]
    return max(len(r) for r in rows), len(rows)


WOOD = {"out": hexc("3a2416"), "hi": hexc("d79a58"), "mid": hexc("b0723c"), "lo": hexc("8a5428"),
        "seam": hexc("6e4222"), "in": hexc("5a3a20"), "paper": hexc("f2e4c0"), "paper_sh": hexc("d8c69c"),
        "nail": hexc("e2d8bc"), "nail_sh": hexc("8a7a62")}


def panel(img, x, y, w, h, paper=True, band=3, seed=0):
    """A wooden frame (planks, nails), paper inside."""
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed)
    d.rectangle([x + 1, y, x + w - 2, y + h - 1], fill=WOOD["out"])
    d.rectangle([x, y + 1, x + w - 1, y + h - 2], fill=WOOD["out"])
    d.rectangle([x + 1, y + 1, x + w - 2, y + h - 2], fill=WOOD["mid"])
    d.line([x + 2, y + 1, x + w - 3, y + 1], fill=WOOD["hi"])
    d.line([x + 1, y + 2, x + 1, y + h - 3], fill=WOOD["hi"])
    d.line([x + 2, y + h - 2, x + w - 3, y + h - 2], fill=WOOD["lo"])
    d.line([x + w - 2, y + 2, x + w - 2, y + h - 3], fill=WOOD["lo"])
    # Plank seams along the top and bottom bands.
    sx = x + 6 + int(rng.integers(0, 8))
    while sx < x + w - 6:
        d.line([sx, y + 1, sx, y + band], fill=WOOD["seam"])
        d.line([sx + 5, y + h - 1 - band, sx + 5, y + h - 2], fill=WOOD["seam"])
        sx += int(rng.integers(14, 22))
    if paper:
        ix0, iy0, ix1, iy1 = x + band + 1, y + band + 1, x + w - band - 2, y + h - band - 2
        d.rectangle([ix0 - 1, iy0 - 1, ix1 + 1, iy1 + 1], fill=WOOD["in"])
        d.rectangle([ix0, iy0, ix1, iy1], fill=WOOD["paper"])
        d.line([ix0, iy0, ix1, iy0], fill=WOOD["paper_sh"])
        d.line([ix0, iy0, ix0, iy1], fill=WOOD["paper_sh"])
        # A few paper fibres.
        for _ in range(int((ix1 - ix0) * (iy1 - iy0) / 60)):
            fx, fy = int(rng.integers(ix0 + 1, ix1)), int(rng.integers(iy0 + 1, iy1))
            img.putpixel((fx, fy), hexc("e9d8ae"))
    for nx, ny in ((x + 2, y + 2), (x + w - 4, y + 2), (x + 2, y + h - 4), (x + w - 4, y + h - 4)):
        if band >= 3:
            img.putpixel((nx, ny), WOOD["nail"])
            img.putpixel((nx + 1, ny + 1), WOOD["nail_sh"])


def bar(img, x, y, w, frac, fill="y", dark="o"):
    d = ImageDraw.Draw(img)
    d.rectangle([x, y, x + w, y + 4], fill=WOOD["out"])
    d.rectangle([x + 1, y + 1, x + w - 1, y + 3], fill=hexc("d8c69c"))
    end = x + 1 + int((w - 2) * frac)
    d.rectangle([x + 1, y + 1, end, y + 3], fill=PAL[fill])
    d.line([x + 1, y + 3, end, y + 3], fill=PAL[dark])


def draw(size, scale, selected="hoe", night=False):
    """Returns (HUD image at screen size, list of text jobs)."""
    W, H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    texts = []
    # Top left: level, money, energy.
    panel(img, 5, 5, 214, 28, seed=1)
    icon(img, "star", 12, 13)
    texts.append((26, 10, "3", 34))
    bar(img, 36, 21, 30, 0.6)
    icon(img, "coin", 76, 13)
    texts.append((90, 10, "1,240", 34))
    icon(img, "bolt", 150, 13)
    texts.append((163, 10, "84", 34))
    bar(img, 182, 17, 28, 0.84, fill="G", dark="e")
    # Top centre: the goal.
    panel(img, 226, 5, 226, 28, seed=2)
    texts.append((236, 10, "Plow the first field: 3 of 6", 30))
    # Top right: day and time, then the menu.
    panel(img, 459, 5, 128, 28, seed=3)
    icon(img, "moon" if night else "sun", 467, 13)
    texts.append((482, 10, "Day 4 · 21:40" if night else "Day 4 · 9:40", 30))
    panel(img, 593, 5, 42, 28, paper=False, seed=4)
    d = ImageDraw.Draw(img)
    for k in range(3):
        d.rectangle([604, 12 + k * 5, 623, 13 + k * 5], fill=WOOD["out"])
        d.line([605, 12 + k * 5, 622, 12 + k * 5], fill=WOOD["hi"])
    # Bottom centre: the tool belt.
    tools = ["hand", "hoe", "seeds", "can", "sickle"]
    slot, step = 34, 37
    bw = 5 * step + 9
    bx, by = (W - bw) // 2, H - 46
    panel(img, bx, by, bw, 42, paper=False, seed=5)
    for i, t in enumerate(tools):
        sx = bx + 6 + i * step
        sy = by + 6 - (4 if t == selected else 0)
        d.rectangle([sx, sy, sx + slot, sy + 30], fill=WOOD["out"])
        d.rectangle([sx + 1, sy + 1, sx + slot - 1, sy + 29], fill=WOOD["paper"] if t != selected else hexc("ffe9b8"))
        d.line([sx + 1, sy + 1, sx + slot - 1, sy + 1], fill=WOOD["paper_sh"])
        if t == selected:
            d.rectangle([sx - 1, sy - 1, sx + slot + 1, sy + 31], outline=hexc("e27a16"))
        icon2(img, t, sx + slot // 2 + 1, sy + 15)
    # Bottom right: phone and basket.
    for k, (name, x) in enumerate((("phone", W - 92), ("basket", W - 48))):
        panel(img, x, H - 46, 42, 42, paper=True, band=3, seed=6 + k)
        icon2(img, name, x + 21, H - 25)
    big = img.resize((W * scale, H * scale), Image.NEAREST)
    dd = ImageDraw.Draw(big)
    for (x, y, text, pt) in texts:
        font = ImageFont.truetype(FONT, pt)
        try:
            font.set_variation_by_name("SemiBold")
        except Exception:
            pass
        dd.text((x * scale, y * scale - 2), text, font=font, fill=hexc("4a2e1a"))
    return big
