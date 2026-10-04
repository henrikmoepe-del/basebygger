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
const READY_PILE := BuildPlan.READY_PILE
const BENCH := BuildPlan.BENCH_AT
const BENCH_GAP := BuildPlan.BENCH_GAP
const ROUGH_PILE := BuildPlan.ROUGH_PILE
const BENCH_COLOR := BuildPlan.BENCH_COLOR
const HATCH := Color(0.33, 0.21, 0.13)
const FLASH_TIME := 0.5
const DUST := Color(0.85, 0.82, 0.72)
## The front layer is drawn above peasants on the wall and below everyone else.
const FRONT_Z := 2
## A peasant this close above or below a floor counts as standing on it.
const FLOOR_SNAP := 16.0
## Chips fly from this many pieces at most when several land at once.
const MAX_BURSTS := 3
const FAR := 100000.0
const FALL_GRAVITY := 420.0
## Stairs inside a building: how much each flight rises, and how far it runs
## to either side of the middle.
const STAIR_FLIGHT := 22.0
const STAIR_HALF := 9.0

## Goes up whenever the floors change, so peasants know to find their way again.
var version := 0

## One entry per stone on its way up: seconds since it left the ground.
var _hoists: Array[float] = []
## Pieces knocked off the old level, on their way to the ground:
## {"rect": Rect2, "color": Color, "speed": float}.
var _falling: Array[Dictionary] = []
## The part that just gained a level, and seconds since it did.
var _flash_part := ""
var _flash_age := 0.0
var _known_levels := {}
var _front := Node2D.new()
## The floors of everything that is built (see floors()).
var _floors: Array = []
## The windows of the courtyard buildings: peasants on the stairs inside
## can be seen through them.
var _windows: Array[Rect2] = []

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
	if not _falling.is_empty():
		for piece in _falling:
			piece.speed += FALL_GRAVITY * delta
			piece.rect.position.y += piece.speed * delta
			if piece.rect.end.y >= 0.0:
				get_tree().call_group("effects", "burst", to_global(Vector2(piece.rect.get_center().x, -2)), DUST, 4)
		_falling = _falling.filter(func(piece: Dictionary) -> bool: return piece.rect.end.y < 0.0)
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
func _draw_layer(canvas, front: bool) -> void:
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
	if front:
		for piece in _falling:
			canvas.draw_rect(piece.rect, piece.color)
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


## Where the rope hangs for the section being worked on. The yard (the piles
## and the benches) is laid out from here, whether or not there is a rope.
func hoist_x() -> float:
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
		if piece.kind == BuildPlan.Kind.DISMANTLE:
			# Old work to knock down: the same, from up on the old wall.
			return stand_spot(GameState.job_taken)
		if piece.lift:
			return hoist_spot()
	return Vector2(hoist_x() + READY_PILE, 0)


## Where a builder stands to put a piece in place. Pieces placed from the
## top of the section are placed from wherever its deck has got to.
func stand_spot(index: int) -> Vector2:
	var piece: Dictionary = _plan[index]
	if piece.top:
		return _on_deck(piece.section, piece.stand.x)
	return piece.stand


## What a builder carrying a piece holds: the colour of its material.
func item_color(index: int) -> Color:
	return _plan[clampi(index, 0, _plan.size() - 1)].color


## What a builder carrying a piece holds: "stone", "plank", "ladder"...
func item_name(index: int) -> String:
	return _plan[clampi(index, 0, _plan.size() - 1)].item


## True if a piece takes two to carry.
func is_heavy(index: int) -> bool:
	return item_name(index) in BuildPlan.HEAVY


## How many pieces one builder can take in a trip, starting with a piece:
## up to most, but stopping before anything that takes two to carry.
func light_run(index: int, most: int) -> int:
	var count := 0
	while count < most and index + count < _plan.size() and _plan[index + count].fetch and not is_heavy(index + count):
		count += 1
	return maxi(count, 1)


## Which store of the stockyard a piece's material comes from.
func item_store(index: int) -> String:
	return BuildPlan.store_for(_plan[clampi(index, 0, _plan.size() - 1)].item)


