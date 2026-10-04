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
## "site_x" is where the signpost for an unbuilt part stands, and where builders
## work on parts that need no scaffolding. "scaffold" lists the left and right
## edge of each section that gets scaffolding while it is built: builders
## climb it and work from the top. "hoist_x" is where the rope hangs that
## lifts the materials up to them. All are relative to the castle's
## ground-centre point.
##
## The castle is seen from the side with its front wall cut away: the curtain
## wall and gate stand at the back, and the buildings in FRONT stand in the
## courtyard before it. floors() lists where peasants can walk up there.

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
const STONE_WARM := Color(0.60, 0.56, 0.52)
const SHADOW := Color(0.25, 0.25, 0.30)
const WOOD := Color(0.48, 0.32, 0.20)
const WOOD_DARK := Color(0.33, 0.21, 0.13)
const IRON := Color(0.22, 0.23, 0.27)
const BANNER := Color(0.78, 0.22, 0.22)
const ROOF_RED := Color(0.62, 0.30, 0.24)
const ROOF_BLUE := Color(0.28, 0.38, 0.62)
const PLASTER := Color(0.86, 0.82, 0.70)
const THATCH := Color(0.80, 0.68, 0.36)
## The lines between courses of stone are this much darker than the stone.
const COURSE_SHADE := 0.07

