extends RefCounted
## The castle's parts, as plain data. Each part has a level the player raises.
## Every part is a defence: "defence" is how much each level adds, and the
## later 3D wave-defence mode will read the part levels to build the castle.
## "renown" is how much renown finishing a level gives.
##
## Village buildings ("village": true) are built the same way, but stand east
## of the castle, don't count towards the castle rank, and stop at "max_level".
##
## The castle stands in the middle of the world. Everything to do with
## defence is on its west side (where raiders come from); the stockhouse,
## resources and village are on its east side.
##
## "benefit" and "drawback" are shown on the card when the player points at
## the part. The drawbacks are real: see DRAWBACKS below and where GameState
## uses them.
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
const COURT_HIRE_DISCOUNT := 0.04
## Drawbacks, per level of the part.
const KEEP_RAID_GROWTH := 0.03      ## A richer keep draws stronger raids.
const TAVERN_EXTRA_EATING := 0.03   ## Tavern-goers eat more.
const COURT_FOOD_UPKEEP := 2        ## The court's household eats every day.
const SOLDIER_EXTRA_FOOD := 1.0     ## A soldier eats this many extra shares.
const QUARRY_DUST := 0.02           ## Quarry dust slows everyone's work.
const MINER_EXTRA_FOOD := 1.0       ## A miner eats this many extra shares.
## Castle parts need iron from this level on, this much more per level.
const IRON_FROM_LEVEL := 4
const IRON_PER_LEVEL := 10

const STONE := Color(0.64, 0.64, 0.68)
const STONE_LIGHT := Color(0.70, 0.70, 0.74)
const STONE_DARK := Color(0.50, 0.50, 0.55)
const SHADOW := Color(0.25, 0.25, 0.30)
const WOOD := Color(0.48, 0.32, 0.20)
const WOOD_DARK := Color(0.33, 0.21, 0.13)
const IRON := Color(0.22, 0.23, 0.27)
const BANNER := Color(0.78, 0.22, 0.22)
const ROOF_RED := Color(0.62, 0.30, 0.24)
const ROOF_BLUE := Color(0.28, 0.38, 0.62)
const PLASTER := Color(0.86, 0.82, 0.70)

