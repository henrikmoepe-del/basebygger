extends Node2D
## Draws the castle from GameState's part levels, and knows where peasants can
## walk on it. The part being built shows a faint outline of its next level,
## which fills in upwards as builders work, with scaffolding around it and
## stones hoisted up by rope.
##
## The castle is drawn in two layers: the curtain wall and everything outside
## it here, and the courtyard buildings (CastleData.FRONT) on a child node in
## front. Peasants up on the wall are drawn between the two (see worker.gd).

const CastleData = preload("res://scripts/castle_data.gd")
const PREVIEW_ALPHA := 0.25
const SCAFFOLD_COLOR := Color(0.48, 0.32, 0.20)
const ROPE_COLOR := Color(0.75, 0.68, 0.50)
const PLANK_SPACING := 18.0
const POLE_SPACING := 45.0
const RUNG_SPACING := 5.0
## How far the scaffold stands above the stonework.
const SCAFFOLD_RISE := 10.0
## Seconds for a hoisted stone to reach the top.
const HOIST_TIME := 1.2
## The most stones shown waiting in the pile at the site.
const MAX_PILE := 6
const FLASH_TIME := 0.5
const DUST := Color(0.85, 0.82, 0.72)
## The front layer is drawn above peasants on the wall and below everyone else.
const FRONT_Z := 2
## A peasant this close above or below a floor counts as standing on it.
const FLOOR_SNAP := 14.0
## Builders work within this distance of the hoist, so the walk along the top is short.
const WORK_REACH := 90.0

## Goes up whenever the floors change, so peasants know to find their way again.
var version := 0

## One entry per stone on its way up: seconds since it left the ground.
var _hoists: Array[float] = []
## The part that just gained a level, and seconds since it did.
var _flash_part := ""
var _flash_age := 0.0
var _known_levels := {}
var _front := Node2D.new()
## The floors of everything that is built (see floors()).
var _floors: Array = []


func _ready() -> void:
	_front.z_index = FRONT_Z
	add_child(_front)
	_front.draw.connect(_draw_layer.bind(_front, true))
	_known_levels = GameState.part_levels.duplicate()
	GameState.castle_changed.connect(_on_castle_changed)
	GameState.job_progress_changed.connect(_redraw)
	_rebuild_floors()


## When a part gains a level it flashes white, dust flies from its base,
## the screen shakes a little and a fanfare plays.
func _on_castle_changed() -> void:
	for part: String in GameState.part_levels:
		if GameState.part_levels[part] > _known_levels.get(part, 0):
			_flash_part = part
			_flash_age = 0.0
			for shape: Array in CastleData.shapes(part, GameState.part_levels[part]):
				var area: Rect2 = shape[0]
				if CastleData.is_body(area):
					var base := to_global(Vector2(area.get_center().x, 0))
					get_tree().call_group("effects", "burst", base + Vector2(-area.size.x * 0.4, -2), DUST, 5)
					get_tree().call_group("effects", "burst", base + Vector2(area.size.x * 0.4, -2), DUST, 5)
			get_tree().call_group("camera", "shake", 3.0)
			get_tree().call_group("sfx", "play", "built")
	_known_levels = GameState.part_levels.duplicate()
	_rebuild_floors()
	_redraw()


func _process(delta: float) -> void:
	if _flash_part != "":
		_flash_age += delta
		if _flash_age >= FLASH_TIME:
			_flash_part = ""
		_redraw()
	if _hoists.is_empty():
		return
	for i in _hoists.size():
		_hoists[i] += delta
	_hoists = _hoists.filter(func(age: float) -> bool: return age < HOIST_TIME)
	_redraw()


func _redraw() -> void:
	queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	_draw_layer(self, false)


## Draws the back layer onto this node, or the front layer onto its child.
func _draw_layer(canvas: CanvasItem, front: bool) -> void:
	for part: String in CastleData.DRAW_ORDER:
		if (part in CastleData.FRONT) != front:
			continue
		var level: int = GameState.part_levels[part]
		_draw_shapes(canvas, CastleData.shapes(part, level), 1.0, -INF)
		if part == _flash_part:
			var glow := 0.8 * (1.0 - _flash_age / FLASH_TIME)
			for shape: Array in CastleData.shapes(part, level):
				canvas.draw_rect(shape[0], Color(1, 1, 1, glow))
		if part == GameState.job_part:
			var next := CastleData.shapes(part, level + 1)
			_draw_shapes(canvas, next, PREVIEW_ALPHA, -INF)
			_draw_shapes(canvas, next, 1.0, built_top_y())
		for flat: Dictionary in CastleData.floors(part, level):
			if not flat.hidden:
				for x: float in flat.stairs:
					_draw_ladder(canvas, x, flat.y)
	if GameState.job_part != "" and (GameState.job_part in CastleData.FRONT) == front:
		_draw_scaffold(canvas)
		_draw_pile(canvas)
		_draw_hoists(canvas)


