extends RefCounted
## The castle's parts, as plain data. Each part has a level the player raises.
## Every part is a defence: "defence" is how much each level adds, and the
## later 3D wave-defence mode will read the part levels to build the castle.
##
## "cost" and "work" are for level 1; each further level multiplies them by
## COST_GROWTH and WORK_GROWTH. "work" is seconds of hammering for one builder.
## "site_x" is where builders stand to work on the part, and "scaffold" lists
## the left and right edge of each section that gets scaffolding while it is
## built. Both are relative to the castle's ground-centre point.

const COST_GROWTH := 1.55
const WORK_GROWTH := 1.45
## Parts stop getting visibly bigger past this level (they can still level up).
const MAX_VISUAL_LEVEL := 12

const STONE := Color(0.64, 0.64, 0.68)
const STONE_LIGHT := Color(0.70, 0.70, 0.74)
const STONE_DARK := Color(0.50, 0.50, 0.55)
const SHADOW := Color(0.25, 0.25, 0.30)
const WOOD := Color(0.48, 0.32, 0.20)
const WOOD_DARK := Color(0.33, 0.21, 0.13)
const IRON := Color(0.22, 0.23, 0.27)
const BANNER := Color(0.78, 0.22, 0.22)

const PARTS := {
	"walls": {
		"name": "Walls", "defence": 10, "cost": {"stone": 12, "wood": 4}, "work": 8.0,
		"site_x": -60.0, "scaffold": [[-104.0, 104.0]],
	},
	"towers": {
		"name": "Towers", "defence": 15, "cost": {"stone": 20, "wood": 8}, "work": 12.0,
		"site_x": -110.0, "scaffold": [[-128.0, -92.0], [92.0, 128.0]],
	},
	"gate": {
		"name": "Gate", "defence": 5, "cost": {"wood": 18, "stone": 4}, "work": 8.0,
		"site_x": 0.0, "scaffold": [[-22.0, 22.0]],
	},
	"keep": {
		"name": "Keep", "defence": 12, "cost": {"stone": 30, "wood": 15}, "work": 18.0,
		"site_x": 30.0, "scaffold": [[-42.0, 42.0]],
	},
}
## Back to front.
const DRAW_ORDER := ["keep", "walls", "towers", "gate"]


## Placeholder art for a part at a level: a list of [Rect2, Color], relative to
## the castle's ground-centre point (x right, up is negative y).
static func shapes(part: String, level: int) -> Array:
	var out := []
	if level <= 0:
		return out
	var v := mini(level, MAX_VISUAL_LEVEL)
	match part:
		"walls":
			var h := 22 + 5 * v
			out.append([Rect2(-104, -h, 208, h), STONE])
			out.append([Rect2(-110, -8, 220, 8), STONE_DARK])
			if level >= 3:
				for i in 8:
					out.append([Rect2(-96 + i * 26, -h - 7, 12, 7), STONE])
		"towers":
			var h := 44 + 9 * v
			for x: int in [-128, 92]:
				out.append([Rect2(x, -h, 36, h), STONE_LIGHT])
				out.append([Rect2(x + 15, -h + 14, 6, 14), STONE_DARK])
				if h > 80:
					out.append([Rect2(x + 15, -h + 44, 6, 14), STONE_DARK])
				if level >= 2:
					for j in 3:
						out.append([Rect2(x + j * 14, -h - 8, 8, 8), STONE_LIGHT])
		"gate":
			var w := 26 + 2 * mini(v, 7)
			var h := 24 + 3 * mini(v, 7)
			if level >= 2:
				# Stone arch around the door.
				out.append([Rect2(-w / 2.0 - 4, -h - 4, w + 8, h + 4), STONE_DARK])
			out.append([Rect2(-w / 2.0, -h, w, h), WOOD])
			# Wooden bands at first, iron once the gate is reinforced.
			var band := IRON if level >= 4 else WOOD_DARK
			out.append([Rect2(-w / 2.0, -h * 0.72, w, 3), band])
			out.append([Rect2(-w / 2.0, -h * 0.32, w, 3), band])
			out.append([Rect2(-1, -h, 2, h), band])
		"keep":
			var h := 70 + 12 * v
			out.append([Rect2(-42, -h, 84, h), STONE_DARK])
			if level >= 2:
				for j in 5:
					out.append([Rect2(-42 + j * 19, -h - 8, 8, 8), STONE_DARK])
			for row in clampi(level, 1, 4):
				out.append([Rect2(-22, -h + 14 + row * 26, 8, 14), SHADOW])
				out.append([Rect2(14, -h + 14 + row * 26, 8, 14), SHADOW])
			if level >= 5:
				out.append([Rect2(-1, -h - 36, 2, 36), WOOD_DARK])
				out.append([Rect2(1, -h - 36, 18, 10), BANNER])
	return out


## The highest point of a part at a level (0 = ground, for an unbuilt part).
static func top_y(part: String, level: int) -> float:
	var top := 0.0
	for shape: Array in shapes(part, level):
		top = minf(top, shape[0].position.y)
	return top