const PARTS := {
	"walls": {
		"benefit": "+10 defence per level", "drawback": "",
		"name": "Walls", "defence": 10, "renown": 1, "cost": {"stone": 12, "wood": 4}, "work": 8.0,
		"site_x": -60.0, "scaffold": [[-104.0, 104.0]],
	},
	"towers": {
		"benefit": "+15 defence per level", "drawback": "",
		"name": "Towers", "defence": 15, "renown": 1, "cost": {"stone": 20, "wood": 8}, "work": 12.0,
		"site_x": -110.0, "scaffold": [[-128.0, -92.0], [92.0, 128.0]],
	},
	"gate": {
		"benefit": "+5 defence per level", "drawback": "",
		"name": "Gate", "defence": 5, "renown": 1, "cost": {"wood": 18, "stone": 4}, "work": 8.0,
		"site_x": 0.0, "scaffold": [[-22.0, 22.0]],
	},
	"keep": {
		"benefit": "+12 defence per level", "drawback": "Raids grow 3% stronger per level",
		"name": "Keep", "defence": 12, "renown": 1, "cost": {"stone": 30, "wood": 15}, "work": 18.0,
		"site_x": 30.0, "scaffold": [[-42.0, 42.0]],
	},
	# The quarry turns the loose stones east of the stockhouse into a proper
	# stone supply (see GameState.quarry_rate).
	"quarry": {
		"benefit": "Stone appears 0.7 a second faster, and 10 more can pile up, per level", "drawback": "Dust: everyone works 2% slower per level",
		"name": "Quarry", "defence": 0, "renown": 1, "cost": {"wood": 24, "stone": 6}, "work": 10.0,
		"site_x": 240.0, "scaffold": [], "village": true, "max_level": 10,
	},
	# The farm's fields add to what the hunting grounds give (see GameState.site_rate).
	"farm": {
		"benefit": "Food appears 0.3 a second faster, and 12 more can wait, per level", "drawback": "",
		"name": "Farm", "defence": 0, "renown": 1, "cost": {"wood": 20, "stone": 4}, "work": 8.0,
		"site_x": 430.0, "scaffold": [], "village": true, "max_level": 10,
	},
	# The mine goes underground for iron, which high castle levels need.
	"mine": {
		"benefit": "Lets peasants mine iron: room for 2 miners per level", "drawback": "Each miner eats double",
		"name": "Mine", "defence": 0, "renown": 2, "cost": {"wood": 40, "stone": 40}, "work": 20.0,
		"site_x": 548.0, "scaffold": [], "village": true, "max_level": 8,
	},
	# Outer defences: cheap wooden works that raiders meet first.
	"palisade": {
		"benefit": "+8 defence per level", "drawback": "",
		"name": "Palisade", "defence": 8, "renown": 1, "cost": {"wood": 20}, "work": 8.0,
		"site_x": -214.0, "scaffold": [],
	},
	"watchtower": {
		"benefit": "+6 defence per level", "drawback": "",
		"name": "Watchtower", "defence": 6, "renown": 1, "cost": {"wood": 22, "stone": 6}, "work": 10.0,
		"site_x": -292.0, "scaffold": [],
	},
	# The garrison is the castle's strongest defence per level. Its soldiers
	# will man the walls in the 3D mode.
	"garrison": {
		"benefit": "+20 defence and room for 2 soldiers per level", "drawback": "Each soldier eats double",
		"name": "Garrison", "defence": 20, "renown": 1, "cost": {"stone": 25, "wood": 20}, "work": 14.0,
		"site_x": 68.0, "scaffold": [[48.0, 88.0]],
	},
	# The court adds no defence, but gives double renown and draws people in:
	# each level makes peasants COURT_HIRE_DISCOUNT cheaper to hire.
	"court": {
		"benefit": "Double renown, and hiring costs 4% less per level", "drawback": "Its household eats 2 food a day per level",
		"name": "Court", "defence": 0, "renown": 2, "cost": {"wood": 25, "stone": 15}, "work": 12.0,
		"site_x": -68.0, "scaffold": [[-88.0, -48.0]],
	},
	# Houses raise how many peasants can live here (see GameState.max_peasants).
	"houses": {
		"benefit": "Room for 4 more peasants per level", "drawback": "",
		"name": "Houses", "defence": 0, "renown": 0, "cost": {"wood": 12, "stone": 4}, "work": 6.0,
		"site_x": 718.0, "scaffold": [], "village": true, "max_level": 12,
	},
	# The well and the tavern keep peasants content, which makes them work
	# faster (see GameState.morale_bonus). Each level serves more peasants.
	"well": {
		"benefit": "Up to +15% work speed; each level serves 8 peasants", "drawback": "",
		"name": "Well", "defence": 0, "renown": 1, "cost": {"stone": 16, "wood": 4}, "work": 8.0,
		"site_x": 616.0, "scaffold": [], "village": true, "max_level": 10,
	},
	"tavern": {
		"benefit": "Up to +15% work speed; each level serves 10 peasants", "drawback": "Peasants eat 3% more per level",
		"name": "Tavern", "defence": 0, "renown": 1, "cost": {"wood": 24, "stone": 8}, "work": 10.0,
		"site_x": 650.0, "scaffold": [[654.0, 698.0]], "village": true, "max_level": 10,
	},
}
## Back to front.
const DRAW_ORDER := ["houses", "tavern", "well", "mine", "farm", "quarry", "watchtower", "palisade", "keep", "court", "garrison", "walls", "towers", "gate"]

