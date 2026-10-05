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
## "cost" is for level 1; each further level multiplies it by COST_GROWTH.
## How long a level takes to build comes from how many pieces it is made of
## (see build_plan.gd), so "work" and WORK_GROWTH are not used at the moment.
## "site_x" is where the part's circle floats in build mode, and where builders
## work on parts that need no scaffolding. All positions are relative to the
## castle's ground-centre point.
##
## The castle is seen from the side with its front wall cut away: the curtain
## wall and gate stand at the back, and the buildings in FRONT stand in the
## courtyard before it. floors() lists where peasants can walk up there, and
## sections() where the scaffolding goes while a part is raised.

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
## Basic building needs only wood. Later levels need planks as well, this
## many more per level. The FINE buildings need them a level sooner, and twice as many.
const PLANKS_FROM_LEVEL := 3
const PLANKS_PER_LEVEL := 6
const FINE := ["court", "tavern"]
const SAWYERS_PER_LEVEL := 2

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
		"site_x": 300.0,
	},
	"towers": {
		"benefit": "+15 defence per level. More towers rise at levels 3 and 5", "drawback": "",
		"name": "Towers", "defence": 15, "renown": 1, "cost": {"stone": 20, "wood": 8}, "work": 12.0,
		"site_x": 455.0,
	},
	"gate": {
		"benefit": "+5 defence per level", "drawback": "",
		"name": "Gate", "defence": 5, "renown": 1, "cost": {"wood": 18, "stone": 4}, "work": 8.0,
		"site_x": 0.0,
	},
	"keep": {
		"benefit": "+12 defence and a new storey of rooms per level", "drawback": "Raids grow 3% stronger per level",
		"name": "Keep", "defence": 12, "renown": 1, "cost": {"stone": 30, "wood": 15}, "work": 18.0,
		"site_x": -165.0,
	},
	# The quarry turns the loose stones east of the stockhouse into a proper
	# stone supply (see GameState.quarry_rate).
	"quarry": {
		"benefit": "Stone appears 0.7 a second faster, and 10 more can pile up, per level", "drawback": "Dust: everyone works 2% slower per level",
		"name": "Quarry", "defence": 0, "renown": 1, "cost": {"wood": 24, "stone": 6}, "work": 10.0,
		"site_x": 800.0, "village": true, "max_level": 10,
	},
	# The farm's fields add to what the hunting grounds give (see GameState.site_rate).
	"farm": {
		"benefit": "Food appears 0.3 a second faster, and 12 more can wait, per level", "drawback": "",
		"name": "Farm", "defence": 0, "renown": 1, "cost": {"wood": 20, "stone": 4}, "work": 8.0,
		"site_x": 990.0, "village": true, "max_level": 10,
	},
	# The mine goes underground for iron, which high castle levels need.
	"mine": {
		"benefit": "Lets peasants mine iron: room for 2 miners per level", "drawback": "Each miner eats double",
		"name": "Mine", "defence": 0, "renown": 2, "cost": {"wood": 40, "stone": 40}, "work": 20.0,
		"site_x": 1108.0, "village": true, "max_level": 8,
	},
	# The sawmill turns logs into planks, which finer buildings and later
	# levels need on top of wood (see GameState.part_cost).
	"sawmill": {
		"benefit": "Lets peasants saw wood into planks: room for 2 sawyers per level", "drawback": "",
		"name": "Sawmill", "defence": 0, "renown": 1, "cost": {"wood": 30, "stone": 10}, "work": 10.0,
		"site_x": 1185.0, "village": true, "max_level": 6,
	},
	# Outer defences: cheap wooden works that raiders meet first.
	"palisade": {
		"benefit": "+8 defence per level", "drawback": "",
		"name": "Palisade", "defence": 8, "renown": 1, "cost": {"wood": 20}, "work": 8.0,
		"site_x": -580.0,
	},
	"watchtower": {
		"benefit": "+6 defence per level", "drawback": "",
		"name": "Watchtower", "defence": 6, "renown": 1, "cost": {"wood": 22, "stone": 6}, "work": 10.0,
		"site_x": -646.0,
	},
	# The garrison is the castle's strongest defence per level. Its soldiers
	# will man the walls in the 3D mode.
	"garrison": {
		"benefit": "+20 defence and room for 2 soldiers per level", "drawback": "Each soldier eats double",
		"name": "Garrison", "defence": 20, "renown": 1, "cost": {"stone": 25, "wood": 20}, "work": 14.0,
		"site_x": 122.0,
	},
	# The court adds no defence, but gives double renown and draws people in:
	# each level makes peasants COURT_HIRE_DISCOUNT cheaper to hire.
	"court": {
		"benefit": "Double renown, and hiring costs 4% less per level", "drawback": "Its household eats 2 food a day per level",
		"name": "Court", "defence": 0, "renown": 2, "cost": {"wood": 25, "stone": 15}, "work": 12.0,
		"site_x": -365.0,
	},
	# Houses raise how many peasants can live here (see GameState.max_peasants).
	"houses": {
		"benefit": "Room for 4 more peasants per level", "drawback": "",
		"name": "Houses", "defence": 0, "renown": 0, "cost": {"wood": 12, "stone": 4}, "work": 6.0,
		"site_x": 1338.0, "village": true, "max_level": 12,
	},
	# The well and the tavern keep peasants content, which makes them work
	# faster (see GameState.morale_bonus). Each level serves more peasants.
	"well": {
		"benefit": "Up to +15% work speed; each level serves 8 peasants", "drawback": "",
		"name": "Well", "defence": 0, "renown": 1, "cost": {"stone": 16, "wood": 4}, "work": 8.0,
		"site_x": 1250.0, "village": true, "max_level": 10,
	},
	"tavern": {
		"benefit": "Up to +15% work speed; each level serves 10 peasants", "drawback": "Peasants eat 3% more per level",
		"name": "Tavern", "defence": 0, "renown": 1, "cost": {"wood": 24, "stone": 8}, "work": 10.0,
		"site_x": 1296.0, "village": true, "max_level": 10,
	},
}
## Back to front.
const DRAW_ORDER := ["houses", "tavern", "well", "sawmill", "mine", "farm", "quarry", "watchtower", "palisade", "walls", "gate", "court", "garrison", "keep", "towers"]
## The parts that stand in the courtyard, in front of the curtain wall. A
## peasant up on the wall walks behind them.
const FRONT := ["court", "garrison", "keep", "towers"]

