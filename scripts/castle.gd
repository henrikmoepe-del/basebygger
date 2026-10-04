extends Node2D
## Draws the castle from GameState's part levels, and knows where peasants can
## walk on it.
##
## A part being raised is built piece by piece, following the job's plan in
## GameState (see build_plan.gd): scaffolding bay by bay, stone block by
## block and course by course, and each window, door and battlement set in
## place. This node draws what is in place so far, the yard at the foot of
## the site (the piles and the bench) and the hoist, and tells builders where
## to stand for each step.
##
## The castle is drawn in two layers: the curtain wall and everything outside
## it here, and the courtyard buildings (CastleData.FRONT) on a child node in
## front. Peasants up on the wall are drawn between the two (see worker.gd).

const CastleData = preload("res://scripts/castle_data.gd")
const BuildPlan = preload("res://scripts/build_plan.gd")
const SCAFFOLD_COLOR := Color(0.48, 0.32, 0.20)
const ROPE_COLOR := Color(0.75, 0.68, 0.50)
const RUNG_SPACING := 5.0
## How far the hoist's beam stands above the builders' feet.
const HOIST_RISE := 20.0
## Seconds for a hoisted stone to reach the top.
const HOIST_TIME := 1.2
## The most pieces shown in each pile at the site.
const MAX_PILE := 6
## The yard at the foot of the site, as distances east of the rope: the
## shaped pieces wait by the rope, then the bench, then the rough pile.
const READY_PILE := 8.0
const BENCH := 30.0
const ROUGH_PILE := 44.0
const BENCH_COLOR := Color(0.40, 0.27, 0.17)
const FLASH_TIME := 0.5
const DUST := Color(0.85, 0.82, 0.72)
## The front layer is drawn above peasants on the wall and below everyone else.
const FRONT_Z := 2
## A peasant this close above or below a floor counts as standing on it.
const FLOOR_SNAP := 16.0
## Chips fly from this many pieces at most when several land at once.
const MAX_BURSTS := 3
const FAR := 100000.0

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

## The job's plan, straight from GameState (see build_plan.gd).
var _plan: Array:
	get:
		return GameState.job_pieces()
var _plan_sections: Array:
	get:
		return GameState.job_plan.get("sections", [])
var _plan_scaffolded: bool:
	get:
		return GameState.job_plan.get("scaffolded", false)
## How many pieces are in place.
var _placed: int:
	get:
		return GameState.job_placed
## How many pieces were in place the last time this node looked.
var _seen_placed := 0


func _ready() -> void:
	_front.z_index = FRONT_Z
	add_child(_front)
	_front.draw.connect(_draw_layer.bind(_front, true))
	_known_levels = GameState.part_levels.duplicate()
	GameState.castle_changed.connect(_on_castle_changed)
	GameState.job_progress_changed.connect(_on_progress)
	_seen_placed = _placed
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
	_seen_placed = _placed
	_rebuild_floors()
	_redraw()


## Pieces moved along or were put in place: chips fly from the new ones.
func _on_progress() -> void:
	var now := mini(_placed, _plan.size())
	if now > _seen_placed:
		for i in range(maxi(_seen_placed, now - MAX_BURSTS), now):
			var piece: Dictionary = _plan[i]
			get_tree().call_group("effects", "burst", to_global(piece.rect.get_center()), piece.color, 3)
		get_tree().call_group("sfx", "play", "place")
	_seen_placed = now
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
		if part == GameState.job_part and not _plan.is_empty():
			_draw_job(canvas)
		else:
			_draw_shapes(canvas, CastleData.shapes(part, level))
		if part == _flash_part:
			var glow := 0.8 * (1.0 - _flash_age / FLASH_TIME)
			for shape: Array in CastleData.shapes(part, level):
				canvas.draw_rect(shape[0], Color(1, 1, 1, glow))
		for flat: Dictionary in CastleData.floors(part, level):
			if not flat.hidden:
				for x: float in flat.stairs:
					_draw_ladder(canvas, x, flat.y)
	if not _plan.is_empty() and (GameState.job_part in CastleData.FRONT) == front:
		_draw_scaffold(canvas)
		_draw_yard(canvas)
		_draw_hoists(canvas)


## A builder at the top starts pulling a load up the rope.
func show_hoist() -> void:
	_hoists.append(0.0)
	_redraw()


# --- The part being built ---

## True if the part being built has a scaffold to climb.
func job_has_scaffold() -> bool:
	return not _plan.is_empty() and _plan_scaffolded


