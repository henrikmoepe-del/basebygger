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
const BENCH_GAP := 14.0
const BENCHES := 2
const ROUGH_PILE := 58.0
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


## Where a builder stands to shape a piece at one of the benches.
func bench_x(bench: int) -> float:
	return hoist_x() + BENCH + bench * BENCH_GAP - 7.0


## Where the next piece to be placed waits for a builder: at the top beside
## the hoist if it was lifted, else with the shaped pieces at the foot.
func pickup_spot() -> Vector2:
	var pieces := _plan
	if GameState.job_taken < pieces.size():
		var piece: Dictionary = pieces[GameState.job_taken]
		if piece.kind == BuildPlan.Kind.REMOVE:
			# Scaffolding to take down: nothing to pick up, go straight to it.
			return piece.stand
		if piece.lift:
			return hoist_spot()
	return Vector2(hoist_x() + READY_PILE, 0)


## Where a builder stands to put a piece in place. Pieces placed from the
## top of the section are placed from wherever its deck has got to.
func stand_spot(index: int) -> Vector2:
	var piece: Dictionary = _plan[index]
	if piece.top:
		return Vector2(piece.stand.x, _deck_y(piece.section))
	return piece.stand


## What a builder carrying a piece holds: the colour of its material.
func item_color(index: int) -> Color:
	return _plan[clampi(index, 0, _plan.size() - 1)].color


## Which store of the stockyard a piece's material comes from.
func item_store(index: int) -> String:
	return BuildPlan.store_for(_plan[clampi(index, 0, _plan.size() - 1)].item)


## True if the piece is scaffolding being taken down.
func is_removal(index: int) -> bool:
	return _plan[index].kind == BuildPlan.Kind.REMOVE


## Where the builder who pulls the rope stands: on the deck, beside the hoist.
func hoist_spot() -> Vector2:
	var piece := _next_piece()
	var section: Array = _plan_sections[piece.section]
	return Vector2(clampf(hoist_x(), section[0] + 4.0, section[1] - 4.0), _deck_y(piece.section))


## How high the deck of a section is right now: the top of what is laid of
## it so far, where builders stand to lay more (0 = still on the ground).
func _deck_y(section: int) -> float:
	var plan: Dictionary = GameState.job_plan
	if _placed >= plan.fetch:
		return plan.tops[section]
	var piece := _next_piece()
	if piece.section == section:
		return piece.floor
	return plan.tops[section] if piece.section > section else 0.0


## The piece that goes in next (the last one, once all are placed).
func _next_piece() -> Dictionary:
	return _plan[mini(_placed, _plan.size() - 1)]


# --- Where peasants can walk ---

## Every floor a peasant can stand on right now, each {"x0", "x1", "y",
## "stairs", "hidden", "back"}: see CastleData.floors. "back" floors are on or
## behind the curtain wall. The top of the part being built counts too.
func floors() -> Array:
	return _floors + job_floors()


## The floors of what is built, without the scaffold: where guards stand.
func built_floors() -> Array:
	return _floors


## Where builders can stand on the part being built: the deck of every
## section that has been started (reached by the building's own stairs or a
## ladder), and every platform of the scaffolding that is standing.
func job_floors() -> Array:
	var out := []
	if _plan.is_empty():
		return out
	var plan: Dictionary = GameState.job_plan
	var back: bool = not GameState.job_part in CastleData.FRONT
	if plan.scaffolded:
		for i in _plan_sections.size():
			var y := _deck_y(i)
			if y < -0.5:
				var section: Array = _plan_sections[i]
				out.append({
					"x0": section[0], "x1": section[1], "y": y, "stairs": [plan.access[i].x],
					"hidden": plan.access[i].hidden, "back": back,
				})
	for platform: Dictionary in plan.platforms:
		if _placed >= platform.from and _placed <= platform.until:
			out.append({
				"x0": platform.x0, "x1": platform.x1, "y": platform.y, "stairs": [platform.ladder],
				"hidden": false, "back": back,
			})
	return out