## Where the village stands, relative to the castle's ground-centre point.
const QUARRY_X := 776.0
const FARM_X := 1012.0
const MINE_X := 1126.0
const SAWMILL_X := 1185.0
const WELL_X := 1250.0
const TAVERN_X := 1296.0
const FIRST_HOUSE_X := 1352.0
const HOUSE_SPACING := 26.0
## The outer defences, west of the castle.
const PALISADE_X := -580.0
const WATCHTOWER_X := -670.0

## The castle itself: the curtain wall runs between the two end towers, and
## the court, keep and garrison stand in the courtyard from west to east.
## More towers rise along the wall and beside the gate as Towers is levelled.
const WALL_HALF := 420.0
const WALL_STAIRS := [-263.0, 245.0]
const END_TOWER_WIDTH := 70.0
const WALL_TOWER_WIDTH := 44.0
const GATE_TOWER_WIDTH := 24.0
const WALL_TOWERS_FROM := 3
const GATE_TOWERS_FROM := 5
const KEEP_LEFT := -255.0
const KEEP_WIDTH := 180.0
## The keep is built in storeys: you step up into the entrance storey, and
## every storey above is this much higher. Each level of the keep adds one.
## A staircase runs up the middle, with a room on either side on every storey.
const KEEP_ENTRANCE := 12.0
const KEEP_STOREY := 24.0
const KEEP_STAIRWELL := 28.0
const COURT_LEFT := -405.0
const COURT_WIDTH := 80.0
const GARRISON_LEFT := 72.0
const GARRISON_WIDTH := 100.0
## A shape can have this as a third entry, [Rect2, Color, FITTING], to say it
## is made and set in whole however big it is: a door.
const FITTING := "fitting"
## Shapes thinner than this are details (windows, courses, battlements), not
## the body of a part.
const BODY_MIN_SIZE := 12.0
## Details narrower than this are fittings: windows, doors, battlements,
## posts, flags. Builders put each one in place whole.
const FITTING_MAX_WIDTH := 40.0
## Stone is laid in blocks this wide, timber in planks this long.
const BLOCK_WIDTH := 24.0
const PLANK_WIDTH := 12.0