## True if a piece must wait until every piece before it is in place:
## anything that is set up or taken down (scaffolding, ladders, the hoist),
## and anything set from a scaffold platform. Otherwise one builder could
## take away the platform another is standing on, or build on one that
## isn't there yet. Stone laid from the deck can be laid side by side.
func needs_turn(index: int) -> bool:
	var piece: Dictionary = _plan[index]
	if piece.kind in [BuildPlan.Kind.SCAFFOLD, BuildPlan.Kind.LADDER, BuildPlan.Kind.HOIST, BuildPlan.Kind.REMOVE]:
		return true
	return not piece.top and piece.stand.y < -0.5


## True if the piece is part of the old level being knocked down.
func is_dismantle(index: int) -> bool:
	return _plan[index].kind == BuildPlan.Kind.DISMANTLE


## A piece knocked loose falls to the ground.
func drop(index: int) -> void:
	var piece: Dictionary = _plan[index]
	_falling.append({"rect": piece.rect, "color": piece.color, "speed": 0.0})


## True if the piece is scaffolding being taken down.
func is_removal(index: int) -> bool:
	return _plan[index].kind == BuildPlan.Kind.REMOVE


## Where the builder who pulls the rope stands: on the deck, beside the hoist.
func hoist_spot() -> Vector2:
	var piece := _next_piece()
	var deck: Array = GameState.job_plan.decks[piece.section]
	return _on_deck(piece.section, clampf(hoist_x(), deck[0] + 4.0, deck[1] - 4.0))


## The point on a section's deck at x: on the course being laid where it
## has got that far, else on the course below.
func _on_deck(section: int, x: float) -> Vector2:
	var y := _deck_y(section)
	var step := _deck_step(section)
	if not step.is_empty() and x >= step[0] - 0.5 and x <= step[1] + 0.5:
		y = step[2]
	return Vector2(x, y)


## The stretch of the course being laid that is laid so far, as
## [left, right, height]: builders step up onto it. Empty if there is none.
func _deck_step(section: int) -> Array:
	if _placed >= GameState.job_fetch():
		return []
	var piece := _next_piece()
	if piece.section != section or piece.kind != BuildPlan.Kind.BLOCK or not piece.top or not piece.partial.has_area():
		return []
	# Only the course that sits right on the deck: anything higher (a roof, a
	# turret) is built from the deck itself.
	if absf(piece.partial.end.y - piece.floor) > 0.5:
		return []
	return [piece.partial.position.x, piece.partial.end.x, piece.partial.position.y]


## Where a builder stands to tie a piece on the rope.
func rope_foot() -> Vector2:
	return Vector2(hoist_x() + READY_PILE - 4.0, 0)


## True if there is still work to do up on the deck: a piece that has to be
## pulled up, or one waiting up there to be put in place.
func work_above() -> bool:
	var pieces := _plan
	for i in range(GameState.job_taken, GameState.job_fetch()):
		if pieces[i].lift:
			return true
	return false


## How many benches are set up in the yard being used right now.
func benches_ready() -> int:
	return _standing(BuildPlan.Kind.BENCH)


## True once the hoist is set up on the deck being built on.
func hoist_ready() -> bool:
	return _standing(BuildPlan.Kind.HOIST) > 0


## How many pieces of a kind are set up, and not yet taken away, in the
## section being worked on.
func _standing(kind: BuildPlan.Kind) -> int:
	if _plan.is_empty() or _placed >= GameState.job_fetch():
		return 0
	var section: int = _next_piece().section
	var count := 0
	for i in _placed:
		var piece: Dictionary = _plan[i]
		if piece.kind == kind and piece.section == section:
			count += 1
	return count


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