const PARTS := {
	"walls": {
		"benefit": "+10 defence per level", "drawback": "",
		"name": "Walls", "defence": 10, "renown": 1, "cost": {"stone": 12, "wood": 4}, "work": 8.0,
		"site_x": 0.0, "scaffold": [[-270.0, 270.0]], "hoist_x": 215.0,
	},
	"towers": {
		"benefit": "+15 defence per level", "drawback": "",
		"name": "Towers", "defence": 15, "renown": 1, "cost": {"stone": 20, "wood": 8}, "work": 12.0,
		"site_x": 302.0, "scaffold": [[-334.0, -270.0], [270.0, 334.0]], "hoist_x": 342.0,
	},
	"gate": {
		"benefit": "+5 defence per level", "drawback": "",
		"name": "Gate", "defence": 5, "renown": 1, "cost": {"wood": 18, "stone": 4}, "work": 8.0,
		"site_x": 0.0, "scaffold": [[-36.0, 36.0]], "hoist_x": 44.0,
	},
	"keep": {
		"benefit": "+12 defence per level", "drawback": "Raids grow 3% stronger per level",
		"name": "Keep", "defence": 12, "renown": 1, "cost": {"stone": 30, "wood": 15}, "work": 18.0,
		"site_x": -95.0, "scaffold": [[-150.0, -40.0]], "hoist_x": -32.0,
	},
	# The quarry turns the loose stones east of the stockhouse into a proper
	# stone supply (see GameState.quarry_rate).
	"quarry": {
		"benefit": "Stone appears 0.7 a second faster, and 10 more can pile up, per level", "drawback": "Dust: everyone works 2% slower per level",
		"name": "Quarry", "defence": 0, "renown": 1, "cost": {"wood": 24, "stone": 6}, "work": 10.0,
		"site_x": 460.0, "scaffold": [], "village": true, "max_level": 10,
	},
	# The farm's fields add to what the hunting grounds give (see GameState.site_rate).
	"farm": {
		"benefit": "Food appears 0.3 a second faster, and 12 more can wait, per level", "drawback": "",
		"name": "Farm", "defence": 0, "renown": 1, "cost": {"wood": 20, "stone": 4}, "work": 8.0,
		"site_x": 650.0, "scaffold": [], "village": true, "max_level": 10,
	},
	# The mine goes underground for iron, which high castle levels need.
	"mine": {
		"benefit": "Lets peasants mine iron: room for 2 miners per level", "drawback": "Each miner eats double",
		"name": "Mine", "defence": 0, "renown": 2, "cost": {"wood": 40, "stone": 40}, "work": 20.0,
		"site_x": 768.0, "scaffold": [], "village": true, "max_level": 8,
	},
	# Outer defences: cheap wooden works that raiders meet first.
	"palisade": {
		"benefit": "+8 defence per level", "drawback": "",
		"name": "Palisade", "defence": 8, "renown": 1, "cost": {"wood": 20}, "work": 8.0,
		"site_x": -396.0, "scaffold": [],
	},
	"watchtower": {
		"benefit": "+6 defence per level", "drawback": "",
		"name": "Watchtower", "defence": 6, "renown": 1, "cost": {"wood": 22, "stone": 6}, "work": 10.0,
		"site_x": -496.0, "scaffold": [],
	},
	# The garrison is the castle's strongest defence per level. Its soldiers
	# will man the walls in the 3D mode.
	"garrison": {
		"benefit": "+20 defence and room for 2 soldiers per level", "drawback": "Each soldier eats double",
		"name": "Garrison", "defence": 20, "renown": 1, "cost": {"stone": 25, "wood": 20}, "work": 14.0,
		"site_x": 95.0, "scaffold": [[50.0, 140.0]], "hoist_x": 148.0,
	},
	# The court adds no defence, but gives double renown and draws people in:
	# each level makes peasants COURT_HIRE_DISCOUNT cheaper to hire.
	"court": {
		"benefit": "Double renown, and hiring costs 4% less per level", "drawback": "Its household eats 2 food a day per level",
		"name": "Court", "defence": 0, "renown": 2, "cost": {"wood": 25, "stone": 15}, "work": 12.0,
		"site_x": -201.0, "scaffold": [[-236.0, -166.0]], "hoist_x": -158.0,
	},
	# Houses raise how many peasants can live here (see GameState.max_peasants).
	"houses": {
		"benefit": "Room for 4 more peasants per level", "drawback": "",
		"name": "Houses", "defence": 0, "renown": 0, "cost": {"wood": 12, "stone": 4}, "work": 6.0,
		"site_x": 938.0, "scaffold": [], "village": true, "max_level": 12,
	},
	# The well and the tavern keep peasants content, which makes them work
	# faster (see GameState.morale_bonus). Each level serves more peasants.
	"well": {
		"benefit": "Up to +15% work speed; each level serves 8 peasants", "drawback": "",
		"name": "Well", "defence": 0, "renown": 1, "cost": {"stone": 16, "wood": 4}, "work": 8.0,
		"site_x": 836.0, "scaffold": [], "village": true, "max_level": 10,
	},
	"tavern": {
		"benefit": "Up to +15% work speed; each level serves 10 peasants", "drawback": "Peasants eat 3% more per level",
		"name": "Tavern", "defence": 0, "renown": 1, "cost": {"wood": 24, "stone": 8}, "work": 10.0,
		"site_x": 870.0, "scaffold": [], "village": true, "max_level": 10,
	},
}
## Back to front.
const DRAW_ORDER := ["houses", "tavern", "well", "mine", "farm", "quarry", "watchtower", "palisade", "walls", "gate", "court", "garrison", "keep", "towers"]
## The parts that stand in the courtyard, in front of the curtain wall. A
## peasant up on the wall walks behind them.
const FRONT := ["court", "garrison", "keep", "towers"]

## Where the village stands, relative to the castle's ground-centre point.
const QUARRY_X := 436.0
const FARM_X := 672.0
const MINE_X := 786.0
const WELL_X := 850.0
const TAVERN_X := 896.0
const FIRST_HOUSE_X := 952.0
const HOUSE_SPACING := 26.0
## The outer defences, west of the castle.
const PALISADE_X := -430.0
const WATCHTOWER_X := -520.0

## The castle itself: the curtain wall runs between the two towers, and the
## court, keep and garrison stand in the courtyard from west to east.
const WALL_HALF := 270.0
const TOWER_WIDTH := 64.0
const TOWER_LEFTS := [-334.0, 270.0]
const KEEP_LEFT := -150.0
const KEEP_WIDTH := 110.0
const COURT_LEFT := -236.0
const COURT_WIDTH := 70.0
const GARRISON_LEFT := 50.0
const GARRISON_WIDTH := 90.0
## Shapes thinner than this are details (windows, courses, battlements), not
## the body of a part.
const BODY_MIN_SIZE := 12.0