## The towers that stand at a level, each {"x", "w", "h", "kind"}: the two
## "end" towers first, then the "wall" towers, then the "gate" towers.
static func towers(level: int) -> Array:
	var out := []
	if level <= 0:
		return out
	var v := mini(level, MAX_VISUAL_LEVEL)
	for x: float in [WALL_HALF, -WALL_HALF - END_TOWER_WIDTH]:
		out.append({"x": x, "w": END_TOWER_WIDTH, "h": 90.0 + 18.0 * v, "kind": "end"})
	if level >= WALL_TOWERS_FROM:
		for x: float in [186.0, -315.0]:
			out.append({"x": x, "w": WALL_TOWER_WIDTH, "h": 70.0 + 16.0 * v, "kind": "wall"})
	if level >= GATE_TOWERS_FROM:
		for x: float in [34.0, -58.0]:
			out.append({"x": x, "w": GATE_TOWER_WIDTH, "h": 56.0 + 12.0 * v, "kind": "gate"})
	return out


## How tall the main body of a castle part is at a level. Its top is where
## peasants stand. 0 for parts nobody stands on.
static func height(part: String, level: int) -> float:
	if level <= 0:
		return 0.0
	var v := mini(level, MAX_VISUAL_LEVEL)
	match part:
		"walls":
			return 20.0 + 10.0 * v
		"gate":
			return 34.0 + 4.0 * mini(v, 7) + (8.0 if level >= 2 else 0.0)
		"keep":
			return KEEP_ENTRANCE + KEEP_STOREY * keep_storeys(level)
		"garrison":
			return 50.0 + 10.0 * v
		"court":
			return 46.0 + 9.0 * v
		"watchtower":
			return 44.0 + 7.0 * v
	return 0.0


## The parts built of stone (or, for the court, of daub panels): they go up
## in big blocks. Everything else is timber, built of planks.
const BLOCK_BUILT := ["walls", "towers", "gate", "keep", "garrison", "court", "quarry", "well"]


## How many storeys the keep has at a level.
static func keep_storeys(level: int) -> int:
	return 4 + mini(level, MAX_VISUAL_LEVEL) if level > 0 else 0


## The kinds of room in the keep. "benefit" is what one room of the kind
## gives (see the ROOM_ constants and where GameState uses them); the kinds
## in ROOM_PICKS are the ones the player can choose for a new storey.
const ROOMS := {
	"kitchen": {"name": "Kitchen", "benefit": "The cooks work here"},
	"hall": {"name": "Great hall", "benefit": ""},
	"beds": {"name": "Bedchamber", "benefit": "Beds for 3, and room for 2 more peasants"},
	"store": {"name": "Storeroom", "benefit": "Building costs 3% less"},
	"armoury": {"name": "Armoury", "benefit": "Soldiers hit 10% harder"},
	"lord": {"name": "Lord's chamber", "benefit": ""},
}
const ROOM_PICKS := ["beds", "store", "armoury"]
const BEDCHAMBER_PEASANTS := 2
const STOREROOM_DISCOUNT := 0.03
const ARMOURY_MIGHT := 0.10
## The rooms the first keep comes with, as [left room, right room] per storey
## from the entrance storey up. Every storey added after that is the player's
## choice (GameState.keep_picks).
const KEEP_FIRST_ROOMS := [
	["kitchen", "hall"], ["store", "armoury"], ["beds", "beds"], ["beds", "beds"], ["beds", "lord"],
]
## What a storey nobody chose rooms for is fitted out as.
const KEEP_DEFAULT_ROOMS := ["beds", "beds"]


## What each room of the keep is, as [left room, right room] for a storey
## (0 = the entrance storey). picks are the rooms chosen for the storeys
## above the first keep's, lowest first.
static func keep_rooms(storey: int, picks: Array) -> Array:
	if storey < KEEP_FIRST_ROOMS.size():
		return KEEP_FIRST_ROOMS[storey]
	var pick := storey - KEEP_FIRST_ROOMS.size()
	return picks[pick] if pick < picks.size() else KEEP_DEFAULT_ROOMS


## Where the beds stand in a bedchamber this wide, from its left wall.
static func bed_offsets(room_width: float) -> Array:
	return [12.0, 34.0, 56.0].filter(func(x: float) -> bool: return x < room_width - 8.0)