## How high the part under construction has been built so far.
func built_top_y() -> float:
	var part := GameState.job_part
	var level: int = GameState.part_levels[part]
	return lerpf(CastleData.build_y(part, level), CastleData.build_y(part, level + 1), GameState.job_fraction())


## A builder at the top starts pulling a load up the rope.
func show_hoist() -> void:
	_hoists.append(0.0)
	_redraw()


# --- Where peasants can walk ---

## Every floor a peasant can stand on right now, each {"x0", "x1", "y",
## "stairs", "hidden", "back"}: see CastleData.floors. "back" floors are on or
## behind the curtain wall. The scaffold of the part being built counts too.
func floors() -> Array:
	return _floors + job_floors()


## The floors of what is built, without the scaffold: where guards stand.
func built_floors() -> Array:
	return _floors


## The top of the scaffold around the part being built, one floor per section.
## It rises as the part does, and a ladder leads up to it.
func job_floors() -> Array:
	var out := []
	var part := GameState.job_part
	if part == "":
		return out
	var top := built_top_y()
	for section: Array in CastleData.PARTS[part].scaffold:
		out.append({
			"x0": section[0], "x1": section[1], "y": top, "stairs": [_ladder_x(section)],
			"hidden": false, "back": not part in CastleData.FRONT,
		})
	return out


## Where the materials for the part being built are dropped, lifted from,
## and lifted to. Parts without a scaffold are built from the ground.
func hoist_x() -> float:
	var part: Dictionary = CastleData.PARTS[GameState.job_part]
	return part.get("hoist_x", part.site_x)


## True if the part being built has a scaffold to climb.
func job_has_scaffold() -> bool:
	return GameState.job_part != "" and not CastleData.PARTS[GameState.job_part].scaffold.is_empty()


## A spot for a builder to work at: on top of the scaffold near the hoist if
## there is one, else on the ground. along runs from 0 to 1 across the spots.
func work_spot(along: float) -> Vector2:
	var part: Dictionary = CastleData.PARTS[GameState.job_part]
	if part.scaffold.is_empty():
		return Vector2(part.site_x + lerpf(-8.0, 8.0, along), 0)
	var section := _hoist_section()
	var x := clampf(hoist_x(), section[0], section[1])
	return Vector2(lerpf(maxf(section[0] + 6.0, x - WORK_REACH), minf(section[1] - 6.0, x + WORK_REACH), along), built_top_y())


## Where the builder who pulls the rope stands: at the top, beside the hoist.
func hoist_spot() -> Vector2:
	var section := _hoist_section()
	return Vector2(clampf(hoist_x(), section[0] + 4.0, section[1] - 4.0), built_top_y())


## The scaffold section the hoist serves: the one nearest to it.
func _hoist_section() -> Array:
	var x := hoist_x()
	var nearest: Array = []
	for section: Array in CastleData.PARTS[GameState.job_part].scaffold:
		if nearest.is_empty() or absf(clampf(x, section[0], section[1]) - x) < absf(clampf(x, nearest[0], nearest[1]) - x):
			nearest = section
	return nearest


## The way from one point to another, as a list of steps
## {"pos": Vector2, "hidden": bool, "back": bool}. Every floor is reached from
## the ground by its stairs, so the way is: along the floor to a stair, down,
## along the ground, up the other stair, along that floor. "hidden" steps are
## walked inside a building.
func route(from: Vector2, to: Vector2) -> Array:
	var all := floors()
	var start := _floor_at(all, from)
	var goal := _floor_at(all, to)
	var steps := []
	var x := from.x
	if start != goal:
		if start >= 0:
			var flat: Dictionary = all[start]
			x = _nearest_stair(flat, from.x)
			steps.append(_step(Vector2(x, flat.y), false, flat.back))
			steps.append(_step(Vector2(x, 0), flat.hidden, flat.back))
		elif from.y < -0.5:
			# Part way up a stair: carry on if it leads to the goal, else go back down.
			var stair := _stair_floor(all, from.x)
			if goal >= 0 and all[goal].stairs.has(from.x):
				steps.append(_step(Vector2(from.x, all[goal].y), all[goal].hidden, all[goal].back))
				steps.append(_step(to, false, all[goal].back))
				return steps
			steps.append(_step(Vector2(from.x, 0), stair >= 0 and all[stair].hidden, stair >= 0 and all[stair].back))
		if goal >= 0:
			var flat: Dictionary = all[goal]
			var stair_x := _nearest_stair(flat, x)
			steps.append(_step(Vector2(stair_x, 0), false, false))
			steps.append(_step(Vector2(stair_x, flat.y), flat.hidden, flat.back))
	steps.append(_step(to, false, goal >= 0 and all[goal].back))
	return steps


func _step(pos: Vector2, hidden: bool, back: bool) -> Dictionary:
	return {"pos": pos, "hidden": hidden, "back": back}


