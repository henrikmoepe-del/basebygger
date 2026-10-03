extends RefCounted
## The castle's build order, as plain data.
## Each piece is a defence: its "defence" value is what the later 3D
## wave-defence mode will read to know how strong the castle is.
##
## Rects are placeholder art, relative to the castle's ground-centre point
## (x right, y up is negative). "layer" decides draw order: low = behind.
## "work" is how many seconds one builder needs to finish the piece.

const STONE := Color(0.64, 0.64, 0.68)
const STONE_DARK := Color(0.50, 0.50, 0.55)
const WOOD := Color(0.48, 0.32, 0.20)
const WOOD_DARK := Color(0.33, 0.21, 0.13)
const BANNER := Color(0.78, 0.22, 0.22)

const PIECES := [
	{
		"id": "foundation", "name": "Foundation", "defence": 0, "layer": 0, "work": 3,
		"cost": {"stone": 5},
		"color": STONE_DARK,
		"rects": [Rect2(-110, -12, 220, 12)],
	},
	{
		"id": "wall", "name": "Curtain Wall", "defence": 10, "layer": 0, "work": 8,
		"cost": {"stone": 10, "wood": 5},
		"color": STONE,
		"rects": [Rect2(-100, -52, 200, 40)],
	},
	{
		"id": "gate", "name": "Gate", "defence": 5, "layer": 1, "work": 6,
		"cost": {"wood": 15},
		"color": WOOD,
		"rects": [Rect2(-16, -40, 32, 40)],
		"detail_color": WOOD_DARK,
		"details": [Rect2(-16, -30, 32, 3), Rect2(-16, -14, 32, 3), Rect2(-1, -40, 2, 40)],
	},
	{
		"id": "tower_left", "name": "Left Tower", "defence": 15, "layer": 1, "work": 15,
		"cost": {"stone": 25, "wood": 10},
		"color": STONE,
		"rects": [
			Rect2(-124, -92, 36, 92),
			Rect2(-124, -100, 8, 8), Rect2(-110, -100, 8, 8), Rect2(-96, -100, 8, 8),
		],
		"detail_color": STONE_DARK,
		"details": [Rect2(-109, -76, 6, 14)],
	},
	{
		"id": "tower_right", "name": "Right Tower", "defence": 15, "layer": 1, "work": 18,
		"cost": {"stone": 30, "wood": 12},
		"color": STONE,
		"rects": [
			Rect2(88, -92, 36, 92),
			Rect2(88, -100, 8, 8), Rect2(102, -100, 8, 8), Rect2(116, -100, 8, 8),
		],
		"detail_color": STONE_DARK,
		"details": [Rect2(103, -76, 6, 14)],
	},
	{
		"id": "battlements", "name": "Battlements", "defence": 10, "layer": 0, "work": 20,
		"cost": {"stone": 40},
		"color": STONE,
		"rects": [
			Rect2(-84, -60, 12, 8), Rect2(-60, -60, 12, 8), Rect2(-36, -60, 12, 8),
			Rect2(-12, -60, 12, 8), Rect2(12, -60, 12, 8), Rect2(36, -60, 12, 8),
			Rect2(60, -60, 12, 8),
		],
	},
	{
		"id": "keep", "name": "Keep", "defence": 25, "layer": -1, "work": 45,
		"cost": {"stone": 80, "wood": 40},
		"color": STONE_DARK,
		"rects": [
			Rect2(-40, -140, 80, 140),
			Rect2(-40, -148, 8, 8), Rect2(-22, -148, 8, 8), Rect2(-4, -148, 8, 8),
			Rect2(14, -148, 8, 8), Rect2(32, -148, 8, 8),
		],
		"detail_color": Color(0.25, 0.25, 0.30),
		"details": [Rect2(-22, -122, 8, 16), Rect2(14, -122, 8, 16), Rect2(-4, -92, 8, 16)],
	},
	{
		"id": "banner", "name": "Banner", "defence": 5, "layer": -1, "work": 10,
		"cost": {"wood": 60},
		"color": WOOD_DARK,
		"rects": [Rect2(-1, -178, 2, 30)],
		"detail_color": BANNER,
		"details": [Rect2(1, -178, 18, 10)],
	},
]