## How tall the main body of a castle part is at a level. Its top is where
## peasants stand, and where builders work while it is raised. 0 for parts
## that are not built upwards (see build_y).
static func height(part: String, level: int) -> float:
	if level <= 0:
		return 0.0
	var v := mini(level, MAX_VISUAL_LEVEL)
	match part:
		"walls":
			return 40.0 + 9.0 * v
		"towers":
			return 70.0 + 14.0 * v
		"gate":
			return 34.0 + 4.0 * mini(v, 7) + (8.0 if level >= 2 else 0.0)
		"keep":
			return 90.0 + 16.0 * v
		"garrison":
			return 48.0 + 9.0 * v
		"court":
			return 44.0 + 8.0 * v
		"watchtower":
			return 44.0 + 7.0 * v
	return 0.0


## The floors of a part that peasants can stand on, each
## {"x0", "x1", "y", "stairs", "hidden"}: its left and right edge, its height
## (negative = up), and the x of every stair that leads up to it from the
## ground. Hidden stairs are inside the building: a peasant goes in at the
## door and comes out on top.
static func floors(part: String, level: int) -> Array:
	var out := []
	if level <= 0:
		return out
	var y := -height(part, level)
	match part:
		"walls":
			out.append({"x0": -WALL_HALF, "x1": WALL_HALF, "y": y, "stairs": [-254.0, 254.0], "hidden": false})
		"towers":
			for x: float in TOWER_LEFTS:
				out.append({"x0": x + 3.0, "x1": x + TOWER_WIDTH - 3.0, "y": y, "stairs": [x + TOWER_WIDTH / 2.0], "hidden": true})
		"keep":
			out.append({"x0": KEEP_LEFT + 3.0, "x1": KEEP_LEFT + KEEP_WIDTH - 3.0, "y": y, "stairs": [KEEP_LEFT + KEEP_WIDTH / 2.0], "hidden": true})
		"garrison":
			out.append({"x0": GARRISON_LEFT + 3.0, "x1": GARRISON_LEFT + GARRISON_WIDTH - 3.0, "y": y, "stairs": [GARRISON_LEFT + GARRISON_WIDTH / 2.0], "hidden": true})
		"watchtower":
			out.append({"x0": WATCHTOWER_X - 13.0, "x1": WATCHTOWER_X + 13.0, "y": y, "stairs": [WATCHTOWER_X], "hidden": false})
	return out


## The doors at ground level that peasants can go in by, as x positions.
static func doors(part: String, level: int) -> Array:
	if level <= 0:
		return []
	match part:
		"towers":
			return [TOWER_LEFTS[0] + TOWER_WIDTH / 2.0, TOWER_LEFTS[1] + TOWER_WIDTH / 2.0]
		"keep":
			return [KEEP_LEFT + KEEP_WIDTH / 2.0]
		"garrison":
			return [GARRISON_LEFT + GARRISON_WIDTH / 2.0]
		"court":
			return [COURT_LEFT + COURT_WIDTH / 2.0]
		"houses":
			var out := []
			for i in mini(level, MAX_VISUAL_LEVEL):
				out.append(FIRST_HOUSE_X + HOUSE_SPACING * i)
			return out
		"tavern":
			return [TAVERN_X]
	return []


## True for the main bodies of a part, false for its small details.
static func is_body(area: Rect2) -> bool:
	return minf(area.size.x, area.size.y) >= BODY_MIN_SIZE


## A stone body with the lines between its courses.
static func _masonry(out: Array, area: Rect2, color: Color, course: float) -> void:
	out.append([area, color])
	var y := area.end.y - course
	while y > area.position.y:
		out.append([Rect2(area.position.x, y, area.size.x, 1), color.darkened(COURSE_SHADE)])
		y -= course