## Where the materials for the part being built are dropped and lifted from.
## Parts without a scaffold are built from the ground.
func hoist_x() -> float:
	if not job_has_scaffold():
		return CastleData.PARTS[GameState.job_part].site_x
	return CastleData.hoist_x(GameState.job_part, _plan_sections[_next_piece().section])


## Where builders drop what they carry from the stockhouse.
func yard_x() -> float:
	return hoist_x() + ROUGH_PILE


## Where a builder stands to shape a piece at the bench.
func bench_x() -> float:
	return hoist_x() + BENCH - 7.0


## Where the next piece to be placed waits for a builder: at the top beside
## the hoist if it was lifted, else with the shaped pieces at the foot.
func pickup_spot() -> Vector2:
	var pieces := _plan
	if GameState.job_taken < pieces.size() and pieces[GameState.job_taken].lift:
		return hoist_spot()
	return Vector2(hoist_x() + READY_PILE, 0)


## Where a builder stands to put a piece in place.
func stand_spot(index: int) -> Vector2:
	return _plan[index].stand


## What a builder carrying a piece holds: the colour of its material.
func item_color(index: int) -> Color:
	return BuildPlan.ITEMS[_plan[mini(index, _plan.size() - 1)].kind].color


## Where the builder who pulls the rope stands: at the top, beside the hoist.
func hoist_spot() -> Vector2:
	var piece := _next_piece()
	var section: Array = _plan_sections[piece.section]
	return Vector2(clampf(hoist_x(), section[0] + 4.0, section[1] - 4.0), piece.stand.y)


## The piece that goes in next (the last one, once all are placed).
func _next_piece() -> Dictionary:
	return _plan[mini(_placed, _plan.size() - 1)]


## The scaffold's ladder is at the end of the section nearest the hoist.
func _ladder_x(section: Array, hoist: float) -> float:
	return BuildPlan.ladder_x(section, hoist)


# --- Where peasants can walk ---

## Every floor a peasant can stand on right now, each {"x0", "x1", "y",
## "stairs", "hidden", "back"}: see CastleData.floors. "back" floors are on or
## behind the curtain wall. The top of the part being built counts too.
func floors() -> Array:
	return _floors + job_floors()


## The floors of what is built, without the scaffold: where guards stand.
func built_floors() -> Array:
	return _floors


## Where the builders stand on the part being built: on the stone laid so
## far in the section they are working on, reached by the scaffold's ladder.
func job_floors() -> Array:
	if not job_has_scaffold():
		return []
	var piece := _next_piece()
	if piece.stand.y > -0.5:
		return []
	var section: Array = _plan_sections[piece.section]
	return [{
		"x0": section[0], "x1": section[1], "y": piece.stand.y, "stairs": [_ladder_x(section, hoist_x())],
		"hidden": false, "back": not GameState.job_part in CastleData.FRONT,
	}]


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


# --- Drawing ---

func _draw_shapes(canvas: CanvasItem, shapes: Array) -> void:
	for shape: Array in shapes:
		canvas.draw_rect(shape[0], shape[1])


## Draws the piece of a shape inside an area.
func _draw_clipped(canvas: CanvasItem, shape: Array, area: Rect2) -> void:
	var piece: Rect2 = shape[0].intersection(area)
	if piece.has_area():
		canvas.draw_rect(piece, shape[1])


## The part being built: the old level, then the new stone laid so far, then
## the fittings in place.
func _draw_job(canvas: CanvasItem) -> void:
	_draw_shapes(canvas, GameState.job_plan.old)
	var done := _placed >= _plan.size()
	var piece := _next_piece()
	for i in _plan_sections.size():
		if done or i < piece.section:
			_draw_shapes(canvas, GameState.job_plan.solid[i])
		elif i == piece.section:
			for shape: Array in GameState.job_plan.solid[i]:
				_draw_clipped(canvas, shape, Rect2(-FAR, piece.line, FAR * 2.0, FAR))
				_draw_clipped(canvas, shape, piece.partial)
	_draw_shapes(canvas, GameState.job_plan.same)
	for i in _plan_sections.size():
		if done or i < piece.section:
			_draw_shapes(canvas, GameState.job_plan.fit[i])
	if not done:
		for i in range(GameState.job_plan.first[piece.section], _placed):
			if _plan[i].kind == BuildPlan.Kind.FITTING:
				canvas.draw_rect(_plan[i].rect, _plan[i].color)


## A ladder from the ground up to top.
func _draw_ladder(canvas: CanvasItem, x: float, top: float) -> void:
	canvas.draw_rect(Rect2(x - 3, top, 1, -top), CastleData.WOOD_DARK)
	canvas.draw_rect(Rect2(x + 2, top, 1, -top), CastleData.WOOD_DARK)
	var y := -RUNG_SPACING
	while y > top:
		canvas.draw_rect(Rect2(x - 2, y, 4, 1), CastleData.WOOD)
		y -= RUNG_SPACING


