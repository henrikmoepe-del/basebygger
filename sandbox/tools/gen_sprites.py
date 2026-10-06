# Makes sandbox/sb_sprites.gd from people_native.png: the people sheet of the
# Game_1 Art Direction page at 1x (read from its 8x picture). Run:
#   python3 sandbox/tools/gen_sprites.py sandbox/sb_sprites.gd
import sys
from PIL import Image
import os
nat = Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'people_native.png')).convert('RGBA')
FIGS = [(9, 17), (25, 33), (38, 49), (57, 65), (73, 81), (89, 97), (105, 113), (121, 130), (137, 146), (153, 162), (167, 177), (185, 192)]
NAMES = ["peasant", "builder_block", "woodcutter_log", "cook", "straw_hat", "noble", "spearman", "archer", "bandit", "raider", "warband", "child"]
BASE = 21

def grid(i):
    a, b = FIGS[i]
    rows = []
    for y in range(0, BASE + 1):
        rows.append([nat.getpixel((x, y)) for x in range(a, b)])
    # trim empty rows on top
    while rows and all(p[3] == 0 for p in rows[0]):
        rows.pop(0)
    return rows

def recolor(rows, mapping, y_from=0, y_to=99):
    out = []
    n = len(rows)
    for yi, row in enumerate(rows):
        y = BASE - (n - 1 - yi)   # sheet row
        nr = []
        for p in row:
            k = p[:3]
            if y_from <= y <= y_to and k in mapping:
                nr.append(mapping[k] + (255,))
            else:
                nr.append(p)
        out.append(nr)
    return out

HAIR_DARK = (92, 58, 36)
TUNIC = (138, 90, 52)
MAROON = (90, 30, 36)
GREEN_L, GREEN_D = (74, 122, 56), (46, 82, 48)
SLATE_L, SLATE_D = (69, 85, 138), (44, 53, 88)

sprites = {}
peasant = grid(0)
sprites["peasant"] = peasant
b = grid(1)
# builder: drop the block above the head (rows above the hair start at sheet row 6)
sprites["builder"] = b[len(b) - 16:]
sprites["woodcutter"] = recolor(recolor(peasant, {HAIR_DARK: MAROON}, 6, 11), {TUNIC: GREEN_L, HAIR_DARK: GREEN_D}, 12, 21)
sprites["miner"] = recolor(peasant, {TUNIC: SLATE_L, HAIR_DARK: SLATE_D}, 12, 21)
sprites["crafter"] = grid(3)
sprites["forager"] = grid(4)
sprites["noble"] = grid(5)
sprites["guard"] = grid(6)
sprites["hunter"] = grid(7)
sprites["bandit"] = grid(8)
sprites["raider"] = grid(9)
sprites["warband"] = grid(10)
sprites["child"] = grid(11)
sprites["hauler"] = peasant

palette = {}
def ch(p):
    if p[3] == 0:
        return "."
    k = p[:3]
    if k not in palette:
        palette[k] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"[len(palette)]
    return palette[k]

out = []
for name, rows in sprites.items():
    srows = ["".join(ch(p) for p in row) for row in rows]
    # anchor: the middle of the shoes on the bottom row
    xs = [x for x, c in enumerate(srows[-1]) if c != "."]
    anchor = round((min(xs) + max(xs)) / 2.0)
    out.append((name, anchor, srows))

lines = []
lines.append("extends RefCounted")
lines.append("## The people, as pixels read from the Game_1 Art Direction page's people")
lines.append("## sheet (made by a script from the 8x picture; see sandbox/README.md).")
lines.append("## Each sprite: rows from the top down, one letter per pixel (PALETTE),")
lines.append('## "." clear; the bottom row is the feet, `anchor` the x of their middle.')
lines.append("## Builder is the sheet's builder without the block on the head; woodcutter")
lines.append("## and miner are the plain peasant in other colours.")
lines.append("")
lines.append("const PALETTE := {")
for k, c in palette.items():
    lines.append('\t"%s": Color8(%d, %d, %d),' % (c, k[0], k[1], k[2]))
lines.append("}")
lines.append("")
lines.append("const SPRITES := {")
for name, anchor, srows in out:
    lines.append('\t"%s": {"anchor": %d, "rows": [' % (name, anchor))
    for r in srows:
        lines.append('\t\t"%s",' % r)
    lines.append("\t]},")
lines.append("}")
lines.append("")
lines.append('''static var _cache := {}


## The sprite as a texture. Frame 0 stands; 1 and 2 lift the left or right
## foot (the shoe on the bottom row is left out), for walking.
static func texture(name: String, frame := 0) -> Texture2D:
	var key := "%s/%d" % [name, frame]
	if _cache.has(key):
		return _cache[key]
	var s: Dictionary = SPRITES[name]
	var rows: Array = s.rows
	var h := rows.size()
	var w: int = rows[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var c := row[x]
			if c == ".":
				continue
			if y == h - 1 and ((frame == 1 and x < s.anchor) or (frame == 2 and x > s.anchor)):
				continue
			img.set_pixel(x, y, PALETTE[c])
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Where to draw the texture so its feet stand on (0, 0).
static func offset(name: String) -> Vector2:
	var s: Dictionary = SPRITES[name]
	return Vector2(-s.anchor, -s.rows.size())


static func height(name: String) -> int:
	return SPRITES[name].rows.size()''')
open(sys.argv[1], "w").write("\n".join(lines) + "\n")
print("palette", len(palette), "sprites", [(n, a, len(r), len(r[0])) for n, a, r in out])