## Where every bed in the keep stands, for peasants to sleep in.
static func keep_beds(level: int, picks: Array) -> Array:
	var out := []
	var storeys := keep_storeys(level)
	var room_width := (KEEP_WIDTH - KEEP_STAIRWELL) / 2.0 - 6.0
	for storey in storeys:
		var rooms := keep_rooms(storey, picks)
		for side in 2:
			if rooms[side] == "beds":
				var left := KEEP_LEFT + 4.0 if side == 0 else KEEP_LEFT + KEEP_WIDTH / 2.0 + KEEP_STAIRWELL / 2.0 + 2.0
				for bed: float in bed_offsets(room_width):
					out.append(Vector2(left + bed, keep_floor_y(storey)))
	return out


## How high the floor of a storey of the keep is (negative = up).
static func keep_floor_y(storey: int) -> float:
	return -(KEEP_ENTRANCE + KEEP_STOREY * storey)


## How tall one course of a part is: builders raise it a course at a time.
## Planks are much thinner than blocks of stone.
static func course(part: String) -> float:
	match part:
		"walls", "garrison":
			return 10.0
		"towers":
			return 12.0
		"keep":
			return 12.0
		"court":
			return 9.0
	return 8.0 if part in BLOCK_BUILT else 4.0


## How wide one block or plank of a part is.
static func block_width(part: String) -> float:
	return BLOCK_WIDTH if part in BLOCK_BUILT else PLANK_WIDTH


## The stretches of a part that get scaffolding while it is raised to a
## level, each [left, right]. Builders finish one before starting the next.
## Parts with none are built from the ground.
static func sections(part: String, level: int) -> Array:
	match part:
		"walls":
			# The east half first: it is nearer the stockhouse.
			return [[0.0, WALL_HALF], [-WALL_HALF, 0.0]]
		"towers":
			var out := []
			for tower: Dictionary in towers(level):
				out.append([tower.x, tower.x + tower.w])
			return out
		"gate":
			return [[-37.0, 37.0]]
		"keep":
			return [[KEEP_LEFT, KEEP_LEFT + KEEP_WIDTH]]
		"garrison":
			return [[GARRISON_LEFT, GARRISON_LEFT + GARRISON_WIDTH]]
		"court":
			return [[COURT_LEFT, COURT_LEFT + COURT_WIDTH]]
	return []


## Where the rope hangs that lifts materials to the top of a section.
static func hoist_x(part: String, section: Array) -> float:
	if part == "walls":
		# In the open ground at the east end, and in front of the gate.
		return PARTS.walls.site_x if section[1] > WALL_HALF / 2.0 else 8.0
	return section[1] + 8.0


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
			out.append({"x0": -WALL_HALF, "x1": WALL_HALF, "y": y, "stairs": WALL_STAIRS, "hidden": false})
		"towers":
			for tower: Dictionary in towers(level):
				if tower.kind != "gate":
					out.append({"x0": tower.x + 3.0, "x1": tower.x + tower.w - 3.0, "y": -tower.h, "stairs": [tower.x + tower.w / 2.0], "hidden": true})
		"keep":
			out.append({"x0": KEEP_LEFT + 3.0, "x1": KEEP_LEFT + KEEP_WIDTH - 3.0, "y": y, "stairs": [KEEP_LEFT + KEEP_WIDTH / 2.0], "hidden": true})
			# Every storey inside is a floor too: the rooms.
			for storey in keep_storeys(level):
				out.append({
					"x0": KEEP_LEFT + 5.0, "x1": KEEP_LEFT + KEEP_WIDTH - 5.0, "y": keep_floor_y(storey),
					"stairs": [KEEP_LEFT + KEEP_WIDTH / 2.0], "hidden": true, "inside": true, "storey": storey,
				})
		"garrison":
			out.append({"x0": GARRISON_LEFT + 3.0, "x1": GARRISON_LEFT + GARRISON_WIDTH - 3.0, "y": y, "stairs": [GARRISON_LEFT + GARRISON_WIDTH / 2.0], "hidden": true})
		"watchtower":
			out.append({"x0": WATCHTOWER_X - 13.0, "x1": WATCHTOWER_X + 13.0, "y": y, "stairs": [WATCHTOWER_X], "hidden": false})
	return out