## The bays of scaffolding put up so far on the section being worked on: a
## pole at each side and planks across, and the ladder the builders climb.
func _draw_scaffold(canvas: CanvasItem) -> void:
	if not _plan_scaffolded or _placed >= _plan.size():
		return
	var piece := _next_piece()
	var lift := BuildPlan.LIFT_ROWS * CastleData.course(GameState.job_part)
	for i in range(GameState.job_plan.first[piece.section], _placed):
		var bay: Dictionary = _plan[i]
		if bay.kind != BuildPlan.Kind.SCAFFOLD:
			continue
		var area: Rect2 = bay.rect
		canvas.draw_rect(Rect2(area.position.x - 2, area.position.y, 2, area.size.y), SCAFFOLD_COLOR)
		if bay.end:
			canvas.draw_rect(Rect2(area.end.x, area.position.y, 2, area.size.y), SCAFFOLD_COLOR)
		var y := area.position.y
		while y < -0.5:
			canvas.draw_rect(Rect2(area.position.x - 2, y, area.size.x + 2, 1), SCAFFOLD_COLOR)
			y += lift
	if piece.stand.y < -0.5:
		var section: Array = _plan_sections[piece.section]
		_draw_ladder(canvas, _ladder_x(section, hoist_x()), piece.stand.y)


## The yard at the foot of the site: the rough pile where carriers drop
## their loads, the bench where each piece is shaped, and the shaped pieces
## waiting by the rope. Lifted pieces wait at the top beside the hoist.
func _draw_yard(canvas: CanvasItem) -> void:
	var x := hoist_x()
	var pieces := _plan
	_draw_pile(canvas, Vector2(x + ROUGH_PILE, 0), GameState.job_formed, GameState.job_rough())
	# The bench: a heavy table, with the piece being shaped on top.
	canvas.draw_rect(Rect2(x + BENCH - 6, -7, 12, 2), BENCH_COLOR)
	canvas.draw_rect(Rect2(x + BENCH - 5, -5, 2, 5), BENCH_COLOR)
	canvas.draw_rect(Rect2(x + BENCH + 3, -5, 2, 5), BENCH_COLOR)
	if GameState.job_rough() > 0:
		canvas.draw_rect(Rect2(x + BENCH - 3, -11, 6, 4), BuildPlan.ITEMS[pieces[GameState.job_formed].kind].color)
	_draw_pile(canvas, Vector2(x + READY_PILE, 0), GameState.job_lifted, GameState.job_ready())
	if GameState.job_landed() > 0 and pieces[GameState.job_taken].lift:
		_draw_pile(canvas, hoist_spot() + Vector2(-14, 0), GameState.job_taken, GameState.job_landed())
	elif GameState.job_landed() > 0:
		_draw_pile(canvas, Vector2(x + READY_PILE, 0), GameState.job_taken, GameState.job_landed())


## A small stack of pieces standing at foot: count of them, starting with
## piece number first of the plan (each in its material's colour).
func _draw_pile(canvas: CanvasItem, foot: Vector2, first: int, count: int) -> void:
	var pieces := _plan
	for i in mini(count, MAX_PILE):
		var color: Color = BuildPlan.ITEMS[pieces[mini(first + i, pieces.size() - 1)].kind].color
		canvas.draw_rect(Rect2(foot.x + (i % 3) * 6 + (i / 3) * 3, foot.y - 4 - (i / 3) * 4, 5, 3), color)


## A beam sticking out above the builders, with stones rising on a rope.
func _draw_hoists(canvas: CanvasItem) -> void:
	if not _plan_scaffolded or _placed >= _plan.size() or _next_piece().stand.y > -0.5:
		return
	var x := hoist_x()
	var top: float = _next_piece().stand.y - HOIST_RISE
	canvas.draw_rect(Rect2(x - 10, top, 16, 2), SCAFFOLD_COLOR)
	canvas.draw_rect(Rect2(x - 10, top, 2, HOIST_RISE), SCAFFOLD_COLOR)
	canvas.draw_rect(Rect2(x + 2, top + 2, 1, 4), ROPE_COLOR)
	for age in _hoists:
		var y := lerpf(-4.0, top + 8.0, age / HOIST_TIME)
		canvas.draw_rect(Rect2(x + 2, top + 2, 1, y - top - 2), ROPE_COLOR)
		canvas.draw_rect(Rect2(x - 1, y, 7, 5), CastleData.STONE_LIGHT)