## Placeholder art for a part at a level: a list of [Rect2, Color], relative to
## the castle's ground-centre point (x right, up is negative y).
static func shapes(part: String, level: int) -> Array:
	var out := []
	if level <= 0:
		return out
	var v := mini(level, MAX_VISUAL_LEVEL)
	var h := height(part, level)
	match part:
		"walls":
			# The curtain wall, with a walk along its top.
			_masonry(out, Rect2(-WALL_HALF, -h, WALL_HALF * 2, h), STONE, 9.0)
			out.append([Rect2(-WALL_HALF - 6, -8, WALL_HALF * 2 + 12, 8), STONE_DARK])
			if level >= 2:
				for i in 30:
					out.append([Rect2(-WALL_HALF + i * 18, -h - 7, 10, 7), STONE])
		"towers":
			for x: float in TOWER_LEFTS:
				_masonry(out, Rect2(x, -h, TOWER_WIDTH, h), STONE_LIGHT, 14.0)
				out.append([Rect2(x - 3, -10, TOWER_WIDTH + 6, 10), STONE])
				# An arrow slit on every storey.
				var slit := -h + 22.0
				while slit < -44.0:
					out.append([Rect2(x + 29, slit, 6, 16), SHADOW])
					slit += 44.0
				out.append([Rect2(x + 25, -18, 14, 18), WOOD_DARK])
				if level >= 3:
					# The top juts out over the tower.
					out.append([Rect2(x - 4, -h, TOWER_WIDTH + 8, 7), STONE])
				if level >= 2:
					for j in 4:
						out.append([Rect2(x + j * 18, -h - 8, 10, 8), STONE_LIGHT])
				if level >= 6:
					out.append([Rect2(x + 56, -h - 34, 2, 34), WOOD_DARK])
					out.append([Rect2(x + 58, -h - 34, 16, 9), BANNER])
		"gate":
			var steps := mini(v, 7)
			var w := 40.0 + 3.0 * steps
			var door := 34.0 + 4.0 * steps
			if level >= 2:
				# Stone arch around the doors, which grows into a gatehouse.
				out.append([Rect2(-w / 2.0 - 7, -h, w + 14, h), STONE_DARK])
			if level >= 5:
				for j in 3:
					out.append([Rect2(-w / 2.0 - 7 + j * (w + 4) / 2.0, -h - 7, 10, 7), STONE_DARK])
			out.append([Rect2(-w / 2.0, -door, w, door), WOOD])
			# Wooden bands at first, iron once the gate is reinforced.
			var band := IRON if level >= 4 else WOOD_DARK
			out.append([Rect2(-w / 2.0, -door * 0.72, w, 3), band])
			out.append([Rect2(-w / 2.0, -door * 0.32, w, 3), band])
			out.append([Rect2(-1, -door, 2, door), band])
		"keep":
			_masonry(out, Rect2(KEEP_LEFT, -h, KEEP_WIDTH, h), STONE_DARK, 16.0)
			out.append([Rect2(KEEP_LEFT - 4, -12, KEEP_WIDTH + 8, 12), SHADOW])
			if level >= 2:
				for j in 6:
					out.append([Rect2(KEEP_LEFT + j * 20, -h - 8, 10, 8), STONE_DARK])
			# A row of windows on every storey.
			var row := -h + 18.0
			while row < -48.0:
				for x: float in [18.0, 51.0, 84.0]:
					out.append([Rect2(KEEP_LEFT + x, row, 8, 16), SHADOW])
				row += 40.0
			out.append([Rect2(KEEP_LEFT + 47, -24, 16, 24), WOOD_DARK])
			if level >= 5:
				out.append([Rect2(KEEP_LEFT + 100, -h - 44, 2, 44), WOOD_DARK])
				out.append([Rect2(KEEP_LEFT + 102, -h - 44, 24, 13), BANNER])
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
			h = 22.0 + 3.0 * mini(v, 8)
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
			h = 12.0 + 3.0 * v
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
			h = 22.0 + 4.0 * v
			for i in 9:
				var x := PALISADE_X - 27 + i * 6
				out.append([Rect2(x, -h, 5, h), WOOD])
				out.append([Rect2(x + 1, -h - 3, 3, 3), WOOD_DARK])
			out.append([Rect2(PALISADE_X - 28, -h * 0.6, 55, 2), WOOD_DARK])
			out.append([Rect2(PALISADE_X - 28, -h * 0.25, 55, 2), WOOD_DARK])
		"watchtower":
			# A wooden lookout on legs, with a ladder up to its floor.
			out.append([Rect2(WATCHTOWER_X - 15, -h, 3, h), WOOD_DARK])
			out.append([Rect2(WATCHTOWER_X + 12, -h, 3, h), WOOD_DARK])
			out.append([Rect2(WATCHTOWER_X - 15, -h * 0.5, 30, 2), WOOD_DARK])
			out.append([Rect2(WATCHTOWER_X - 18, -h, 36, 3), WOOD])
			out.append([Rect2(WATCHTOWER_X - 16, -h - 22, 2, 22), WOOD_DARK])
			out.append([Rect2(WATCHTOWER_X + 14, -h - 22, 2, 22), WOOD_DARK])
			out.append([Rect2(WATCHTOWER_X - 20, -h - 27, 40, 5), THATCH])
		"garrison":
			# Barracks in the courtyard, east of the gate, with a flat roof.
			_masonry(out, Rect2(GARRISON_LEFT, -h, GARRISON_WIDTH, h), STONE_WARM, 9.0)
			out.append([Rect2(GARRISON_LEFT - 4, -h, GARRISON_WIDTH + 8, 6), ROOF_RED])
			var row := -h + 14.0
			while row < -34.0:
				for x: float in [10.0, 30.0, 54.0, 74.0]:
					out.append([Rect2(GARRISON_LEFT + x, row, 6, 10), SHADOW])
				row += 22.0
			out.append([Rect2(GARRISON_LEFT + 38, -20, 14, 20), WOOD_DARK])
			if level >= 4:
				# Weapon rack on the roof once the garrison is established.
				out.append([Rect2(GARRISON_LEFT + 80, -h - 16, 1, 16), WOOD_DARK])
				out.append([Rect2(GARRISON_LEFT + 74, -h - 13, 13, 1), IRON])
		"court":
			# The great hall in the courtyard, west of the keep: timber and plaster.
			out.append([Rect2(COURT_LEFT, -h, COURT_WIDTH, h), PLASTER])
			out.append([Rect2(COURT_LEFT, -h, 3, h), WOOD])
			out.append([Rect2(COURT_LEFT + COURT_WIDTH - 3, -h, 3, h), WOOD])
			var beam := -26.0
			while beam > -h + 8.0:
				out.append([Rect2(COURT_LEFT, beam, COURT_WIDTH, 2), WOOD])
				beam -= 26.0
			out.append([Rect2(COURT_LEFT - 5, -h - 8, COURT_WIDTH + 10, 8), ROOF_BLUE])
			out.append([Rect2(COURT_LEFT + 5, -h - 15, COURT_WIDTH - 10, 7), ROOF_BLUE])
			out.append([Rect2(COURT_LEFT + 17, -h - 21, COURT_WIDTH - 34, 6), ROOF_BLUE])
			out.append([Rect2(COURT_LEFT + 31, -h + 8, 8, 14), ROOF_BLUE])
			if level >= 3:
				out.append([Rect2(COURT_LEFT + 12, -h + 8, 8, 14), ROOF_BLUE])
				out.append([Rect2(COURT_LEFT + 50, -h + 8, 8, 14), ROOF_BLUE])
			out.append([Rect2(COURT_LEFT + 28, -20, 14, 20), WOOD_DARK])
			if level >= 5:
				out.append([Rect2(COURT_LEFT + 34, -h - 39, 1, 18), WOOD_DARK])
				out.append([Rect2(COURT_LEFT + 35, -h - 39, 12, 7), ROOF_BLUE])
	return out


## The highest point of a part at a level (0 = ground, for an unbuilt part).
static func top_y(part: String, level: int) -> float:
	var top := 0.0
	for shape: Array in shapes(part, level):
		top = minf(top, shape[0].position.y)
	return top


## How high builders have to work to raise a part to a level: the top of its
## body, or of everything in it for parts that are not built upwards.
static func build_y(part: String, level: int) -> float:
	var tall := height(part, level)
	return -tall if tall > 0.0 else top_y(part, level)
