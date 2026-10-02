"""Generates the wood-and-paper HUD as pixel art, straight into the asset
catalog: stretchable frames (wooden panel with paper inside, a wooden board,
paper slots, painted board buttons) and the HUD's icons.

    uv run --with pillow --with numpy python art/hud/make_hud.py

Frames are drawn at art scale, then saved twice as big, so one art pixel is
2 points on screen (the world's pixel size at the normal zoom); the game
stretches them with fixed corners (cap insets = 2 × the art insets below).
Icons are 12 × 12 art pixels, saved as they are: the game draws them at
24 points (2 points per pixel, like everything else) with no smoothing.
"""

import json
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
G = 12  # icon grid, in art pixels
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CATALOG = os.environ.get("ACRES_ART_CATALOG") or os.path.join(REPO, "Acres", "Resources", "Assets.xcassets", "Art")


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


PAL = {
    "k": hexc("2e1e14"), "w": hexc("a8743f"), "W": hexc("cf9a5c"), "v": hexc("7a4a26"),
    "s": hexc("9aa4ad"), "S": hexc("d6dde2"), "d": hexc("5d6670"),
    "y": hexc("f0b83a"), "Y": hexc("ffe07a"), "o": hexc("b97a1e"),
    "g": hexc("5aa83a"), "G": hexc("8fd45a"), "e": hexc("2f6e2a"),
    "b": hexc("4a90d8"), "B": hexc("8cc4f2"), "n": hexc("2a5a9a"),
    "r": hexc("d84a3a"), "R": hexc("f08070"), "m": hexc("9a2a22"),
    "p": hexc("f3e6c4"), "t": hexc("c8a46a"), "T": hexc("8a6a3e"),
    "h": hexc("f0c090"), "H": hexc("c08a5a"),
    "c": hexc("f4f6fa"), "C": hexc("c4cede"), "x": hexc("8a8f98"),
    "L": hexc("8a4a2a"), "M": hexc("5e2f1a"), "N": hexc("b06a3e"),
    "P": hexc("f6b0c8"), "Q": hexc("d8709a"), "O": hexc("f2a33a"), "q": hexc("c85a1c"),
}
WOOD = {"out": hexc("3a2416"), "hi": hexc("d79a58"), "mid": hexc("b0723c"), "lo": hexc("8a5428"),
        "seam": hexc("6e4222"), "in": hexc("5a3a20"), "paper": hexc("f2e4c0"), "paper_sh": hexc("d8c69c"),
        "fibre": hexc("e9d8ae"), "nail": hexc("e2d8bc"), "nail_sh": hexc("8a7a62")}


# ------------------------------------------------------------------- frames