## The floors where guards stand and idle peasants stroll: those of what is
## built, but not of the part being rebuilt, which is the builders' for now.
func built_floors() -> Array:
	return _floors.filter(func(flat: Dictionary) -> bool: return flat.part != GameState.job_part)


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
				var deck: Array = plan.decks[i]
				out.append({
					"x0": deck[0], "x1": deck[1], "y": y, "stairs": [plan.access[i].x],
					"hidden": plan.access[i].hidden, "back": back, "step": _deck_step(i),
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
	var out := []
	var at := from
	for step: Dictionary in _plain_route(from, to):
		if step.hidden and absf(step.pos.x - at.x) < 0.01:
			# Stairs inside a building go up in flights, back and forth.
			var rise: float = step.pos.y - at.y
			var flights := maxi(int(absf(rise) / STAIR_FLIGHT), 1)
			var side := 1.0
			for i in range(1, flights):
				out.append({"pos": Vector2(at.x + side * STAIR_HALF, at.y + rise * i / flights), "hidden": true, "back": step.back, "stair": true})
				side = -side
			out.append({"pos": step.pos, "hidden": true, "back": step.back, "stair": true})
		else:
			out.append(step)
		at = step.pos
	return out


## The way as straight steps: route() turns the ones inside buildings into flights of stairs.
func _plain_route(from: Vector2, to: Vector2) -> Array:
	var all := floors()
	var start := _floor_at(all, from)
	var goal := _floor_at(all, to)
	var end := Vector2(to.x, _surface(all[goal], to.x) if goal >= 0 else 0.0)
	var end_back: bool = goal >= 0 and all[goal].back
	var steps := []
	var x := from.x
	if start < 0 and from.y < -0.5:
		# Part way up a stair: carry on if it leads to the goal, else go back
		# down it first.
		if goal >= 0 and all[goal].stairs.has(from.x):
			steps.append(_step(Vector2(from.x, _surface(all[goal], from.x)), all[goal].hidden, end_back))
			steps.append(_step(end, false, end_back))
			return steps
		var stair := _stair_floor(all, from.x)
		steps.append(_step(Vector2(from.x, 0), stair >= 0 and all[stair].hidden, stair >= 0 and all[stair].back))
		if goal >= 0:
			var stair_x := _nearest_stair(all[goal], x)
			steps.append(_step(Vector2(stair_x, 0), false, false))
			steps.append(_step(Vector2(stair_x, _surface(all[goal], stair_x)), all[goal].hidden, end_back))
	elif start != goal:
		if start >= 0:
			var flat: Dictionary = all[start]
			if goal >= 0:
				for stair: float in flat.stairs:
					if all[goal].stairs.has(stair):
						# Both floors are on this stair: no need to touch the ground.
						steps.append(_step(Vector2(stair, _surface(flat, stair)), false, flat.back))
						steps.append(_step(Vector2(stair, _surface(all[goal], stair)), all[goal].hidden, end_back))
						steps.append(_step(end, false, end_back))
						return steps
			x = _nearest_stair(flat, from.x)
			steps.append(_step(Vector2(x, _surface(flat, x)), false, flat.back))
			steps.append(_step(Vector2(x, 0), flat.hidden, flat.back))
		if goal >= 0:
			var flat: Dictionary = all[goal]
			var stair_x := _nearest_stair(flat, x)
			steps.append(_step(Vector2(stair_x, 0), false, false))
			steps.append(_step(Vector2(stair_x, _surface(flat, stair_x)), flat.hidden, flat.back))
	steps.append(_step(end, false, end_back))
	return steps


## How high a peasant standing at a point is: on the floor that is there
## (see _surface), or just where they are if there is none.
func surface_at(point: Vector2) -> float:
	var all := floors()
	var found := _floor_at(all, point)
	return _surface(all[found], point.x) if found >= 0 else point.y


## How high a floor is at x. A deck being built on has a step in it: the
## stretch of the next course that is already laid.
func _surface(flat: Dictionary, x: float) -> float:
	var step: Array = flat.get("step", [])
	if not step.is_empty() and x >= step[0] - 0.5 and x <= step[1] + 0.5:
		return step[2]
	return flat.y


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


## The windows of the courtyard buildings (see workers.gd).
func windows() -> Array[Rect2]:
	return _windows


func _rebuild_floors() -> void:
	_windows = []
	for part: String in CastleData.FRONT:
		for shape: Array in CastleData.shapes(part, GameState.part_levels[part]):
			if shape[1] == CastleData.SHADOW and CastleData.is_fitting(shape[0]):
				_windows.append(shape[0])
	_floors = []
	for part: String in CastleData.DRAW_ORDER:
		for flat: Dictionary in CastleData.floors(part, GameState.part_levels[part]):
			flat["back"] = not part in CastleData.FRONT
			flat["part"] = part
			_floors.append(flat)
	version += 1


# --- Drawing ---

func _draw_shapes(canvas, shapes: Array) -> void:
	for shape: Array in shapes:
		canvas.draw_rect(shape[0], shape[1])


## Draws the piece of a shape inside an area.
func _draw_clipped(canvas, shape: Array, area: Rect2) -> void:
	var piece: Rect2 = shape[0].intersection(area)
	if piece.has_area():
		canvas.draw_rect(piece, shape[1])


## The part being built: the old level, then what is laid of the new one so
## far, then the fittings in place.
func _draw_job(canvas) -> void:
	var plan: Dictionary = GameState.job_plan
	_draw_shapes(canvas, plan.old)
	# Once only the scaffolding is left to take down, everything stands.
	var built := mini(_placed, plan.fetch)
	var done: bool = built >= plan.fetch
	var piece := _next_piece()
	# What must come off the old level stays until a builder knocks it down.
	for chunk: Array in plan.gone:
		if chunk[2] >= _placed:
			canvas.draw_rect(chunk[0], chunk[1])
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
func _draw_ladder(canvas, x: float, top: float, bottom := 0.0) -> void:
	canvas.draw_rect(Rect2(x - 3, top, 1, bottom - top), CastleData.WOOD_DARK)
	canvas.draw_rect(Rect2(x + 2, top, 1, bottom - top), CastleData.WOOD_DARK)
	var y := bottom - RUNG_SPACING
	while y > top:
		canvas.draw_rect(Rect2(x - 2, y, 4, 1), CastleData.WOOD)
		y -= RUNG_SPACING


## Everything the builders have set up for the job and not yet taken away
## again: scaffolding, their ladders, the benches. A bay of scaffolding is a
## pole at its side and the planks the builders stand on.
func _draw_scaffold(canvas) -> void:
	# Where builders come up from the stairs inside, there is a hatch in the deck.
	var plan: Dictionary = GameState.job_plan
	if plan.scaffolded and _placed < plan.fetch:
		for i in _plan_sections.size():
			var y := _deck_y(i)
			if plan.access[i].hidden and y < -0.5:
				# An open trapdoor: its frame in the deck and its lid standing up.
				# The stair door is built over it at the end.
				var x: float = plan.access[i].x
				# On top of the course being laid, where that has passed it.
				y = _on_deck(i, x).y
				canvas.draw_rect(Rect2(x - 6, y - 2, 12, 2), HATCH)
				canvas.draw_rect(Rect2(x - 4, y - 1, 8, 1), CastleData.SHADOW)
				canvas.draw_rect(Rect2(x + 5, y - 10, 2, 8), HATCH)
				canvas.draw_rect(Rect2(x + 4, y - 10, 1, 8), CastleData.WOOD)
	for i in mini(_placed, GameState.job_fetch()):
		var piece: Dictionary = _plan[i]
		if piece.removed_by < 0 or piece.removed_by < _placed:
			continue
		var area: Rect2 = piece.rect
		if piece.kind == BuildPlan.Kind.LADDER:
			_draw_ladder(canvas, area.get_center().x, area.position.y, area.end.y)
			continue
		if piece.kind == BuildPlan.Kind.BENCH:
			# A heavy table.
			canvas.draw_rect(Rect2(area.position.x, area.position.y, area.size.x, 2), BENCH_COLOR)
			canvas.draw_rect(Rect2(area.position.x + 1, area.position.y + 2, 2, 5), BENCH_COLOR)
			canvas.draw_rect(Rect2(area.end.x - 3, area.position.y + 2, 2, 5), BENCH_COLOR)
			continue
		if piece.kind == BuildPlan.Kind.HOIST:
			continue
		canvas.draw_rect(Rect2(area.position.x - 2, area.position.y, 2, area.size.y), SCAFFOLD_COLOR)
		if piece.end:
			canvas.draw_rect(Rect2(area.end.x, area.position.y, 2, area.size.y), SCAFFOLD_COLOR)
		# The planks on top are the platform the builders stand on.
		canvas.draw_rect(Rect2(area.position.x - 2, area.position.y, area.size.x + 4, 2), SCAFFOLD_COLOR)


## The piles in the yard at the foot of the site: the rough pile where
## carriers drop their loads, the piece on the bench, and the shaped pieces
## waiting by the rope. Lifted pieces wait at the top beside the hoist.
func _draw_yard(canvas) -> void:
	if _placed >= GameState.job_fetch():
		return
	var x := hoist_x()
	_draw_pile(canvas, Vector2(x + ROUGH_PILE, 0), GameState.job_formed, GameState.job_rough())
	if GameState.job_rough() > 0 and benches_ready() > 0:
		canvas.draw_rect(Rect2(x + BENCH - 3, -11, 6, 4), item_color(GameState.job_formed))
	_draw_pile(canvas, Vector2(x + READY_PILE, 0), GameState.job_lifted, GameState.job_ready())
	if GameState.job_landed() > 0 and _plan[GameState.job_taken].lift:
		_draw_pile(canvas, hoist_spot() + Vector2(-14, 0), GameState.job_taken, GameState.job_landed())
	elif GameState.job_landed() > 0:
		_draw_pile(canvas, Vector2(x + READY_PILE, 0), GameState.job_taken, GameState.job_landed())


## A small stack of pieces standing at foot: count of them, starting with
## piece number first of the plan (each in its material's colour).
func _draw_pile(canvas, foot: Vector2, first: int, count: int) -> void:
	for i in mini(count, MAX_PILE):
		canvas.draw_rect(Rect2(foot.x + (i % 3) * 6 + (i / 3) * 3, foot.y - 4 - (i / 3) * 4, 5, 3), item_color(first + i))


## Every hoist that is set up and not yet taken away: a beam sticking out
## over the edge of its deck. On the one in use, pieces rise on the rope.
func _draw_hoists(canvas) -> void:
	if not _plan_scaffolded:
		return
	var active: int = _next_piece().section if _placed < GameState.job_fetch() else -1
	for i in mini(_placed, GameState.job_fetch()):
		var piece: Dictionary = _plan[i]
		if piece.kind != BuildPlan.Kind.HOIST or piece.removed_by < _placed:
			continue
		var x := CastleData.hoist_x(GameState.job_part, _plan_sections[piece.section])
		var top: float = _deck_y(piece.section) - HOIST_RISE
		canvas.draw_rect(Rect2(x - 10, top, 16, 2), SCAFFOLD_COLOR)
		canvas.draw_rect(Rect2(x - 10, top, 2, HOIST_RISE), SCAFFOLD_COLOR)
		if piece.section == active and _hoists.is_empty():
			# The rope hangs to the ground, with the next piece tied on if a
			# builder below has done so.
			canvas.draw_rect(Rect2(x + 2, top + 2, 1, -top - 6), ROPE_COLOR)
			if GameState.job_hooked:
				canvas.draw_rect(Rect2(x - 1, -6, 7, 5), item_color(GameState.job_lifted))
		else:
			canvas.draw_rect(Rect2(x + 2, top + 2, 1, 4), ROPE_COLOR)
		if piece.section == active:
			for age in _hoists:
				var y := lerpf(-4.0, top + 8.0, age / HOIST_TIME)
				canvas.draw_rect(Rect2(x + 2, top + 2, 1, y - top - 2), ROPE_COLOR)
				canvas.draw_rect(Rect2(x - 1, y, 7, 5), item_color(GameState.job_lifted))