## The way from one point to another, as a list of steps
## {"pos": Vector2, "hidden": bool, "back": bool}. Peasants only ever move
## along the ground, along a floor, or up and down a stair. Every floor is
## reached from the ground by its stairs, so the way is: along the floor to a
## stair, down, along the ground, up the other stair, along that floor (or
## straight up or down a stair the two floors share). "hidden" steps are
## walked inside a building. A point with no floor under it can't be
## reached: the way then ends on the ground below it.
func route(from: Vector2, to: Vector2) -> Array:
	var all := floors()
	var start := _floor_at(all, from)
	var goal := _floor_at(all, to)
	var end := Vector2(to.x, all[goal].y if goal >= 0 else 0.0)
	var end_back: bool = goal >= 0 and all[goal].back
	var steps := []
	var x := from.x
	if start < 0 and from.y < -0.5:
		# Part way up a stair: carry on if it leads to the goal, else go back
		# down it first.
		if goal >= 0 and all[goal].stairs.has(from.x):
			steps.append(_step(Vector2(from.x, all[goal].y), all[goal].hidden, end_back))
			steps.append(_step(end, false, end_back))
			return steps
		var stair := _stair_floor(all, from.x)
		steps.append(_step(Vector2(from.x, 0), stair >= 0 and all[stair].hidden, stair >= 0 and all[stair].back))
		if goal >= 0:
			var stair_x := _nearest_stair(all[goal], x)
			steps.append(_step(Vector2(stair_x, 0), false, false))
			steps.append(_step(Vector2(stair_x, all[goal].y), all[goal].hidden, end_back))
	elif start != goal:
		if start >= 0:
			var flat: Dictionary = all[start]
			if goal >= 0:
				for stair: float in flat.stairs:
					if all[goal].stairs.has(stair):
						# Both floors are on this stair: no need to touch the ground.
						steps.append(_step(Vector2(stair, flat.y), false, flat.back))
						steps.append(_step(Vector2(stair, all[goal].y), all[goal].hidden, end_back))
						steps.append(_step(end, false, end_back))
						return steps
			x = _nearest_stair(flat, from.x)
			steps.append(_step(Vector2(x, flat.y), false, flat.back))
			steps.append(_step(Vector2(x, 0), flat.hidden, flat.back))
		if goal >= 0:
			var flat: Dictionary = all[goal]
			var stair_x := _nearest_stair(flat, x)
			steps.append(_step(Vector2(stair_x, 0), false, false))
			steps.append(_step(Vector2(stair_x, flat.y), flat.hidden, flat.back))
	steps.append(_step(end, false, end_back))
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


## The part being built: the old level, then what is laid of the new one so
## far, then the fittings in place.
func _draw_job(canvas: CanvasItem) -> void:
	var plan: Dictionary = GameState.job_plan
	_draw_shapes(canvas, plan.old)
	# Once only the scaffolding is left to take down, everything stands.
	var built := mini(_placed, plan.fetch)
	var done: bool = built >= plan.fetch
	var piece := _next_piece()
	# The old battlements and flags stay until new stone is laid over them.
	for shape: Array in plan.gone:
		var covered: bool = shape[0].end.y > piece.line + 0.01 or shape[0].intersects(piece.partial)
		if not done and (shape[2] > piece.section or (shape[2] == piece.section and not covered)):
			canvas.draw_rect(shape[0], shape[1])
	for i in _plan_sections.size():
		if done or i < piece.section:
			_draw_shapes(canvas, plan.solid[i])
		elif i == piece.section:
			for shape: Array in plan.solid[i]:
				_draw_clipped(canvas, shape, Rect2(-FAR, piece.line, FAR * 2.0, FAR))
				_draw_clipped(canvas, shape, piece.partial)
	_draw_shapes(canvas, plan.same)
	for i in built:
		var placed: Dictionary = _plan[i]
		if placed.kind == BuildPlan.Kind.FITTING:
			canvas.draw_rect(placed.rect, placed.color)
		elif placed.kind == BuildPlan.Kind.LADDER and placed.removed_by == -1:
			_draw_ladder(canvas, placed.rect.get_center().x, placed.rect.position.y, placed.rect.end.y)


## A ladder from bottom up to top.
func _draw_ladder(canvas: CanvasItem, x: float, top: float, bottom := 0.0) -> void:
	canvas.draw_rect(Rect2(x - 3, top, 1, bottom - top), CastleData.WOOD_DARK)
	canvas.draw_rect(Rect2(x + 2, top, 1, bottom - top), CastleData.WOOD_DARK)
	var y := bottom - RUNG_SPACING
	while y > top:
		canvas.draw_rect(Rect2(x - 2, y, 4, 1), CastleData.WOOD)
		y -= RUNG_SPACING