## The index of the floor a point is on, or -1 for the ground (or mid-air).
func _floor_at(all: Array, point: Vector2) -> int:
	if point.y > -0.5:
		return -1
	var found := -1
	var best := FLOOR_SNAP
	for i in all.size():
		var flat: Dictionary = all[i]
		var off := absf(flat.y - point.y)
		if point.x >= flat.x0 - 2.0 and point.x <= flat.x1 + 2.0 and off <= best:
			best = off
			found = i
	return found


func _nearest_stair(flat: Dictionary, x: float) -> float:
	var nearest: float = flat.stairs[0]
	for stair_x: float in flat.stairs:
		if absf(stair_x - x) < absf(nearest - x):
			nearest = stair_x
	return nearest


## The index of a floor with a stair at x, or -1.
func _stair_floor(all: Array, x: float) -> int:
	for i in all.size():
		if all[i].stairs.has(x):
			return i
	return -1


func _rebuild_floors() -> void:
	_floors = []
	for part: String in CastleData.DRAW_ORDER:
		for flat: Dictionary in CastleData.floors(part, GameState.part_levels[part]):
			flat["back"] = not part in CastleData.FRONT
			_floors.append(flat)
	version += 1


## The scaffold's ladder is at the end of the section nearest the hoist.
func _ladder_x(section: Array) -> float:
	var middle: float = (section[0] + section[1]) / 2.0
	return section[1] - 6.0 if hoist_x() >= middle else section[0] + 6.0


# --- Drawing ---

## Draws shapes, but only the part of each below top_y (-INF for everything).
func _draw_shapes(canvas: CanvasItem, shapes: Array, alpha: float, top_y: float) -> void:
	for shape: Array in shapes:
		var r: Rect2 = shape[0]
		var top := maxf(r.position.y, top_y)
		if top < r.end.y:
			canvas.draw_rect(Rect2(r.position.x, top, r.size.x, r.end.y - top), Color(shape[1], alpha))


## A ladder from the ground up to top.
func _draw_ladder(canvas: CanvasItem, x: float, top: float) -> void:
	canvas.draw_rect(Rect2(x - 3, top, 1, -top), CastleData.WOOD_DARK)
	canvas.draw_rect(Rect2(x + 2, top, 1, -top), CastleData.WOOD_DARK)
	var y := -RUNG_SPACING
	while y > top:
		canvas.draw_rect(Rect2(x - 2, y, 4, 1), CastleData.WOOD)
		y -= RUNG_SPACING


## Poles and planks around each section of the part being built. The scaffold
## stands a little above the stonework, so it climbs as the part does.
func _draw_scaffold(canvas: CanvasItem) -> void:
	var floor_y := built_top_y()
	var top := floor_y - SCAFFOLD_RISE
	for section: Array in CastleData.PARTS[GameState.job_part].scaffold:
		var left: float = section[0] - 3.0
		var right: float = section[1] + 1.0
		var poles := maxi(roundi((right - left) / POLE_SPACING), 1)
		for i in poles + 1:
			canvas.draw_rect(Rect2(roundf(lerpf(left, right, float(i) / poles)), top, 2, -top), SCAFFOLD_COLOR)
		var y := -PLANK_SPACING
		while y > floor_y:
			canvas.draw_rect(Rect2(left, y, right - left + 2, 1), SCAFFOLD_COLOR)
			y -= PLANK_SPACING
		# The planks the builders stand on, and a rail above them.
		canvas.draw_rect(Rect2(left, floor_y, right - left + 2, 2), SCAFFOLD_COLOR)
		canvas.draw_rect(Rect2(left, top, right - left + 2, 1), SCAFFOLD_COLOR)
		_draw_ladder(canvas, _ladder_x(section), floor_y)


## Materials that have been delivered but not lifted yet, stacked at the foot of the hoist.
func _draw_pile(canvas: CanvasItem) -> void:
	var waiting := float(GameState.job_hauled - GameState.job_lifted) / GameState.job_units
	var x: float = hoist_x() + 8.0
	for i in clampi(ceili(waiting * MAX_PILE * 2.0), 0, MAX_PILE):
		canvas.draw_rect(Rect2(x + (i % 3) * 6 + (i / 3) * 3, -4 - (i / 3) * 4, 5, 4), CastleData.STONE_LIGHT)


## A beam sticking out from the top of the scaffold, with stones rising on a rope.
func _draw_hoists(canvas: CanvasItem) -> void:
	if not job_has_scaffold():
		return
	var x := hoist_x()
	var top := built_top_y() - SCAFFOLD_RISE
	canvas.draw_rect(Rect2(x - 8, top, 14, 2), SCAFFOLD_COLOR)
	canvas.draw_rect(Rect2(x + 2, top + 2, 1, 4), ROPE_COLOR)
	for age in _hoists:
		var y := lerpf(-4.0, top + 8.0, age / HOIST_TIME)
		canvas.draw_rect(Rect2(x + 2, top + 2, 1, y - top - 2), ROPE_COLOR)
		canvas.draw_rect(Rect2(x - 1, y, 7, 5), CastleData.STONE_LIGHT)
