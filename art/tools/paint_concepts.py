"""Paints the concept art for Game_1 in code, pixel by pixel, in the game's own
palette and at the game's own scale (1 world unit = 1 pixel: peasants are 16
high, a stone block 24 x 12, a keep storey 48). Writes PNGs (also scaled up 3x
for viewing) and layered .aseprite files into art/concept/.

Run from the repo root:  python3 art/tools/paint_concepts.py
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import aseprite_writer  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "concept")
W, H = 640, 360
G = 300  # the ground line

# ---------------------------------------------------------------- palette
# One palette for the whole game. Index 0 is transparent.
PALETTE = [
    ("clear", "000000"),
    ("ink", "1a1622"), ("night1", "232a45"), ("night2", "2f3f66"),
    ("sky1", "3e6aa0"), ("sky2", "6a98c8"), ("sky3", "a6c8e0"), ("haze", "d8e4e0"), ("white", "f4f1e6"),
    ("stone0", "3a3540"), ("stone1", "575160"), ("stone2", "7c7680"), ("stone3", "a39c98"), ("stone4", "c9c0b0"),
    ("wood0", "3a2418"), ("wood1", "5c3a24"), ("wood2", "8a5a34"), ("wood3", "b88a54"), ("thatch", "d6b268"),
    ("grass0", "1d3222"), ("grass1", "2e5230"), ("grass2", "4a7a38"), ("grass3", "78a444"), ("grass4", "b4c860"),
    ("dirt", "9c7a52"),
    ("slate0", "2c3558"), ("slate1", "45558a"), ("slate2", "6a7cb8"),
    ("red0", "5a1e24"), ("red1", "9a3028"), ("fire", "d0582c"), ("gold", "f2b640"), ("light", "ffe9a0"),
    ("skin0", "a86a4c"), ("skin1", "e6b08a"),
    ("teal", "3f7a78"), ("purple", "6a3a6a"),
    ("mtn0", "6c7aa0"), ("mtn1", "9aa8c8"), ("daub", "e2d4b0"),
]
C = {name: i for i, (name, _) in enumerate(PALETTE)}
RGB = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for _, h in PALETTE]

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dith(x, y, t):
    """True where a pixel should take the second colour, for a mix t (0..1)."""
    return BAYER[y % 4][x % 4] < t * 16


# ---------------------------------------------------------------- canvas
class Canvas:
    def __init__(self, w=W, h=H, names=("sky", "far", "castle", "front")):
        self.w, self.h = w, h
        self.layers = {n: Image.new("P", (w, h), 0) for n in names}
        self.order = list(names)
        self.use(self.order[0])

    def use(self, name):
        self.img = self.layers[name]
        self.d = ImageDraw.Draw(self.img)
        self.pix = self.img.load()
        return self

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.pix[x, y] = C[c] if isinstance(c, str) else c

    def get(self, x, y):
        return self.pix[x, y] if 0 <= x < self.w and 0 <= y < self.h else 0

    def rect(self, x0, y0, x1, y1, c):
        """Fills x0..x1-1, y0..y1-1."""
        if x1 > x0 and y1 > y0:
            self.d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=C[c])

    def poly(self, pts, c):
        self.d.polygon(pts, fill=C[c])

    def line(self, pts, c, w=1):
        self.d.line(pts, fill=C[c], width=w)

    def ellipse(self, x0, y0, x1, y1, c):
        self.d.ellipse([x0, y0, x1 - 1, y1 - 1], fill=C[c])

    def mix(self, x0, y0, x1, y1, a, b, t):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.px(x, y, b if dith(x, y, t) else a)

    def flat(self):
        out = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for n in self.order:
            out.alpha_composite(to_rgba(self.layers[n]))
        return out


def to_rgba(img):
    rgba = img.convert("RGBA") if False else None
    p = img.copy()
    flat = []
    for r, g, b in RGB:
        flat += [r, g, b]
    p.putpalette(flat + [0] * (768 - len(flat)))
    p.info["transparency"] = 0
    return p.convert("RGBA")


# ---------------------------------------------------------------- building blocks
def masonry(cv, x0, y0, x1, y1, base, mortar, hi, lo, bw=24, bh=12, seed=1, cut_top=False):
    """Stone blocks a course at a time, bottom up, so courses line up with the
    game's (block 24 x 12). Light comes from the upper left."""
    rnd = random.Random(seed)
    cv.rect(x0, y0, x1, y1, base)
    course = 0
    y = y1
    while y > y0:
        top = max(y0, y - bh)
        off = (bw // 2) if course % 2 else 0
        cv.rect(x0, y - 1, x1, y, mortar) if y - 1 >= top else None
        x = x0 - off
        while x < x1:
            bx0, bx1 = max(x0, x), min(x1, x + bw)
            if x > x0:
                for yy in range(top, y):
                    cv.px(x, yy, mortar)
            # a light top edge and left edge, a few chips
            for xx in range(bx0 + 1, bx1):
                cv.px(xx, top, hi)
            shade = rnd.random()
            if shade < 0.25:
                for yy in range(top + 2, y - 2):
                    for xx in range(bx0 + 2, bx1 - 1):
                        if dith(xx, yy, 0.25):
                            cv.px(xx, yy, lo)
            for _ in range(2):
                cv.px(rnd.randrange(bx0 + 1, max(bx0 + 2, bx1 - 1)), rnd.randrange(top + 1, max(top + 2, y - 1)), lo)
            x += bw
        y -= bh
        course += 1


def merlons(cv, x0, x1, y, c, cap, step=12, size=8, height=8):
    """Battlements: teeth of `size` every `step`, standing on y."""
    x = x0
    while x + size <= x1 + 1:
        cv.rect(x, y - height, x + size, y, c)
        cv.rect(x, y - height, x + size, y - height + 1, cap)
        cv.px(x + size - 1, y - 2, "stone1")
        x += step


def cone_roof(cv, x0, x1, base, tip_h, flag=True, colors=("slate0", "slate1", "slate2")):
    mid = (x0 + x1) / 2
    cv.poly([(x0 - 3, base), (x1 + 2, base), (mid, base - tip_h)], colors[1])
    cv.poly([(x0 - 3, base), (mid, base), (mid, base - tip_h)], colors[2])  # lit left half
    for i in range(0, tip_h, 6):  # rows of slates
        y = base - i
        half = (x1 - x0 + 5) / 2 * (1 - i / tip_h)
        cv.line([(mid - half, y), (mid + half, y)], colors[0])
    cv.rect(x0 - 4, base, x1 + 4, base + 2, "slate0")
    if flag:
        top = int(base - tip_h)
        cv.line([(mid, top), (mid, top - 14)], "wood1")
        cv.poly([(mid + 1, top - 14), (mid + 11, top - 11), (mid + 1, top - 8)], "red1")
        cv.line([(mid + 1, top - 14), (mid + 9, top - 12)], "fire")


def slit(cv, x, y, h=8):
    cv.rect(x, y, x + 2, y + h, "ink")
    cv.px(x - 1, y + h // 2, "ink")
    cv.px(x + 2, y + h // 2, "ink")


def window(cv, x, y, w=8, h=12, lit=False):
    cv.rect(x - 1, y - 1, x + w + 1, y + h + 1, "stone4")
    cv.rect(x, y, x + w, y + h, "gold" if lit else "ink")
    cv.rect(x, y, x + w, y + 2, "fire" if lit else "night2")
    cv.line([(x + w // 2, y), (x + w // 2, y + h - 1)], "wood0")


def tree(cv, x, base, size=1.0, pine=False, seed=0):
    rnd = random.Random(seed)
    if pine:
        h = int(34 * size)
        cv.rect(x - 1, base - 6, x + 2, base, "wood0")
        for i in range(4):
            y = base - 5 - i * h // 5
            half = int((4 - i) * 4 * size) + 2
            cv.poly([(x - half, y), (x + half, y), (x, y - h // 3)], "grass0")
            cv.poly([(x - half, y), (x, y), (x, y - h // 3)], "grass1")
        return
    trunk = int(16 * size)
    cv.rect(x - 2, base - trunk, x + 2, base, "wood1")
    cv.px(x - 2, base - trunk // 2, "wood0")
    r = int(14 * size)
    cy = base - trunk - r + 4
    for (dx, dy, rr, c) in [(0, 2, r, "grass0"), (-r // 2, 0, r * 2 // 3, "grass1"), (r // 2, 1, r * 2 // 3, "grass1"),
                            (-2, -r // 3, r * 2 // 3, "grass2"), (-r // 2, -r // 4, r // 3, "grass3")]:
        cv.ellipse(x + dx - rr, cy + dy - rr, x + dx + rr, cy + dy + rr, c)
    for _ in range(int(10 * size)):  # leaf clusters catching light
        a = rnd.random() * math.pi
        cv.px(int(x - abs(math.cos(a)) * r * 0.7), int(cy - math.sin(a) * r * 0.6), "grass4")


def smoke(cv, x, y, n=6, seed=3):
    rnd = random.Random(seed)
    for i in range(n):
        r = 3 + i
        cx, cy = x + int(math.sin(i * 1.3) * 2) + i * 3, y - i * 8
        for yy in range(cy - r, cy + r):
            for xx in range(cx - r, cx + r):
                if (xx - cx) ** 2 + (yy - cy) ** 2 < r * r and dith(xx, yy, 0.65 - i * 0.08):
                    cv.px(xx, yy, "stone4" if yy < cy else "stone3")


# ---------------------------------------------------------------- people
# Sprites are drawn in strings, bottom-centre anchored. 9 x 16 for grown-ups.
ADULT = [
    "...hhh...",
    "..hhhhh..",
    "..hhsss..",
    "..hsses..",
    "...ssss..",
    "....SS...",
    "..ttttt..",
    ".ttttTtt.",
    ".tTttTtts",
    ".s.tTttt.",
    "...bbbb..",
    "...tttT..",
    "...tTTT..",
    "...l..l..",
    "...l..l..",
    "..ff..ff.",
]
CHILD = [
    "..hhh..",
    ".hhsss.",
    ".hsses.",
    "..sss..",
    ".ttttt.",
    "sttTtts",
    "..bbb..",
    "..tTT..",
    "..l.l..",
    ".ff.ff.",
]
BASE_KEY = {"o": "ink", "e": "ink", "s": "skin1", "S": "skin0", "f": "ink", "l": "wood0", "b": "wood0"}

ROLES = {
    # name: (hair, tunic, tunic shade, extra overlays)
    "peasant": ("wood1", "wood2", "wood1", []),
    "builder": ("wood0", "stone2", "stone1", ["block"]),
    "woodcutter": ("red0", "grass2", "grass1", ["log"]),
    "cook": ("wood3", "daub", "stone3", ["apron"]),
    "trained": ("wood1", "teal", "slate0", ["hat"]),
    "spearman": ("wood0", "red1", "red0", ["helmet", "spear"]),
    "archer": ("wood1", "grass1", "grass0", ["hood", "bow"]),
    "noble": ("gold", "purple", "slate0", ["crown"]),
    "bandit": ("ink", "wood1", "wood0", ["mask", "torch"]),
    "raider": ("red0", "stone1", "stone0", ["helmet", "axe"]),
    "warband": ("ink", "stone2", "stone1", ["helmet_big", "shield", "spear"]),
}

OVERLAYS = {
    # name: (rows, dx, dy, key) — dx/dy from the sprite's top-left
    "block": (["BBBBB", "BbbbB", "BBBBB"], 2, -3, {"B": "stone3", "b": "stone4"}),
    "log": (["wwwwwwwwwr", "WWWWWWWWWr"], -2, 6, {"w": "wood2", "W": "wood1", "r": "wood3"}),
    "apron": (["aaa", "aaa", "aaa", "aaa"], 3, 8, {"a": "white"}),
    "hat": ([".ggggg.", "ggggggg"], 1, -1, {"g": "thatch"}),
    "helmet": ([".iiii.", "iIIIIi", "i....i"], 2, -1, {"i": "stone3", "I": "stone4"}),
    "helmet_big": (["..ii..", ".iIIi.", "iIIIIi", "i.ii.i"], 2, -2, {"i": "stone2", "I": "stone4"}),
    "hood": ([".ggg.", "ggggg", "g...."], 2, -1, {"g": "grass1"}),
    "crown": (["g.g.g", "ggggg"], 2, -2, {"g": "gold"}),
    "mask": (["mmmm"], 4, 4, {"m": "ink"}),
    "spear": (["k", "K", "w", "w", "w", "w", "w", "w", "w", "w", "w", "w", "w", "w", "w", "w", "w", "w", "w"], 8, -4,
              {"k": "stone4", "K": "stone3", "w": "wood1"}),
    "bow": (["..w", ".w.", "w..", "w..", "w..", ".w.", "..w"], 7, 4, {"w": "wood2"}),
    "axe": (["II.", "IIw", "I.w", "..w", "..w", "..w"], 7, 3, {"I": "stone3", "w": "wood1"}),
    "torch": (["L", "F", "f", "w", "w", "w", "w"], 9, 1, {"L": "light", "F": "gold", "f": "fire", "w": "wood1"}),
    "shield": (["sss", "sgs", "sgs", "sss"], -1, 7, {"s": "red1", "g": "gold"}),
}


def stamp(cv, rows, x, y, key, flip=False):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != "." and ch in key:
                cv.px(x + (len(row) - 1 - i if flip else i), y + j, key[ch])


def person(cv, role, x, base, flip=False, child=False, pose=0):
    hair, tunic, shade, extras = ROLES[role]
    key = dict(BASE_KEY, h=hair, t=tunic, T=shade)
    rows = CHILD if child else ADULT
    if pose == 1:  # mid-stride
        rows = rows[:-3] + ["...l.l...", "..l...l..", ".ff...ff."] if not child else rows
    w = len(rows[0])
    x0, y0 = x - w // 2, base - len(rows)
    stamp(cv, rows, x0, y0, key, flip)
    if child:
        return
    for name in extras:
        o_rows, dx, dy, o_key = OVERLAYS[name]
        ow = len(o_rows[0])
        ox = x0 + (w - dx - ow if flip else dx)
        stamp(cv, o_rows, ox, y0 + dy, o_key, flip)


def sleeper(cv, x, y):
    """A peasant lying in bed, seen from the side."""
    cv.rect(x, y, x + 4, y + 3, "skin1")
    cv.rect(x, y - 1, x + 3, y, "wood1")


# ---------------------------------------------------------------- the scene
def sky(cv, mode):
    bands = {
        "day": ["sky1", "sky2", "sky3", "haze"],
        "night": ["night1", "night1", "night2", "slate0"],
        "winter": ["sky2", "sky3", "haze", "white"],
    }[mode]
    stops = [0, 110, 200, 270, G]
    for k in range(4):
        a = bands[k]
        b = bands[min(k + 1, 3)]
        y0, y1 = stops[k], stops[k + 1]
        for y in range(y0, y1):
            t = (y - y0) / max(1, y1 - y0)
            for x in range(W):
                cv.px(x, y, b if dith(x, y, max(0.0, t * 1.4 - 0.4)) else a)
    if mode == "night":
        rnd = random.Random(9)
        for _ in range(90):
            cv.px(rnd.randrange(W), rnd.randrange(200), rnd.choice(["white", "sky3", "sky2", "sky2"]))
        cx, cy = 520, 60
        for y in range(cy - 26, cy + 26):
            for x in range(cx - 26, cx + 26):
                d = math.hypot(x - cx, y - cy)
                if d < 12:
                    cv.px(x, y, "white" if (x - cx + 3) ** 2 + (y - cy + 3) ** 2 > 40 or d < 9 else "haze")
                elif d < 26 and dith(x, y, (26 - d) / 40):
                    cv.px(x, y, "night2")
        for (x, y) in [(512, 56), (523, 66), (518, 63)]:
            cv.px(x, y, "sky3")
        return
    # sun and clouds
    if mode == "day":
        cx, cy = 96, 64
        for y in range(cy - 30, cy + 30):
            for x in range(cx - 30, cx + 30):
                d = math.hypot(x - cx, y - cy)
                if d < 9:
                    cv.px(x, y, "white" if d < 7 else "light")
                elif d < 30 and dith(x, y, (30 - d) / 34):
                    cv.px(x, y, "haze" if d < 18 else "sky3")
    rnd = random.Random(4)
    for (cx, cy, n) in [(250, 60, 7), (470, 95, 6), (40, 140, 4), (600, 40, 5), (360, 150, 3)]:
        for i in range(n):
            ex = cx + rnd.randint(-n * 6, n * 6)
            ey = cy + rnd.randint(-5, 5)
            rx, ry = rnd.randint(10, 22), rnd.randint(5, 9)
            cv.ellipse(ex - rx, ey - ry + 2, ex + rx, ey + ry + 2, "sky3" if mode == "day" else "haze")
            cv.ellipse(ex - rx, ey - ry, ex + rx, ey + ry - 2, "white")
        cv.rect(cx - n * 6 - 14, cy + 4, cx + n * 6 + 14, cy + 8, "sky3" if mode == "day" else "haze")


def far(cv, mode):
    rnd = random.Random(2)
    for (px_, top, half) in [(140, 168, 120), (330, 140, 150), (560, 175, 110), (20, 195, 90)]:
        cv.poly([(px_ - half, 270), (px_ + half, 270), (px_, top)], "mtn0")
        cv.poly([(px_ - half, 270), (px_, 270), (px_, top)], "mtn1")
        snow = top + 24
        sw = half * 24 / (270 - top)
        pts = [(px_, top), (px_ + sw, snow)]
        for k in range(5, -1, -1):
            pts.append((px_ - sw + k * sw / 2.5, snow + (5 if k % 2 else -1)))
        cv.poly(pts, "white")
        cv.poly([(px_, top), (px_ + sw, snow), (px_ + 2, snow + 3)], "haze")
    # far hills with dithered haze, then near hills with trees
    for x in range(W):
        y_far = int(262 + 8 * math.sin(x / 70) + 4 * math.sin(x / 23 + 1))
        y_near = int(282 + 6 * math.sin(x / 55 + 2) + 3 * math.sin(x / 17))
        for y in range(y_far, G):
            cv.px(x, y, "grass2" if dith(x, y, 0.5) else "mtn1")
        for y in range(y_near, G):
            cv.px(x, y, "grass1" if y > y_near + 2 else "grass2")
    for i in range(46):
        x = rnd.randrange(W)
        y = int(266 + 8 * math.sin(x / 70) + 4 * math.sin(x / 23 + 1))
        h = rnd.randint(5, 9)
        cv.poly([(x - 3, y + 2), (x + 3, y + 2), (x, y - h)], "grass1")


def ground(cv):
    for x in range(W):
        for y in range(G, H):
            t = (y - G) / (H - G)
            cv.px(x, y, "grass1" if dith(x, y, t * 0.8) else "grass2")
        cv.px(x, G, "grass3")
        if x % 7 == 3 or x % 11 == 0:
            cv.px(x, G - 1, "grass3")
            cv.px(x + 1, G - 2, "grass4")
    # the dirt road towards the gate and the stockyard
    for x in range(W):
        y = int(320 + 10 * math.sin(x / 120))
        for yy in range(y, y + 9):
            cv.px(x, yy, "dirt" if dith(x, yy, 0.85) else "wood2")
        cv.px(x, y, "wood3")
    rnd = random.Random(5)
    for _ in range(140):  # flowers and tufts
        x, y = rnd.randrange(W), rnd.randrange(G + 4, H)
        cv.px(x, y, rnd.choice(["grass3", "grass4", "grass3", "gold", "white", "red1"]))


def curtain_wall(cv):
    top = G - 80
    masonry(cv, 16, top, 624, G, "stone1", "stone0", "stone2", "stone0", seed=11)
    merlons(cv, 16, 624, top, "stone1", "stone2")
    cv.rect(16, top, 624, top + 2, "stone2")  # the wall walk
    # the gate: an arch with the portcullis half raised
    gx0, gx1 = 410, 450
    cv.rect(gx0 - 6, G - 52, gx1 + 6, G, "stone3")
    cv.ellipse(gx0 - 6, G - 64, gx1 + 6, G - 36, "stone3")
    cv.rect(gx0, G - 44, gx1, G, "ink")
    cv.ellipse(gx0, G - 58, gx1, G - 30, "ink")
    for x in range(gx0 + 3, gx1, 6):
        cv.line([(x, G - 54), (x, G - 22)], "stone0")
    for y in range(G - 52, G - 22, 6):
        cv.line([(gx0, y), (gx1 - 1, y)], "stone0")
    for x in range(gx0 + 3, gx1, 6):
        cv.rect(x, G - 22, x + 1, G - 18, "stone2")
    # end towers
    for x0 in (0, 596):
        masonry(cv, x0, G - 130, x0 + 44, G, "stone2", "stone0", "stone3", "stone1", seed=x0 + 3)
        merlons(cv, x0, x0 + 44, G - 130, "stone2", "stone3", step=12, size=8)
        cone_roof(cv, x0 + 2, x0 + 42, G - 138, 56)
        for y in (G - 110, G - 70):
            slit(cv, x0 + 21, y)


def keep(cv, lit_night=False):
    """The keep, front wall cut away: three storeys, a stair up the middle
    and a room either side (CastleData.keep_rooms)."""
    x0, x1 = 60, 320
    floors = [G - 8, G - 56, G - 104]
    roof = G - 152
    # outer shell
    masonry(cv, x0, roof, x1, G, "stone3", "stone1", "stone4", "stone2", seed=21)
    cv.rect(x0 - 4, G - 8, x1 + 4, G, "stone1")
    merlons(cv, x0 - 2, x1 + 2, roof, "stone3", "stone4", step=14, size=9, height=10)
    cv.rect(x0 - 2, roof - 1, x1 + 2, roof + 3, "stone2")
    # inside: back walls of each storey
    for i, fy in enumerate(floors):
        top = fy - 44
        masonry(cv, x0 + 10, top, x1 - 10, fy, "stone1", "stone0", "stone2", "stone0", bw=20, bh=10, seed=30 + i)
        cv.rect(x0 + 10, top, x1 - 10, top + 3, "wood1")  # ceiling beams
        for bx in range(x0 + 16, x1 - 10, 22):
            cv.rect(bx, top, bx + 4, top + 5, "wood0")
        # floor slab: planks, its cut edge facing us
        cv.rect(x0, fy, x1, fy + 4, "wood1")
        cv.rect(x0, fy, x1, fy + 1, "wood3")
        for px_ in range(x0 + 5, x1, 9):
            cv.px(px_, fy + 2, "wood0")
        # the stair well
        sx0, sx1 = 176, 204
        cv.rect(sx0, top + 3, sx1, fy, "stone0")
        for k in range(12):  # flight up to the right, then back to the left
            cv.rect(sx0 + 2 * k, fy - 2 * k - 2, sx0 + 2 * k + 4, fy - 2 * k, "wood2")
            cv.rect(sx1 - 2 * k - 4, fy - 24 - 2 * k - 2, sx1 - 2 * k, fy - 24 - 2 * k, "wood2")
        cv.rect(sx1 - 6, fy - 26, sx1, fy - 24, "wood3")
        for wx in (sx0 - 2, sx1):  # room walls with doorways
            cv.rect(wx, top + 3, wx + 2, fy - 16, "stone1")
    # the cut edges of the front wall, ragged so it reads as a cut
    rnd = random.Random(7)
    for (ex, d) in ((x0, 1), (x1 - 10, -1)):
        cv.rect(ex, roof, ex + 10, G - 8, "stone3")
        for y in range(roof, G - 8, 3):
            r = rnd.randint(0, 3)
            if d > 0:
                cv.rect(ex + 10, y, ex + 10 + r, y + 3, "stone2")
            else:
                cv.rect(ex - r, y, ex, y + 3, "stone2")
        cv.line([(ex + (9 if d > 0 else 0), roof), (ex + (9 if d > 0 else 0), G - 8)], "stone4")
    for y in (G - 30, G - 78, G - 126):
        window(cv, x0 + 1, y, w=7, h=12, lit=lit_night)
        window(cv, x1 - 8, y, w=7, h=12, lit=lit_night)
    # the door you step up to
    cv.rect(178, G - 30, 200, G - 8, "wood1")
    cv.ellipse(178, G - 38, 200, G - 22, "wood1")
    cv.line([(189, G - 37), (189, G - 9)], "wood0")
    cv.rect(172, G - 8, 206, G - 4, "stone4")
    rooms(cv, floors)
    # chimney stack out of the kitchen, and the flag
    cv.rect(80, roof - 18, 92, roof, "stone2")
    cv.rect(79, roof - 20, 93, roof - 17, "stone3")
    cv.line([(250, roof - 10), (250, roof - 50)], "wood1")
    cv.poly([(251, roof - 50), (273, roof - 44), (251, roof - 38)], "red1")
    cv.poly([(251, roof - 50), (273, roof - 44), (251, roof - 44)], "fire")
    cv.rect(256, roof - 47, 260, roof - 41, "gold")


LIGHTS = []  # (x, y, radius) of every light, for the night version


def rooms(cv, floors):
    k, s, b = floors  # kitchen/hall, store/armoury, bedrooms
    # --- kitchen (west, entrance storey)
    cv.rect(72, k - 30, 104, k, "stone3")
    cv.rect(76, k - 22, 100, k, "ink")
    cv.rect(72, k - 32, 106, k - 29, "stone4")
    for i, c in enumerate(["fire", "gold", "light"]):
        cv.poly([(80 + i * 2, k), (96 - i * 2, k), (88, k - 12 + i * 3)], c)
    cv.line([(88, k - 22), (88, k - 14)], "ink")
    cv.ellipse(83, k - 15, 94, k - 7, "ink")
    cv.rect(83, k - 15, 94, k - 12, "stone1")
    LIGHTS.append((88, k - 8, 34))
    cv.rect(112, k - 10, 148, k - 8, "wood2")  # work table
    cv.rect(114, k - 8, 116, k, "wood1")
    cv.rect(144, k - 8, 146, k, "wood1")
    for jx, c in [(118, "red1"), (126, "stone4"), (134, "thatch"), (140, "grass2")]:
        cv.rect(jx, k - 14, jx + 4, k - 10, c)
    cv.rect(110, k - 34, 168, k - 32, "wood2")  # shelf with jars
    for jx in range(112, 166, 7):
        cv.rect(jx, k - 39, jx + 4, k - 34, ["daub", "teal", "red1", "stone3"][jx % 4])
    for hx in range(152, 170, 5):  # herbs hanging
        cv.line([(hx, k - 44), (hx, k - 40)], "wood0")
        cv.rect(hx - 1, k - 40, hx + 2, k - 36, "grass2")
    person(cv, "cook", 128, k)
    # --- great hall (east)
    cv.rect(216, k - 40, 236, k - 22, "red1")  # banner
    cv.rect(216, k - 40, 236, k - 38, "red0")
    cv.poly([(216, k - 22), (226, k - 17), (236, k - 22)], "red1")
    cv.rect(223, k - 34, 229, k - 26, "gold")
    cv.rect(270, k - 40, 290, k - 22, "teal")
    cv.poly([(270, k - 22), (280, k - 17), (290, k - 22)], "teal")
    cv.rect(277, k - 34, 283, k - 26, "gold")
    cv.rect(212, k - 12, 304, k - 9, "wood2")
    cv.rect(212, k - 12, 304, k - 11, "wood3")
    for lx in (216, 256, 298):
        cv.rect(lx, k - 9, lx + 2, k, "wood1")
    for (cx_, c) in [(226, "gold"), (244, "stone4"), (262, "red1"), (284, "gold")]:
        cv.rect(cx_, k - 15, cx_ + 3, k - 12, c)
    cv.rect(250, k - 18, 251, k - 12, "daub")
    cv.px(250, k - 19, "light")
    LIGHTS.append((250, k - 19, 24))
    person(cv, "peasant", 232, k, flip=False)
    person(cv, "trained", 276, k, flip=True)
    # --- store (west, second storey)
    for i, bx in enumerate((76, 92, 108)):
        cv.ellipse(bx, s - 18, bx + 14, s, "wood2")
        cv.rect(bx + 1, s - 13, bx + 13, s - 11, "wood0")
        cv.rect(bx + 1, s - 6, bx + 13, s - 4, "wood0")
        cv.px(bx + 4, s - 15, "wood3")
    cv.ellipse(84, s - 34, 98, s - 17, "wood2")
    cv.rect(85, s - 29, 97, s - 27, "wood0")
    for sx in (130, 141):  # sacks
        cv.poly([(sx, s), (sx + 11, s), (sx + 9, s - 14), (sx + 2, s - 14)], "daub")
        cv.rect(sx + 3, s - 16, sx + 8, s - 14, "wood1")
    cv.rect(152, s - 16, 170, s, "wood1")  # crate
    cv.rect(153, s - 15, 169, s - 1, "wood2")
    cv.line([(153, s - 15), (168, s - 2)], "wood1")
    cv.rect(124, s - 34, 168, s - 32, "wood2")
    for jx in range(126, 166, 6):
        cv.ellipse(jx, s - 40, jx + 5, s - 33, "thatch" if jx % 12 else "grass3")
    # --- armoury (east)
    cv.rect(214, s - 34, 260, s - 31, "wood1")
    for sx in range(218, 258, 6):
        cv.line([(sx, s - 42), (sx, s - 2)], "wood2")
        cv.rect(sx - 1, s - 44, sx + 2, s - 41, "stone4")
    cv.rect(214, s - 6, 260, s - 3, "wood1")
    for (cx_, c) in [(270, "red1"), (288, "teal")]:
        cv.ellipse(cx_, s - 38, cx_ + 14, s - 24, c)
        cv.ellipse(cx_ + 4, s - 34, cx_ + 10, s - 28, "gold")
    cv.rect(282, s - 18, 296, s - 4, "stone3")  # armour on a stand
    cv.rect(286, s - 22, 292, s - 18, "stone4")
    cv.rect(288, s - 4, 290, s, "wood1")
    person(cv, "spearman", 270, s, flip=True)
    # --- bedchamber (west, top storey)
    for bx in (78, 124):
        cv.rect(bx, b - 10, bx + 36, b - 4, "wood2")
        cv.rect(bx, b - 16, bx + 3, b, "wood1")
        cv.rect(bx + 1, b - 12, bx + 36, b - 9, "white")
        cv.rect(bx + 12, b - 13, bx + 36, b - 9, "teal")
        cv.rect(bx + 34, b - 12, bx + 37, b, "wood1")
    sleeper(cv, 82, b - 14)
    cv.rect(115, b - 30, 118, b - 26, "gold")
    LIGHTS.append((116, b - 30, 16))
    # --- the lord's chamber (east)
    cv.rect(210, b - 6, 304, b, "red1")  # rug
    cv.rect(212, b - 5, 302, b - 4, "red0")
    cv.rect(226, b - 40, 230, b, "wood1")
    cv.rect(282, b - 40, 286, b, "wood1")
    cv.rect(224, b - 42, 288, b - 37, "purple")
    cv.poly([(224, b - 37), (288, b - 37), (288, b - 33), (224, b - 33)], "purple")
    for fx in range(226, 288, 6):
        cv.px(fx, b - 33, "gold")
    cv.rect(230, b - 16, 282, b - 8, "wood2")
    cv.rect(230, b - 18, 282, b - 14, "purple")
    cv.rect(232, b - 20, 244, b - 16, "white")
    cv.rect(292, b - 12, 304, b - 4, "wood2")  # chest
    cv.rect(292, b - 12, 304, b - 10, "gold")
    person(cv, "noble", 296, b - 4, flip=True)
    cv.rect(216, b - 30, 219, b - 26, "gold")
    LIGHTS.append((217, b - 30, 16))
    # someone on the stairs
    person(cv, "peasant", 188, s - 10)


def tower_in_progress(cv):
    """A wall tower going up: scaffold, ladder, hoist and the yard at its foot."""
    x0, x1 = 336, 384
    top = G - 72
    masonry(cv, x0, top, x1, G, "stone3", "stone1", "stone4", "stone2", seed=41)
    # the course being laid: two blocks in, the rest to come
    masonry(cv, x0, top - 12, x0 + 24, top, "stone3", "stone1", "stone4", "stone2", seed=42)
    slit(cv, x0 + 23, G - 50)
    # scaffold: poles, ledgers, planks
    for px_ in (x0 - 6, x1 + 4):
        cv.rect(px_, top - 30, px_ + 2, G, "wood1")
    for ly in (G - 34, top):
        cv.rect(x0 - 8, ly, x1 + 8, ly + 2, "wood2")
        cv.rect(x0 - 8, ly, x1 + 8, ly + 1, "wood3")
    for k in range(4):  # cross braces
        cv.line([(x0 - 5, G - k * 18), (x0 - 1, G - k * 18 - 18)], "wood0")
    # ladder on the left
    for lx in (x0 - 18, x0 - 12):
        cv.line([(lx, G), (lx + 6, top - 2)], "wood2")
    for r in range(G - 4, top, -6):
        f = (G - r) / (G - top)
        cv.line([(x0 - 18 + 6 * f, r), (x0 - 12 + 6 * f, r)], "wood3")
    # hoist: a beam out from the deck, a rope down to a block on the way up
    hx = x1 + 14
    cv.rect(x1 - 6, top - 32, x1 - 3, top - 12, "wood1")
    cv.line([(x1 - 6, top - 32), (hx + 2, top - 32)], "wood1", 2)
    cv.ellipse(hx - 2, top - 34, hx + 4, top - 28, "wood0")
    cv.line([(hx + 1, top - 28), (hx + 1, G - 46)], "thatch")
    cv.rect(hx - 4, G - 46, hx + 7, G - 38, "stone3")
    cv.rect(hx - 4, G - 46, hx + 7, G - 45, "stone4")
    # the yard: a bench with a stone being shaped, and a pile
    cv.rect(392, G - 10, 410, G - 8, "wood2")
    cv.rect(393, G - 8, 395, G, "wood1")
    cv.rect(407, G - 8, 409, G, "wood1")
    cv.rect(396, G - 16, 406, G - 10, "stone3")
    for i, (bx, by) in enumerate([(300 + 30, G), (330 + 0, G), (326, G)]):
        pass
    person(cv, "builder", x0 + 30, top - 12)
    person(cv, "trained", x1 - 2, top - 12, flip=True)
    person(cv, "peasant", 402, G, flip=True)
    person(cv, "builder", 395, G + 14, flip=True, pose=1)


def garrison(cv):
    x0, x1 = 460, 570
    masonry(cv, x0, G - 26, x1, G, "stone2", "stone0", "stone3", "stone1", seed=51)
    cv.rect(x0 - 2, G - 70, x1 + 2, G - 26, "daub")
    for bx in range(x0, x1 + 1, 22):  # timber frame
        cv.rect(bx - 1, G - 70, bx + 2, G - 26, "wood0")
    for by in (G - 70, G - 49, G - 28):
        cv.rect(x0 - 2, by, x1 + 2, by + 3, "wood0")
    for bx in range(x0, x1 - 21, 22):
        cv.line([(bx + 2, G - 47), (bx + 20, G - 29)], "wood0", 2)
    for wx in (x0 + 26, x0 + 70):
        cv.rect(wx, G - 66, wx + 10, G - 54, "ink")
        cv.rect(wx - 4, G - 66, wx, G - 54, "red1")
        cv.rect(wx + 10, G - 66, wx + 14, G - 54, "red1")
    cv.poly([(x0 - 10, G - 70), (x1 + 10, G - 70), ((x0 + x1) // 2, G - 108)], "thatch")
    cv.poly([(x0 - 10, G - 70), ((x0 + x1) // 2, G - 70), ((x0 + x1) // 2, G - 108)], "wood3")
    for k in range(5):
        y = G - 72 - k * 7
        half = (x1 - x0 + 20) / 2 * (1 - (k * 7 + 2) / 38)
        cv.line([((x0 + x1) / 2 - half, y), ((x0 + x1) / 2 + half, y)], "wood2")
    cv.rect(x0 + 48, G - 22, x0 + 62, G, "wood1")
    cv.px(x0 + 59, G - 11, "gold")
    cv.rect(x0 + 86, G - 22, x0 + 90, G - 18, "gold")  # a lantern
    LIGHTS.append((x0 + 88, G - 20, 22))


def stockyard(cv):
    # log pile
    for row in range(3):
        for i in range(4 - row):
            cx_ = 592 + i * 9 + row * 4
            cy_ = G + 18 - row * 8
            cv.ellipse(cx_ - 4, cy_ - 4, cx_ + 5, cy_ + 4, "wood3")
            cv.ellipse(cx_ - 2, cy_ - 2, cx_ + 3, cy_ + 2, "wood2")
            cv.px(cx_, cy_, "wood1")
    # stone blocks, a planks stack and a sign
    for row in range(3):
        for i in range(3 - row):
            masonry(cv, 548 + i * 12 + row * 6, G + 14 - row * 8, 560 + i * 12 + row * 6, G + 22 - row * 8,
                    "stone3", "stone1", "stone4", "stone2", bw=12, bh=8, seed=row * 9 + i)
    for k in range(5):
        cv.rect(512, G + 20 - k * 3, 540, G + 22 - k * 3, "wood3" if k % 2 else "thatch")
    cv.rect(632, G - 4, 634, G + 22, "wood1")


def scene(mode):
    LIGHTS.clear()
    cv = Canvas()
    cv.use("sky")
    sky(cv, "night" if mode == "night" else mode)
    cv.use("far")
    far(cv, mode)
    ground(cv)
    cv.use("castle")
    curtain_wall(cv)
    tree(cv, 444 - 30, G, 0.8, seed=1) if False else None
    keep(cv, lit_night=(mode == "night"))
    tower_in_progress(cv)
    garrison(cv)
    smoke(cv, 86, G - 176)
    # soldiers on the wall walk
    person(cv, "spearman", 584, G - 80)
    person(cv, "archer", 22, G - 130)
    cv.use("front")
    tree(cv, 26, G + 20, 1.1, seed=2)
    tree(cv, 626, G + 4, 0.9, pine=True)
    stockyard(cv)
    person(cv, "woodcutter", 470, G + 22, pose=1)
    person(cv, "peasant", 492, G + 22, pose=0)
    person(cv, "peasant", 500, G + 22, child=True)
    person(cv, "builder", 236, G + 22, flip=True)
    person(cv, "cook", 150, G + 26, pose=1)
    if mode == "day":  # birds
        for (bx, by) in [(300, 70), (310, 76), (318, 68), (190, 110)]:
            cv.px(bx, by, "ink"); cv.px(bx - 1, by - 1, "ink"); cv.px(bx + 1, by - 1, "ink")
    if mode == "night":
        raid(cv)
    if mode == "winter":
        winterise(cv)
    if mode == "night":
        nightise(cv)
    return cv


def raid(cv):
    cv.use("front")
    for i, (x, role) in enumerate([(40, "bandit"), (62, "raider"), (84, "warband"), (106, "bandit"),
                                   (128, "raider"), (52, "warband")]):
        person(cv, role, x, G + 26 + (i % 3) * 6, pose=i % 2)
        if role == "bandit":
            LIGHTS.append((x + 5, G + 26 + (i % 3) * 6 - 15, 26))
    # arrows from the wall
    for (ax, ay) in [(70, 250), (110, 236), (150, 262)]:
        cv.line([(ax, ay), (ax + 8, ay - 3)], "wood3")
        cv.px(ax, ay, "stone4")
    for gx in (404, 456):  # braziers at the gate
        cv.rect(gx - 2, G - 6, gx + 3, G, "ink")
        cv.poly([(gx - 3, G - 6), (gx + 4, G - 6), (gx, G - 14)], "fire")
        cv.poly([(gx - 1, G - 6), (gx + 2, G - 6), (gx, G - 11)], "gold")
        LIGHTS.append((gx, G - 9, 30))


# ---------------------------------------------------------------- palette swaps
KEEP_LIT = {C[n] for n in ("fire", "gold", "light")}


def remap(cv, table, layers=None):
    for name in layers or cv.order:
        cv.use(name)
        for y in range(cv.h):
            for x in range(cv.w):
                v = cv.pix[x, y]
                if v in table:
                    cv.pix[x, y] = table[v]


def nearest(rgb, allowed):
    return min(allowed, key=lambda i: sum((a - b) ** 2 for a, b in zip(RGB[i], rgb)))


def nightise(cv):
    """Night is a palette swap: every colour moves to a darker, bluer one,
    except within reach of a light, where a dithered pool keeps the day
    colours. In Godot this is one palette texture per time of day."""
    allowed = [i for i in range(1, len(PALETTE)) if i not in KEEP_LIT]
    table = {}
    for i in range(1, len(PALETTE)):
        if i in KEEP_LIT:
            continue
        r, g, b = RGB[i]
        table[i] = nearest((r * 0.35 + 18, g * 0.38 + 22, b * 0.5 + 48), allowed)
    warm = {}
    for i in table:
        r, g, b = RGB[i]
        warm[i] = nearest((r * 0.75 + 50, g * 0.6 + 22, b * 0.35 + 6), allowed + [C["fire"]])
    for name in cv.order:
        cv.use(name)
        src = cv.img.copy().load()
        for y in range(cv.h):
            for x in range(cv.w):
                v = src[x, y]
                if v == 0 or v not in table:
                    continue
                lit = 0.0
                for (lx, ly, r) in LIGHTS:
                    d = math.hypot(x - lx, y - ly)
                    if d < r:
                        lit = max(lit, 1 - d / r)
                # warm light near a flame, fading out through a dither
                cv.pix[x, y] = warm[v] if lit and dith(x, y, min(1.0, lit * 1.5)) else table[v]


def winterise(cv):
    """Winter is a palette swap too (greens to snow), plus snow wherever the
    sky lands on something: roofs, merlons, the wall walk."""
    swap = {C["grass4"]: C["white"], C["grass3"]: C["white"], C["grass2"]: C["haze"],
            C["grass1"]: C["sky3"], C["dirt"]: C["stone4"], C["mtn0"]: C["mtn1"]}
    remap(cv, swap, ["far", "front"])
    remap(cv, {C["grass3"]: C["grass1"], C["grass4"]: C["grass2"], C["grass2"]: C["grass1"]}, ["castle"])
    takes_snow = {C[n] for n in ("stone1", "stone2", "stone3", "stone4", "slate0", "slate1", "slate2",
                                 "thatch", "wood3", "wood2", "wood1")}
    cv.use("castle")
    for x in range(cv.w):
        for y in range(1, cv.h):
            if cv.pix[x, y] in takes_snow and not cv.pix[x, y - 1]:
                cv.pix[x, y] = C["white"]
                if cv.pix[x, y + 1] in takes_snow:
                    cv.pix[x, y + 1] = C["white"] if x % 4 else C["haze"]
    rnd = random.Random(8)
    cv.use("front")
    for _ in range(260):
        cv.px(rnd.randrange(W), rnd.randrange(H), "white")


# ---------------------------------------------------------------- sheets
def character_sheet():
    order = ["peasant", "builder", "woodcutter", "cook", "trained", "noble",
             "spearman", "archer", "bandit", "raider", "warband"]
    cv = Canvas(16 * (len(order) + 1) + 8, 28, ("people",))
    cv.use("people")
    for i, role in enumerate(order):
        person(cv, role, 12 + i * 16, 22)
    person(cv, "peasant", 12 + len(order) * 16, 22, child=True)
    return cv, order + ["child"]


def palette_strip():
    cv = Canvas(len(PALETTE) - 1, 1, ("palette",))
    cv.use("palette")
    for i in range(1, len(PALETTE)):
        cv.px(i - 1, 0, i)
    return cv


def save(cv, name, scale=3):
    os.makedirs(OUT, exist_ok=True)
    img = cv.flat()
    img.save(os.path.join(OUT, f"{name}.png"))
    img.resize((cv.w * scale, cv.h * scale), Image.NEAREST).save(os.path.join(OUT, f"{name}_x{scale}.png"))
    pal = [(r, g, b, 0 if i == 0 else 255) for i, (r, g, b) in enumerate(RGB)]
    layers = [(n, cv.layers[n].tobytes()) for n in cv.order]
    aseprite_writer.write(os.path.join(OUT, f"{name}.aseprite"), cv.w, cv.h, pal, layers)


def write_gpl():
    path = os.path.join(OUT, "game1_palette.gpl")
    with open(path, "w") as f:
        f.write("GIMP Palette\nName: Game_1\nColumns: 8\n#\n")
        for i, (name, _) in enumerate(PALETTE[1:], 1):
            r, g, b = RGB[i]
            f.write(f"{r:3d} {g:3d} {b:3d}\t{name}\n")


if __name__ == "__main__":
    for mode in ("day", "night", "winter"):
        save(scene(mode), f"scene_{mode}")
    sheet, _ = character_sheet()
    save(sheet, "characters", scale=8)
    save(palette_strip(), "palette", scale=24)
    write_gpl()
    print("written to", os.path.abspath(OUT))