## The scaffolding and builders' ladders standing right now: everything that
## has been put up and not yet taken down again. A bay is a pole at its side
## and the planks the builders stand on.
func _draw_scaffold(canvas: CanvasItem) -> void:
	for i in mini(_placed, GameState.job_fetch()):
		var piece: Dictionary = _plan[i]
		if piece.removed_by < 0 or piece.removed_by < _placed:
			continue
		var area: Rect2 = piece.rect
		if piece.kind == BuildPlan.Kind.LADDER:
			_draw_ladder(canvas, area.get_center().x, area.position.y, area.end.y)
			continue
		canvas.draw_rect(Rect2(area.position.x - 2, area.position.y, 2, area.size.y), SCAFFOLD_COLOR)
		if piece.end:
			canvas.draw_rect(Rect2(area.end.x, area.position.y, 2, area.size.y), SCAFFOLD_COLOR)
		# The planks on top are the platform the builders stand on.
		canvas.draw_rect(Rect2(area.position.x - 2, area.position.y, area.size.x + 4, 2), SCAFFOLD_COLOR)


## The yard at the foot of the site: the rough pile where carriers drop
## their loads, the benches where each piece is shaped, and the shaped pieces
## waiting by the rope. Lifted pieces wait at the top beside the hoist.
func _draw_yard(canvas: CanvasItem) -> void:
	if _placed >= GameState.job_fetch():
		return
	var x := hoist_x()
	_draw_pile(canvas, Vector2(x + ROUGH_PILE, 0), GameState.job_formed, GameState.job_rough())
	for bench in BENCHES:
		# A heavy table.
		var at := x + BENCH + bench * BENCH_GAP
		canvas.draw_rect(Rect2(at - 6, -7, 12, 2), BENCH_COLOR)
		canvas.draw_rect(Rect2(at - 5, -5, 2, 5), BENCH_COLOR)
		canvas.draw_rect(Rect2(at + 3, -5, 2, 5), BENCH_COLOR)
	if GameState.job_rough() > 0:
		canvas.draw_rect(Rect2(x + BENCH - 3, -11, 6, 4), item_color(GameState.job_formed))
	_draw_pile(canvas, Vector2(x + READY_PILE, 0), GameState.job_lifted, GameState.job_ready())
	if GameState.job_landed() > 0 and _plan[GameState.job_taken].lift:
		_draw_pile(canvas, hoist_spot() + Vector2(-14, 0), GameState.job_taken, GameState.job_landed())
	elif GameState.job_landed() > 0:
		_draw_pile(canvas, Vector2(x + READY_PILE, 0), GameState.job_taken, GameState.job_landed())


## A small stack of pieces standing at foot: count of them, starting with
## piece number first of the plan (each in its material's colour).
func _draw_pile(canvas: CanvasItem, foot: Vector2, first: int, count: int) -> void:
	for i in mini(count, MAX_PILE):
		canvas.draw_rect(Rect2(foot.x + (i % 3) * 6 + (i / 3) * 3, foot.y - 4 - (i / 3) * 4, 5, 3), item_color(first + i))


## A beam sticking out above the builders, with stones rising on a rope.
func _draw_hoists(canvas: CanvasItem) -> void:
	if not _plan_scaffolded or _placed >= GameState.job_fetch() or _deck_y(_next_piece().section) > -0.5:
		return
	var x := hoist_x()
	var top: float = _deck_y(_next_piece().section) - HOIST_RISE
	canvas.draw_rect(Rect2(x - 10, top, 16, 2), SCAFFOLD_COLOR)
	canvas.draw_rect(Rect2(x - 10, top, 2, HOIST_RISE), SCAFFOLD_COLOR)
	canvas.draw_rect(Rect2(x + 2, top + 2, 1, 4), ROPE_COLOR)
	for age in _hoists:
		var y := lerpf(-4.0, top + 8.0, age / HOIST_TIME)
		canvas.draw_rect(Rect2(x + 2, top + 2, 1, y - top - 2), ROPE_COLOR)
		canvas.draw_rect(Rect2(x - 1, y, 7, 5), CastleData.STONE_LIGHT)