## The doors at ground level that peasants can go in by, as x positions.
static func doors(part: String, level: int) -> Array:
	var out := []
	if level <= 0:
		return out
	match part:
		"towers":
			for tower: Dictionary in towers(level):
				if tower.kind != "gate":
					out.append(tower.x + tower.w / 2.0)
		"keep":
			out.append(KEEP_LEFT + KEEP_WIDTH / 2.0)
		"garrison":
			out.append(GARRISON_LEFT + GARRISON_WIDTH / 2.0)
		"court":
			out.append(COURT_LEFT + COURT_WIDTH / 2.0)
		"houses":
			for i in mini(level, MAX_VISUAL_LEVEL):
				out.append(FIRST_HOUSE_X + HOUSE_SPACING * i)
		"tavern":
			out.append(TAVERN_X)
	return out


## True for the main bodies of a part, false for its small details.
static func is_body(area: Rect2) -> bool:
	return minf(area.size.x, area.size.y) >= BODY_MIN_SIZE


## True for a shape builders put in place whole: one marked FITTING (a
## door), or any small detail. Everything else is laid block by block.
static func is_fitting_shape(shape: Array) -> bool:
	return shape.size() > 2 or is_fitting(shape[0])


## True for a detail small enough to be put in place whole (see FITTING_MAX_WIDTH).
static func is_fitting(area: Rect2) -> bool:
	return not is_body(area) and area.size.y > 1.5 and area.size.x < FITTING_MAX_WIDTH


## A stone body with the lines between its courses.
static func _masonry(out: Array, area: Rect2, color: Color, course_height: float) -> void:
	out.append([area, color])
	var y := area.end.y - course_height
	while y > area.position.y:
		out.append([Rect2(area.position.x, y, area.size.x, 1), color.darkened(COURSE_SHADE)])
		y -= course_height


## Battlements along the top of a body, spread evenly.
static func _merlons(out: Array, x: float, width: float, top: float, color: Color) -> void:
	var count := int((width - 10.0) / 18.0) + 1
	var start := x + (width - ((count - 1) * 18.0 + 10.0)) / 2.0
	for i in count:
		out.append([Rect2(roundf(start + i * 18.0), top - 8, 10, 8), color])


## A pointed roof, as steps that narrow towards the top. Returns its tip.
static func _cone(out: Array, centre: float, width: float, base: float, color: Color) -> float:
	var half := width / 2.0 + 4.0
	var y := base
	while half > 1.0:
		out.append([Rect2(centre - half, y - 6, half * 2, 6), color])
		half -= 5.0
		y -= 6.0
	return y


## The little stair house on a roof, with the door peasants come out of
## when they climb the stairs inside.
static func _stair_door(out: Array, x: float, roof: float, color: Color) -> void:
	out.append([Rect2(x - 5.5, roof - 15, 11, 15), color])
	out.append([Rect2(x - 3, roof - 11, 6, 11), WOOD_DARK])


## Rows of windows that start a fixed height above the ground, so they stay
## where they are when the part grows taller.
static func _windows(out: Array, left: float, offsets: Array, size: Vector2, first_top: float, spacing: float, body_top: float, color: Color) -> void:
	var y := first_top
	while y > body_top + 10.0:
		for offset: float in offsets:
			out.append([Rect2(left + offset, y, size.x, size.y), color])
		y -= spacing