## Where the village stands, relative to the castle's ground-centre point.
const QUARRY_X := 216.0
const FARM_X := 452.0
const MINE_X := 566.0
const WELL_X := 630.0
const TAVERN_X := 676.0
const FIRST_HOUSE_X := 732.0
const HOUSE_SPACING := 26.0
## The outer defences, west of the castle.
const PALISADE_X := -230.0
const WATCHTOWER_X := -310.0
const THATCH := Color(0.80, 0.68, 0.36)


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
		"houses":
			# One hut per level, in a row going east.
			for i in v:
				var x := FIRST_HOUSE_X + HOUSE_SPACING * i
				out.append([Rect2(x - 10, -14, 20, 14), PLASTER])
				out.append([Rect2(x - 12, -20, 24, 7), THATCH])
				out.append([Rect2(x - 2, -8, 4, 8), WOOD_DARK])
		"well":
			out.append([Rect2(WELL_X - 7, -7, 14, 7), STONE])
			out.append([Rect2(WELL_X - 5, -5, 10, 3), ROOF_BLUE])
			out.append([Rect2(WELL_X - 8, -18, 1, 11), WOOD_DARK])
			out.append([Rect2(WELL_X + 7, -18, 1, 11), WOOD_DARK])
			# The roof gets grander as the well is improved.
			out.append([Rect2(WELL_X - 10, -20 - mini(v, 4), 20, 3 + mini(v, 4)), ROOF_RED if level >= 4 else THATCH])
		"tavern":
			var h := 22 + 3 * mini(v, 8)
			out.append([Rect2(TAVERN_X - 20, -h, 40, h), PLASTER])
			out.append([Rect2(TAVERN_X - 23, -h - 8, 46, 9), ROOF_RED])
			out.append([Rect2(TAVERN_X - 3, -11, 6, 11), WOOD_DARK])
			out.append([Rect2(TAVERN_X - 15, -h + 6, 7, 7), Color(0.98, 0.82, 0.40)])
			out.append([Rect2(TAVERN_X + 8, -h + 6, 7, 7), Color(0.98, 0.82, 0.40)])
			# The sign.
			out.append([Rect2(TAVERN_X + 20, -h + 2, 6, 1), WOOD_DARK])
			out.append([Rect2(TAVERN_X + 22, -h + 3, 5, 5), BANNER])
		"quarry":
			# A stepped rock face that is cut deeper and wider with each level.
			var h := 12 + 3 * v
			out.append([Rect2(QUARRY_X - 22, -h, 44, h), STONE_DARK])
			out.append([Rect2(QUARRY_X - 22, -h, 44, 3), STONE_LIGHT])
			out.append([Rect2(QUARRY_X - 14, -h * 0.6, 36, h * 0.6), STONE])
			out.append([Rect2(QUARRY_X - 2, -h * 0.3, 24, h * 0.3), STONE_LIGHT])
			if level >= 3:
				# A wooden hoist on top.
				out.append([Rect2(QUARRY_X - 18, -h - 12, 2, 12), WOOD_DARK])
				out.append([Rect2(QUARRY_X - 18, -h - 12, 12, 2), WOOD_DARK])
		"farm":
			# Tilled rows with crops that stand taller as the farm grows, and a barn later on.
			var crop := 2 + mini(v, 6)
			for i in 6:
				var x := FARM_X - 18 + i * 6
				out.append([Rect2(x, -2, 5, 2), WOOD_DARK])
				out.append([Rect2(x + 1, -2 - crop, 3, crop), THATCH if i % 2 == 0 else Color(0.45, 0.68, 0.30)])
			if level >= 3:
				out.append([Rect2(FARM_X + 20, -14, 16, 14), WOOD])
				out.append([Rect2(FARM_X + 18, -19, 20, 6), ROOF_RED])
		"mine":
			# A timber-framed entrance, and a shaft and tunnel under the ground
			# (positive y is below the ground line) that go deeper with each level.
			var depth := 10 + 3 * v
			out.append([Rect2(MINE_X - 10, -16, 3, 16), WOOD_DARK])
			out.append([Rect2(MINE_X + 7, -16, 3, 16), WOOD_DARK])
			out.append([Rect2(MINE_X - 12, -19, 24, 4), WOOD])
			out.append([Rect2(MINE_X - 7, -15, 14, 15), SHADOW])
			out.append([Rect2(MINE_X - 4, 0, 8, depth), SHADOW])
			out.append([Rect2(MINE_X - 4 - 8 * v, depth - 6, 8 + 16 * v, 6), SHADOW])
			out.append([Rect2(MINE_X - 2 - 8 * v, depth - 4, 3, 2), IRON])
			out.append([Rect2(MINE_X + 6 * v, depth - 3, 3, 2), IRON])
		"palisade":
			# A row of sharpened stakes; taller and thicker with each level.
			var h := 16 + 3 * v
			for i in 5:
				var x := PALISADE_X - 12 + i * 6
				out.append([Rect2(x, -h, 5, h), WOOD])
				out.append([Rect2(x + 1, -h - 3, 3, 3), WOOD_DARK])
			out.append([Rect2(PALISADE_X - 13, -h * 0.6, 31, 2), WOOD_DARK])
		"watchtower":
			# A wooden lookout on legs.
			var h := 30 + 5 * v
			out.append([Rect2(WATCHTOWER_X - 9, -h, 2, h), WOOD_DARK])
			out.append([Rect2(WATCHTOWER_X + 7, -h, 2, h), WOOD_DARK])
			out.append([Rect2(WATCHTOWER_X - 9, -h * 0.5, 18, 1), WOOD_DARK])
			out.append([Rect2(WATCHTOWER_X - 12, -h - 10, 24, 10), WOOD])
			out.append([Rect2(WATCHTOWER_X - 14, -h - 14, 28, 4), THATCH])
			out.append([Rect2(WATCHTOWER_X - 3, -h - 7, 6, 4), SHADOW])
		"garrison":
			# Barracks behind the wall, right of the keep.
			var h := 40 + 8 * v
			out.append([Rect2(48, -h, 40, h), STONE_DARK])
			out.append([Rect2(45, -h - 6, 46, 6), ROOF_RED])
			for row in clampi(level, 1, 3):
				out.append([Rect2(54, -h + 8 + row * 18, 5, 8), SHADOW])
				out.append([Rect2(64, -h + 8 + row * 18, 5, 8), SHADOW])
				out.append([Rect2(74, -h + 8 + row * 18, 5, 8), SHADOW])
			if level >= 4:
				# Weapon rack on the roof once the garrison is established.
				out.append([Rect2(84, -h - 18, 1, 12), WOOD_DARK])
				out.append([Rect2(80, -h - 16, 9, 1), IRON])
		"court":
			# Great hall behind the wall, left of the keep.
			var h := 36 + 7 * v
			out.append([Rect2(-88, -h, 40, h), PLASTER])
			out.append([Rect2(-91, -h - 7, 46, 7), ROOF_BLUE])
			out.append([Rect2(-72, -h + 8, 8, 14), ROOF_BLUE])
			if level >= 3:
				out.append([Rect2(-84, -h + 8, 6, 10), ROOF_BLUE])
				out.append([Rect2(-58, -h + 8, 6, 10), ROOF_BLUE])
			if level >= 5:
				out.append([Rect2(-69, -h - 22, 1, 15), WOOD_DARK])
				out.append([Rect2(-68, -h - 22, 10, 6), ROOF_BLUE])
	return out


## The highest point of a part at a level (0 = ground, for an unbuilt part).
static func top_y(part: String, level: int) -> float:
	var top := 0.0
	for shape: Array in shapes(part, level):
		top = minf(top, shape[0].position.y)
	return top