def frame(w, h, inner="paper", seams=(), seed=0):
    """A slim wooden frame: outline, two rows of board (lit at the top and
    left, shaded at the bottom and right), a dark inner line, then paper or
    planks. The corners and the 5-pixel border stay fixed when stretched."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 0, w - 2, h - 1], fill=WOOD["out"])
    d.rectangle([0, 1, w - 1, h - 2], fill=WOOD["out"])
    d.rectangle([1, 1, w - 2, h - 2], fill=WOOD["mid"])
    d.line([2, 1, w - 3, 1], fill=WOOD["hi"])
    d.line([1, 2, 1, h - 3], fill=WOOD["hi"])
    d.line([2, h - 2, w - 3, h - 2], fill=WOOD["lo"])
    d.line([w - 2, 2, w - 2, h - 3], fill=WOOD["lo"])
    for x in seams:
        d.line([x, 1, x, 2], fill=WOOD["seam"])
        d.line([x + 7, h - 3, x + 7, h - 2], fill=WOOD["seam"])
    d.rectangle([3, 3, w - 4, h - 4], fill=WOOD["in"])
    if inner == "paper":
        d.rectangle([4, 4, w - 5, h - 5], fill=WOOD["paper"])
        d.line([4, 4, w - 5, 4], fill=WOOD["paper_sh"])
        d.line([4, 4, 4, h - 5], fill=WOOD["paper_sh"])
        rng = np.random.default_rng(seed)
        for _ in range((w - 10) * (h - 10) // 40):
            img.putpixel((int(rng.integers(6, w - 6)), int(rng.integers(6, h - 6))), WOOD["fibre"])
    else:  # planks across, a seam every 5 px
        d.rectangle([4, 4, w - 5, h - 5], fill=WOOD["mid"])
        for y in range(4, h - 4):
            if (y - 4) % 5 == 4:
                d.line([4, y, w - 5, y], fill=WOOD["seam"])
            elif (y - 4) % 5 == 0:
                d.line([4, y, w - 5, y], fill=WOOD["hi"])
    return img


def leather(w=42, h=18, seed=2):
    """A leather band (the farm journal's cover): an outline, a lit top edge,
    a little grain, and light stitching just inside the edge (2 on, 2 off,
    so it repeats cleanly when the band stretches)."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 0, w - 2, h - 1], fill=WOOD["out"])
    d.rectangle([0, 1, w - 1, h - 2], fill=WOOD["out"])
    d.rectangle([1, 1, w - 2, h - 2], fill=PAL["L"])
    d.line([2, 1, w - 3, 1], fill=PAL["N"])
    d.line([2, h - 2, w - 3, h - 2], fill=PAL["M"])
    rng = np.random.default_rng(seed)
    for _ in range(w * h // 9):
        img.putpixel((int(rng.integers(2, w - 2)), int(rng.integers(2, h - 2))), PAL["M"])
    stitch = hexc("d8b47a")
    for x in range(3, w - 3):
        if (x - 3) % 4 < 2:
            img.putpixel((x, 3), stitch)
            img.putpixel((x, h - 4), stitch)
    for y in range(3, h - 3):
        if (y - 3) % 4 < 2:
            img.putpixel((3, y), stitch)
            img.putpixel((w - 4, y), stitch)
    return img


def paper_tile(n=48, seed=5):
    """Plain paper that tiles seamlessly (menu backgrounds): fibres and specks, no gradient."""
    img = Image.new("RGBA", (n, n), WOOD["paper"])
    rng = np.random.default_rng(seed)
    for _ in range(n * n // 14):
        img.putpixel((int(rng.integers(0, n)), int(rng.integers(0, n))), WOOD["fibre"])
    for _ in range(n * n // 90):
        img.putpixel((int(rng.integers(0, n)), int(rng.integers(0, n))), hexc("e0cc9e"))
    for _ in range(n // 6):  # a few short fibres
        x, y = int(rng.integers(0, n)), int(rng.integers(0, n))
        for k in range(int(rng.integers(2, 4))):
            img.putpixel(((x + k) % n, y), hexc("e4d2a6"))
    return img


def card():
    """A card on the menu paper: lighter paper, a thin ink-brown outline, a
    lit top edge and a short drop below (border 4 px)."""
    w, h = 24, 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    drop = (58, 36, 22, 90)
    d.rectangle([2, h - 2, w - 2, h - 1], fill=drop)
    d.rectangle([1, 0, w - 2, h - 3], fill=hexc("6a4a2e"))
    d.rectangle([0, 1, w - 1, h - 4], fill=hexc("6a4a2e"))
    d.rectangle([1, 1, w - 2, h - 4], fill=hexc("f8eed6"))
    d.line([2, 1, w - 3, 1], fill=hexc("fffaf0"))
    d.line([1, h - 4, w - 2, h - 4], fill=hexc("e6d6b0"))
    return img


def inset():
    """A sunken panel of darker paper (lists inside a card): shadowed top-left, lit bottom-right."""
    w, h = 16, 16
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 0, w - 2, h - 1], fill=hexc("c9b48a"))
    d.rectangle([0, 1, w - 1, h - 2], fill=hexc("c9b48a"))
    d.rectangle([1, 1, w - 2, h - 2], fill=hexc("e9d9b4"))
    d.line([1, 1, w - 2, 1], fill=hexc("d4c196"))
    d.line([1, 1, 1, h - 2], fill=hexc("d4c196"))
    d.line([1, h - 2, w - 2, h - 2], fill=hexc("f6ead0"))
    return img


def ribbon(colour, light, dark):
    """A cloth ribbon with notched ends (titles on cards and celebrations)."""
    w, h = 40, 18
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    notch = 5
    # The ends tuck behind: darker tails with a notch.
    for side in (0, 1):
        x0, x1 = (0, 9) if side == 0 else (w - 10, w - 1)
        d.rectangle([x0, 3, x1, h - 1], fill=dark)
        for y in range(3, h):
            depth = notch - abs(y - (3 + h - 1) // 2) * notch // ((h - 3) // 2)
            for k in range(max(0, depth)):
                x = x0 + k if side == 0 else x1 - k
                img.putpixel((x, y), (0, 0, 0, 0))
    # The front band, outlined.
    d.rectangle([5, 0, w - 6, h - 4], fill=WOOD["out"])
    d.rectangle([6, 1, w - 7, h - 5], fill=colour)
    d.line([6, 1, w - 7, 1], fill=light)
    d.line([6, h - 5, w - 7, h - 5], fill=dark)
    return img


TINTS = {  # board and ribbon colours: (paint, lit edge, shade)
    "green": ("5aa83a", "8fd45a", "3c7a26"), "gold": ("e8a92c", "ffd36a", "a8700c"),
    "red": ("d84a3a", "f08070", "9a2a22"), "blue": ("4a90d8", "8cc4f2", "2a5a9a"),
    "wood": ("a8743f", "cf9a5c", "6e4222"), "gray": ("9a948a", "bdb7ab", "6e695f"),
}


def slot(selected=False):
    """A paper slot for the tool belt; the chosen one has an orange edge."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    edge = hexc("e27a16") if selected else WOOD["out"]
    d.rectangle([1, 0, 14, 15], fill=edge)
    d.rectangle([0, 1, 15, 14], fill=edge)
    if selected:
        d.rectangle([1, 1, 14, 14], fill=hexc("f5a04a"))
    d.rectangle([2, 2, 13, 13], fill=hexc("ffe9b8") if selected else WOOD["paper"])
    d.line([2, 2, 13, 2], fill=WOOD["paper_sh"])
    d.line([2, 2, 2, 13], fill=WOOD["paper_sh"])
    return img


def board(colour, light, dark):
    """A painted board button: notched corners, a lit top edge, a darker bottom it presses into."""
    w, h = 24, 20
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 0, w - 2, h - 1], fill=WOOD["out"])
    d.rectangle([0, 1, w - 1, h - 2], fill=WOOD["out"])
    d.rectangle([1, 1, w - 2, h - 2], fill=dark)
    d.rectangle([1, 1, w - 2, h - 5], fill=colour)
    d.line([2, 1, w - 3, 1], fill=light)
    d.line([1, 2, 1, h - 6], fill=light)
    return img


# -------------------------------------------------------------------- icons

ASCII = {
    "ui_icon_bag": """
....kkkk....
...kk..kk...
...k....k...
.kkkkkkkkkk.
kttttttttttk
kTtttttttttk
kTttrrrrtttk
kTttrrrrtttk
kTtttttttttk
kTtttttttTtk
.kTTTTTTTTk.
..kkkkkkkk..
""",
    "ui_icon_tuck": """
......kk....
.....kppk...
....kppk....
...kppk.....
..kppk......
..kppk......
...kppk.....
....kppk....
.....kppk...
......kk....
""",
    "ui_icon_close": """
.kk......kk.
kppk....kppk
kpppk..kpppk
.kpppkkpppk.
..kppppppk..
...kppppk...
...kppppk...
..kppppppk..
.kpppkkpppk.
kpppk..kpppk
kppk....kppk
.kk......kk.
""",
    "ui_icon_goals": """
....kkkk....
.kkkdSSdkkk.
kwwkkkkkkwwk
kwppppppppwk
kwpGgpTTTpwk
kwpggpppppwk
kwppppppppwk
kwpGgpTTTpwk
kwpggpppppwk
kwppppppppwk
kwvvvvvvvvwk
kkkkkkkkkkkk
""",
    "ui_icon_lock": """
...kkkkkk...
..kSddddSk..
..kdk..kdk..
..ksk..ksk..
.kkkkkkkkkk.
.kYyyyyyyok.
.kyyykkyyok.
.kyyykkyyok.
.kyyyykyyok.
.kyyyyyyyok.
.kooooooook.
.kkkkkkkkkk.
""",
    "ui_icon_unlock": """
.kkkkkk.....
kSddddSk....
kdk..kdk....
ksk..ksk....
ksk.........
.kkkkkkkkkk.
.kYyyyyyyok.
.kyyykkyyok.
.kyyyykyyok.
.kyyyyyyyok.
.kooooooook.
.kkkkkkkkkk.
""",
    "ui_icon_gift": """
..kk....kk..
.kyYk..kYyk.
.kyyYkkYyyk.
..kkkyykkk..
kkkkkyykkkkk
kRRRRYYRRRRk
krrrryyrrrrk
kkkkkyykkkkk
.krrryyrrrk.
.krrryyrrmk.
.kmmmyommmk.
.kkkkkkkkkk.
""",
    "ui_icon_truck": """
....kkkkk...
....kBBBrk..
....kBBnrrk.
kkkkkrrrrrrk
kRRRRRRRRRRk
krrrrrrrrrYk
kmkkkmmkkkmk
.kxSxkkxSxk.
..kkk..kkk..
""",
    "ui_icon_blossom": """
....kkkk....
...kPPPQk...
.kkkPPPQkkk.
kPPPkPQkPPQk
kPPPPkkPPPQk
kQPPkYykPQQk
.kQQkyokQQk.
.kPPPkkPPPk.
kPPPQkkPPPQk
kPPQk..kPQQk
.kkk....kkk.
""",
    "ui_icon_snowflake": """
....kck....
..k.kck.k..
.kckkckkck.
..kckckck..
kkkkcccdkkk
kccccBccccd
kkkkcccdkkk
..kckckck..
.kckkckkck.
..k.kck.k..
....kck....
""",
    "ui_icon_shop": """
kkkkkkkkkkkk
kRcRcRcRcRck
krcrcrcrcrck
.kkkkkkkkkk.
.kwwwwwwwwk.
.kwBBkwppwk.
.kwBnkwppwk.
.kwkkkwpTwk.
.kwwwwwppwk.
.kvvvvvppvk.
.kkkkkkkkkk.
""",
    "ui_icon_bank": """
.....kk.....
...kkSSkk...
.kkSSSSSSkk.
kSSSSSSSSSSk
kddddddddddk
kkkkkkkkkkkk
kSdkkSdkkSdk
kSdkkSdkkSdk
kSdkkSdkkSdk
kSdkkSdkkSdk
kSSSSSSSSSdk
kkkkkkkkkkkk
""",
    "ui_icon_hammer": """
kkkkkkkkkk..
kSSSSSSssdk.
kssssssdddk.
kkkkkwwkkkk.
....kwwk....
....kwwk....
....kwwk....
....kwvk....
....kwvk....
....kvvk....
....kkkk....
""",
    "ui_icon_trophy": """
..kkkkkkkk..
kkkYYyyyokkk
k.kYyyyyok.k
k.kYyyyyok.k
.kkYyyyyokk.
...kyyyok...
....kyok....
....kyok....
...kkkkkk...
..kYyyyyok..
..kooooook..
..kkkkkkkk..
""",
    "ui_icon_rosette": """
...kkkkkk...
..kYYyyyok..
..kYyyyyok..
..kyyyyyok..
..kyyyyook..
...kooook...
...kkkkkk...
..kbbkkrrk..
.kbbk..krrk.
.kbnk..kmrk.
.kbkk..kkrk.
.kk......kk.
""",
    "ui_icon_house": """
.....kk.....
....kRRk....
...kRrrrk...
..kRrrrrrk..
.kRrrrrrrrk.
kkkkkkkkkkkk
.kppppppppk.
.kpBBpwwppk.
.kpBnpwwppk.
.kppppwwppk.
.kTTTTwvTTk.
.kkkkkkkkkk.
""",
    "ui_icon_crate": """
kkkkkkkkkkkk
kWWWWWWWWWWk
kWkkkkkkkkWk
kWkwwwwwWkWk
kWkwwwwWvkWk
kWkwwwWvwkWk
kWkwwWvwwkWk
kWkwWvwwwkWk
kWkWvwwwwkWk
kWkkkkkkkkWk
kvvvvvvvvvvk
kkkkkkkkkkkk
""",
    "ui_icon_leaf": """
........kkkk
......kkGGgk
.....kGGGgek
....kGGGgegk
...kGGGgeggk
...kGGgeggk.
..kGGgeggek.
..kGgeggek..
..kgeggeek..
..kegeekk...
.kekkkk.....
kk..........
""",
    "ui_icon_tree": """
....kkkk....
..kkGGggkk..
.kGGGgggggk.
kGGGgggggeek
kGGgggggggek
kGggggggggek
kgggggggeeek
.kggggeeeek.
..kkkwwkkk..
....kwvk....
....kwvk....
...kkkkkk...
""",
    "ui_icon_drop": """
.....kk.....
....kBbk....
....kBbk....
...kBbbbk...
...kBbbbk...
..kBbbbbbk..
.kBcbbbbbnk.
.kBcbbbbbnk.
.kBbbbbbbnk.
..kbbbbbnk..
...knnnnk...
....kkkk....
""",
    "ui_icon_heart": """
.kkkk..kkkk.
kRRrrkkRrrrk
kRrrrrrrrrmk
kRrrrrrrrrmk
krrrrrrrrrmk
.krrrrrrrmk.
..krrrrrmk..
...krrrmk...
....krmk....
.....kk.....
""",
    "ui_icon_bill": """
.kkkkkkkkkk.
.kppppppppk.
.kpTTTTTTpk.
.kppppppppk.
.kpTTTTTppk.
.kppppppppk.
.kpTTTTTTpk.
.kppppppppk.
.kpTTTpprpk.
.kppppprrpk.
.kttttttttk.
.kkkkkkkkkk.
""",
    "ui_icon_signpost": """
.kkkkkkkkk..
.kWWWWWWWWk.
.kwwwwwwwwwk
.kvvvvvvvvk.
.kkkkkkkkk..
....kwvk....
....kwvk....
....kwvk....
...kGwvGk...
..kGGgggGk..
..kkkkkkkk..
""",
    "ui_icon_field": """
kkkkkkkkkkkk
ktGttGttGttk
kTgTTgTTgTTk
kvvvvvvvvvvk
kttGttGttGtk
kTTgTTgTTgTk
kvvvvvvvvvvk
ktGttGttGttk
kTgTTgTTgTTk
kvvvvvvvvvvk
kttttttttttk
kkkkkkkkkkkk
""",
    "ui_icon_flame": """
......k.....
.....krk....
....krrk....
...krRrk.k..
...krRrrkrk.
..krRYrrrrk.
..krRYYrrrk.
.krRYYYYrmk.
.krYYYyYrmk.
.krYyyyYrmk.
..kmYyyrmk..
...kkkkkk...
""",
    "ui_icon_fish": """
...kkkkk....
..kBBBBBk.kk
.kBkBBBbbkbk
kBBBBBbbbbbk
.kbbbbbbnkbk
..knnnnnk.kk
...kkkkk....
""",
    "ui_icon_bowl": """
..C..C..C...
...C..C..C..
..C..C..C...
kkkkkkkkkkkk
kyYyyyyyyyok
kRrrrrrrrrmk
.krrrrrrrmk.
..kmmmmmmk..
...kkkkkk...
""",
    "ui_icon_bread": """
...kkkkkk...
.kkWWWWWWkk.
kWWWvWWvWWWk
kWWvWWvWWvwk
kwwwwwwwwwvk
.kvvvvvvvvk.
..kkkkkkkk..
""",
    "ui_icon_worker": """
....kkkk....
...kYYyyk...
.kkYYyyyokk.
kYYyyyyyyyok
kkkkkkkkkkkk
..khhhhhhk..
..khkhhkhk..
..khhhhhHk..
...khhhHk...
..kgkkkkgk..
.kgGgggggek.
.kkkkkkkkkk.
""",
    "ui_icon_hen": """
..kkk.......
.krrrk......
..kccck.....
.kcckck..kk.
kycccck.kck.
.kkccckkcck.
..kccccccck.
..kcccccCCk.
...kcccCCk..
....kkkkk...
.....y.y....
....yy.yy...
""",
    "ui_icon_hoe": """
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
    "ui_icon_seeds": """
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
    "ui_icon_watering_can": """
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
    "ui_icon_sickle": """
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
    "ui_icon_hand": """
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
    "ui_icon_axe": """
....kkk.....
...kSSsk....
..kSssdk....
..kSsdkwk...
..kssdkwk...
...kdkkwk...
....k.kwk...
......kwk...
......kwk...
......kwk...
......kvk...
......kkk...
""",
    "ui_icon_rod": """
.........kk.
........kwk.
.......kwk.k
......kwk..k
.....kwk...k
....kwk....k
...kwk.....k
..kwk.....krk
.kvk......kck
.kk........k.
""",
    "ui_icon_inventory": """
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
    "ui_icon_journal": """
.kkkkkkkkkk.
kMLLLLLLLLNk
kMLNNNNNNLLk
kMLNppppNLLk
kMLNpTTpNLLk
kMLNppppNLLk
kMLNNNNNNLLk
kMLLLLLLLLLk
kMLLLLLLLLLk
kMpppppppppk
.kkkkkkrkkk.
.......rr...
""",
    "ui_icon_bed": """
kk..........
kwk.........
kwkkkkkkkkkk
kwkccCkRRRRk
kwkcCCkRrrrk
kwkkkkkrrrrk
kwwwwwwwwwwk
kvvvvvvvvvvk
kvk......kvk
kk........kk
""",
    "ui_icon_map": """
.kkk.kkk.kkk
kpptkGgkpptk
kpptkGgkprtk
kpptkggkpptk
kptpkgGkptpk
kpptkGgkpptk
kprtkggkpptk
kpptkGgkpptk
.kkk.kkk.kkk
""",
    "ui_icon_energy": """
.....kkkk.
....kYYk..
...kYYk...
..kYYk....
.kYYYkkk..
kYYYYYYYk.
.kkkkYYk..
....kYk...
...kYk....
..kYk.....
..kk......
""",
    "ui_icon_fuel": """
..kkkk.....
.kk..kkkkk.
.k..krrrrrk
.kkkkRRrrrk
..krrRrrrmk
..krRrrrrmk
..krrrrrrmk
..krrrrrrmk
..kmmmmmmmk
...kkkkkkk.
""",
}


def from_ascii(art):
    rows = art.strip("\n").split("\n")
    h, w = len(rows), max(len(r) for r in rows)
    img = Image.new("RGBA", (G, G), (0, 0, 0, 0))
    ox, oy = (G - w) // 2, (G - h) // 2
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ".":
                img.putpixel((ox + i, oy + j), PAL[ch])
    return img


def shaded(mask, fill, light, dark):
    """A filled shape with a dark outline, lit up and to the left, shaded down and to the right."""
    m = np.asarray(mask) > 0
    out = np.zeros((G, G, 4), np.uint8)
    out[m] = fill
    up_left = np.zeros_like(m)
    up_left[1:, 1:] = ~m[:-1, 1:] | ~m[1:, :-1]
    up_left[0, :] = True
    up_left[:, 0] = True
    down_right = np.zeros_like(m)
    down_right[:-1, :-1] = ~m[1:, :-1] | ~m[:-1, 1:]
    down_right[-1, :] = True
    down_right[:, -1] = True
    out[m & up_left] = light
    out[m & down_right & ~up_left] = dark
    edge = np.zeros_like(m)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        edge |= np.roll(np.roll(m, dy, 0), dx, 1)
    edge &= ~m
    out[edge] = PAL["k"]
    return Image.fromarray(out, "RGBA")


def mask(draw_fn):
    m = Image.new("L", (G, G), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def star_points(cx, cy, r_out, r_in, n=5, rot=-np.pi / 2):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * np.pi / n
        pts.append((cx + r * np.cos(a), cy + r * np.sin(a)))
    return pts


def coin():
    img = shaded(mask(lambda d: d.ellipse([1, 1, 10, 10], fill=255)), PAL["y"], PAL["Y"], PAL["o"])
    ImageDraw.Draw(img).rectangle([5, 4, 6, 7], fill=PAL["o"])  # a stamped bar across the middle
    return img


def star():
    return shaded(mask(lambda d: d.polygon(star_points(5.5, 6.2, 5.7, 2.5), fill=255)), PAL["y"], PAL["Y"], PAL["o"])


def sun(low=False):
    img = Image.new("RGBA", (G, G), (0, 0, 0, 0))
    body = shaded(mask(lambda d: d.ellipse([3, 3, 8, 8], fill=255)), PAL["y"], PAL["Y"], PAL["o"])
    d = ImageDraw.Draw(img)
    for (x0, y0, x1, y1) in ((5, 0, 6, 0), (5, 11, 6, 11), (0, 5, 0, 6), (11, 5, 11, 6),
                             (1, 1, 1, 1), (10, 1, 10, 1), (1, 10, 1, 10), (10, 10, 10, 10)):
        d.rectangle([x0, y0, x1, y1], fill=PAL["o"])
    img.alpha_composite(body)
    if low:  # sunrise / sunset: the horizon cuts it
        a = np.asarray(img).copy()
        a[8:] = 0
        img = Image.fromarray(a, "RGBA")
        ImageDraw.Draw(img).line([0, 8, 11, 8], fill=PAL["T"])
    return img


def moon():
    def draw(d):
        d.ellipse([1, 1, 10, 10], fill=255)
        d.ellipse([4, -1, 12, 7], fill=0)
    return shaded(mask(draw), PAL["Y"], hexc("fff3b8"), PAL["y"])


def cloud(extra=None):
    def draw(d):
        d.ellipse([0, 4, 5, 9], fill=255)
        d.ellipse([3, 1, 8, 7], fill=255)
        d.ellipse([6, 3, 11, 9], fill=255)
        d.rectangle([2, 6, 9, 9], fill=255)
    img = shaded(mask(draw), PAL["c"], PAL["c"], PAL["C"])
    if extra:
        a = np.asarray(img).copy()
        a[10:] = 0
        img = Image.fromarray(a, "RGBA")
        d = ImageDraw.Draw(img)
        for x in (3, 6, 9):
            if extra == "rain":
                d.line([x, 10, x - 1, 11], fill=PAL["b"])
            else:
                d.point([(x, 11), (x - 1, 11), (x + 1, 11), (x, 10)], fill=PAL["c"])
    return img


def gear():
    def draw(d):
        d.ellipse([2, 2, 9, 9], fill=255)
        for box in ((5, 1, 6, 10), (1, 5, 10, 6)):
            d.rectangle(box, fill=255)
        for (x, y) in ((2, 2), (8, 2), (2, 8), (8, 8)):
            d.rectangle([x, y, x + 1, y + 1], fill=255)
        d.rectangle([5, 5, 6, 6], fill=0)
    img = shaded(mask(draw), PAL["s"], PAL["S"], PAL["d"])
    ImageDraw.Draw(img).rectangle([5, 5, 6, 6], fill=PAL["k"])
    return img


def badge(fill, light, dark, marks):
    """A round badge with a white mark on it (check, arrows)."""
    img = shaded(mask(lambda d: d.ellipse([1, 1, 10, 10], fill=255)), fill, light, dark).copy()
    px = img.load()
    for (x, y) in marks:
        px[x, y] = PAL["c"]
    return img


CHECK = [(3, 6), (4, 7), (5, 8), (6, 7), (7, 6), (8, 5), (8, 4), (3, 5), (4, 6), (5, 7), (6, 6), (7, 5)]
ARROW_UP = [(5, 3), (6, 3), (4, 4), (5, 4), (6, 4), (7, 4), (3, 5), (4, 5), (5, 5), (6, 5), (7, 5), (8, 5),
            (5, 6), (6, 6), (5, 7), (6, 7), (5, 8), (6, 8)]
ARROW_DOWN = [(x, 11 - y) for (x, y) in ARROW_UP]


def clock():
    img = shaded(mask(lambda d: d.ellipse([1, 1, 10, 10], fill=255)), PAL["p"], hexc("fffaf0"), PAL["t"])
    d = ImageDraw.Draw(img)
    d.line([5, 3, 5, 6], fill=PAL["k"])
    d.line([6, 6, 7, 6], fill=PAL["k"])
    d.point([(5, 2), (2, 5), (9, 5), (5, 9)], fill=PAL["T"])
    return img


def sparkle():
    def draw(d):
        d.line([4, 1, 4, 11], fill=255)
        d.line([0, 6, 8, 6], fill=255)
        d.rectangle([3, 4, 5, 8], fill=255)
        d.rectangle([2, 5, 6, 7], fill=255)
        d.line([9, 1, 9, 3], fill=255)
        d.line([8, 2, 10, 2], fill=255)
    return shaded(mask(draw), PAL["Y"], hexc("fff3b8"), PAL["y"])


def note():
    """Two beamed notes (sound)."""
    def draw(d):
        d.rectangle([5, 1, 10, 2], fill=255)
        d.line([5, 1, 5, 8], fill=255)
        d.line([10, 1, 10, 7], fill=255)
        d.ellipse([2, 7, 5, 10], fill=255)
        d.ellipse([7, 6, 10, 9], fill=255)
    return shaded(mask(draw), PAL["b"], PAL["B"], PAL["n"])


def recolour(img, table):
    a = np.asarray(img).copy()
    for src, dst in table.items():
        hit = np.all(a == np.array(PAL[src], np.uint8), axis=-1)
        a[hit] = PAL[dst]
    return Image.fromarray(a, "RGBA")


SEASON_ART = ("ui_icon_blossom", "ui_icon_snowflake")  # drawn as the season icons

ICONS = {
    "ui_icon_coin": coin, "ui_icon_level": star,
    "ui_icon_time_day": sun, "ui_icon_time_morning": lambda: sun(low=True),
    "ui_icon_time_evening": lambda: sun(low=True), "ui_icon_time_night": moon,
    "ui_icon_weather_cloudy": cloud, "ui_icon_weather_rain": lambda: cloud("rain"),
    "ui_icon_weather_snow": lambda: cloud("snow"),
    "ui_icon_settings": gear, "ui_icon_clock": clock, "ui_icon_sparkle": sparkle, "ui_icon_note": note,
    "ui_icon_check": lambda: badge(PAL["g"], PAL["G"], PAL["e"], CHECK),
    "ui_icon_arrow_up": lambda: badge(PAL["g"], PAL["G"], PAL["e"], ARROW_UP),
    "ui_icon_arrow_down": lambda: badge(PAL["O"], hexc("ffc870"), PAL["q"], ARROW_DOWN),
    "ui_icon_season_spring": lambda: from_ascii(ASCII["ui_icon_blossom"]), "ui_icon_season_summer": sun,
    "ui_icon_season_winter": lambda: from_ascii(ASCII["ui_icon_snowflake"]),
    "ui_icon_season_autumn": lambda: recolour(from_ascii(ASCII["ui_icon_leaf"]), {"G": "O", "g": "q", "e": "m"}),
    **{name: (lambda a=art: from_ascii(a)) for name, art in ASCII.items() if name not in SEASON_ART},
}

# name → (picture, art cap inset); frames are saved at 2× (cap inset in points = 2 × this).
FRAMES = {
    "ui_hud_panel": (lambda: frame(40, 20, "paper", seams=(13,), seed=1), 5),
    "ui_hud_wood": (lambda: frame(40, 24, "planks", seams=(13,)), 5),
    "ui_hud_slot": (lambda: slot(False), 3),
    "ui_hud_slot_selected": (lambda: slot(True), 3),
    "ui_hud_button": (lambda: board(hexc("e27a16"), hexc("f5a04a"), hexc("a8560c")), 6),
    "ui_hud_leather": (lambda: leather(), 5),
    "ui_paper": (lambda: paper_tile(), 0),
    "ui_card": (lambda: card(), 4),
    "ui_inset": (lambda: inset(), 3),
    **{f"ui_board_{name}": ((lambda c=c: board(hexc(c[0]), hexc(c[1]), hexc(c[2]))), 6) for name, c in TINTS.items()},
    **{f"ui_ribbon_{name}": ((lambda c=c: ribbon(hexc(c[0]), hexc(c[1]), hexc(c[2]))), 9) for name, c in TINTS.items()},
    "ui_hud_button_quiet": (lambda: board(hexc("8a6a4e"), hexc("a8866a"), hexc("5e4632")), 6),
}


def write(name, img):
    folder = os.path.join(CATALOG, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + ".png"))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"},
                              {"idiom": "universal", "scale": "2x"}, {"idiom": "universal", "scale": "3x"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    for name, (make, _inset) in FRAMES.items():
        img = make()
        write(name, img.resize((img.width * 2, img.height * 2), Image.NEAREST))
    for name, make in ICONS.items():
        write(name, make())
    print("wrote", len(FRAMES), "frames and", len(ICONS), "icons")