static func _tower(out: Array, tower: Dictionary, level: int) -> void:
	var x: float = tower.x
	var w: float = tower.w
	var h: float = tower.h
	var middle := x + w / 2.0
	match tower.kind:
		"end":
			_masonry(out, Rect2(x, -h, w, h), STONE_LIGHT, 12.0)
			out.append([Rect2(x - 3, -10, w + 6, 10), STONE])
			_windows(out, x, [w / 2.0 - 3.0], Vector2(6, 16), -64.0, 48.0, -h, SHADOW)
			out.append([Rect2(middle - 7, -18, 14, 18), WOOD_DARK, FITTING])
			if level >= 3:
				# The top juts out over the tower.
				out.append([Rect2(x - 4, -h, w + 8, 7), STONE])
			if level >= 2:
				_merlons(out, x, w, -h, STONE_LIGHT)
			_stair_door(out, middle, -h, STONE)
			if level >= 6:
				# A pointed roof on posts, with room to stand under it.
				out.append([Rect2(x + 3, -h - 26, 2, 26), WOOD_DARK])
				out.append([Rect2(x + w - 5, -h - 26, 2, 26), WOOD_DARK])
				var tip := _cone(out, middle, w, -h - 26, ROOF_BLUE)
				out.append([Rect2(middle - 1, tip - 20, 2, 20), WOOD_DARK])
				out.append([Rect2(middle + 1, tip - 20, 16, 9), BANNER])
		"wall":
			_masonry(out, Rect2(x, -h, w, h), STONE_LIGHT.darkened(0.05), 12.0)
			out.append([Rect2(x - 2, -8, w + 4, 8), STONE])
			_windows(out, x, [w / 2.0 - 3.0], Vector2(6, 14), -58.0, 44.0, -h, SHADOW)
			out.append([Rect2(middle - 6, -16, 12, 16), WOOD_DARK, FITTING])
			_merlons(out, x, w, -h, STONE_LIGHT.darkened(0.05))
			_stair_door(out, middle, -h, STONE)
			if level >= 8:
				out.append([Rect2(x + 2, -h - 24, 2, 24), WOOD_DARK])
				out.append([Rect2(x + w - 4, -h - 24, 2, 24), WOOD_DARK])
				_cone(out, middle, w, -h - 24, ROOF_BLUE)
		"gate":
			_masonry(out, Rect2(x, -h, w, h), STONE, 12.0)
			_windows(out, x, [w / 2.0 - 2.0], Vector2(4, 12), -52.0, 40.0, -h, SHADOW)
			if level >= 7:
				_cone(out, middle, w, -h, ROOF_RED)
			else:
				_merlons(out, x, w, -h, STONE)


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
			_masonry(out, Rect2(-WALL_HALF, -h, WALL_HALF * 2, h), STONE, 10.0)
			out.append([Rect2(-WALL_HALF - 6, -8, WALL_HALF * 2 + 12, 8), STONE_DARK])
			if level >= 2:
				_merlons(out, -WALL_HALF, WALL_HALF * 2, -h, STONE)
		"towers":
			for tower: Dictionary in towers(level):
				_tower(out, tower, level)
		"gate":
			var steps := mini(v, 7)
			var w := 44.0 + 3.0 * steps
			var door := 34.0 + 4.0 * steps
			if level >= 2:
				# Stone arch around the doors, which grows into a gatehouse.
				out.append([Rect2(-w / 2.0 - 7, -h, w + 14, h), STONE_DARK])
			if level >= 5:
				_merlons(out, -w / 2.0 - 7, w + 14, -h, STONE_DARK)
			out.append([Rect2(-w / 2.0, -door, w, door), WOOD])
			# Wooden bands at first, iron once the gate is reinforced.
			var band := IRON if level >= 4 else WOOD_DARK
			out.append([Rect2(-w / 2.0, -door * 0.72, w, 3), band])
			out.append([Rect2(-w / 2.0, -door * 0.32, w, 3), band])
			out.append([Rect2(-1, -door, 2, door), band])
		"keep":
			var middle := KEEP_LEFT + KEEP_WIDTH / 2.0
			_masonry(out, Rect2(KEEP_LEFT, -h, KEEP_WIDTH, h), STONE_DARK, 12.0)
			out.append([Rect2(KEEP_LEFT - 4, -12, KEEP_WIDTH + 8, 12), SHADOW])
			# Two windows to each room, and one on the stairs, on every storey.
			_windows(out, KEEP_LEFT, [18.0, 52.0, 86.0, 120.0, 154.0], Vector2(8, 12), -KEEP_ENTRANCE - KEEP_STOREY - 19.0, KEEP_STOREY, -h, SHADOW)
			out.append([Rect2(middle - 8, -26, 16, 26), WOOD_DARK, FITTING])
			if level >= 2:
				_merlons(out, KEEP_LEFT, KEEP_WIDTH, -h, STONE_DARK)
			var top := -h - 8.0
			if level >= 4:
				# A turret on each corner of the roof.
				for x: float in [KEEP_LEFT - 6.0, KEEP_LEFT + KEEP_WIDTH - 22.0]:
					out.append([Rect2(x, -h - 36, 28, 36), STONE_DARK.lightened(0.08)])
					out.append([Rect2(x + 11, -h - 28, 6, 12), SHADOW])
					if level >= 8:
						_cone(out, x + 14, 28, -h - 36, ROOF_BLUE)
					else:
						_merlons(out, x, 28, -h - 36, STONE_DARK.lightened(0.08))
			if level >= 7:
				# The great tower rises from the middle of the roof.
				var rise := 50.0 + 8.0 * (v - 7)
				out.append([Rect2(middle - 25, -h - rise, 50, rise), STONE_DARK.lightened(0.04)])
				out.append([Rect2(middle - 4, -h - rise + 14, 8, 16), SHADOW])
				# The stair door is in the foot of the great tower.
				out.append([Rect2(middle - 3, -h - 12, 6, 12), WOOD_DARK])
				top = -h - rise - 8.0
				if level >= 10:
					top = _cone(out, middle, 50, -h - rise, ROOF_RED)
				else:
					_merlons(out, middle - 25, 50, -h - rise, STONE_DARK.lightened(0.04))
			else:
				_stair_door(out, middle, -h, STONE)
			if level >= 5:
				# The flag: on the great tower, or beside the stair door until there is one.
				var pole := middle if level >= 7 else middle + 26.0
				out.append([Rect2(pole - 1, top - 36, 2, 36), WOOD_DARK])
				out.append([Rect2(pole + 1, top - 36, 24, 11), BANNER])
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
		"sawmill":
			# An open shed over a saw bench, with a stack of sawn planks beside it.
			h = 18.0 + 2.0 * mini(v, 4)
			out.append([Rect2(SAWMILL_X - 18, -h, 3, h), WOOD_DARK])
			out.append([Rect2(SAWMILL_X + 15, -h, 3, h), WOOD_DARK])
			out.append([Rect2(SAWMILL_X - 23, -h - 6, 46, 6), THATCH])
			out.append([Rect2(SAWMILL_X - 9, -8, 18, 2), WOOD])
			out.append([Rect2(SAWMILL_X - 8, -6, 2, 6), WOOD_DARK])
			out.append([Rect2(SAWMILL_X + 6, -6, 2, 6), WOOD_DARK])
			# A log on the bench, waiting for the saw.
			out.append([Rect2(SAWMILL_X - 7, -11, 14, 3), WOOD])
			for i in mini(level, 4):
				out.append([Rect2(SAWMILL_X + 22, -3 - i * 3, 14, 2), Color(0.78, 0.60, 0.36)])
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
			_masonry(out, Rect2(GARRISON_LEFT, -h, GARRISON_WIDTH, h), STONE_WARM, 10.0)
			out.append([Rect2(GARRISON_LEFT - 4, -h, GARRISON_WIDTH + 8, 6), ROOF_RED])
			# The middle windows are on the stairs.
			_windows(out, GARRISON_LEFT, [12.0, 47.0, 82.0], Vector2(6, 10), -44.0, 24.0, -h, SHADOW)
			_stair_door(out, GARRISON_LEFT + GARRISON_WIDTH / 2.0, -h, STONE_WARM.darkened(0.1))
			out.append([Rect2(GARRISON_LEFT + 43, -20, 14, 20), WOOD_DARK, FITTING])
			if level >= 4:
				# Weapon rack on the roof once the garrison is established.
				out.append([Rect2(GARRISON_LEFT + 88, -h - 16, 2, 16), WOOD_DARK])
				out.append([Rect2(GARRISON_LEFT + 82, -h - 13, 14, 2), IRON])
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
			_windows(out, COURT_LEFT, [36.0] if level < 3 else [14.0, 36.0, 58.0], Vector2(8, 14), -46.0, 26.0, -h - 6.0, ROOF_BLUE)
			out.append([Rect2(COURT_LEFT + 33, -20, 14, 20), WOOD_DARK, FITTING])
			if level >= 5:
				out.append([Rect2(COURT_LEFT + 39, -h - 39, 2, 18), WOOD_DARK])
				out.append([Rect2(COURT_LEFT + 41, -h - 39, 12, 7), ROOF_BLUE])
	return out


## The highest point of a part at a level (0 = ground, for an unbuilt part).
static func top_y(part: String, level: int) -> float:
	var top := 0.0
	for shape: Array in shapes(part, level):
		top = minf(top, shape[0].position.y)
	return top
