extends Node2D
## Draws the castle from GameState's part levels, and knows where peasants can
## walk on it.
##
## A part being raised is built piece by piece (see _make_plan): builders put
## up the scaffolding bay by bay, lay the stone block by block and course by
## course, and set each window, door and battlement in place. How many pieces
## are in place follows the work done, and builders stand where the next
## piece goes.
##
## The castle is drawn in two layers: the curtain wall and everything outside
## it here, and the courtyard buildings (CastleData.FRONT) on a child node in
## front. Peasants up on the wall are drawn between the two (see worker.gd).

enum Kind { BLOCK, FITTING, SCAFFOLD }

const CastleData = preload("res://scripts/castle_data.gd")
const SCAFFOLD_COLOR := Color(0.48, 0.32, 0.20)
const ROPE_COLOR := Color(0.75, 0.68, 0.50)
const RUNG_SPACING := 5.0
## Scaffolding goes up in bays about this wide, with planks this many courses apart.
const BAY_WIDTH := 60.0
const LIFT_ROWS := 2
## How far the hoist's beam stands above the builders' feet.
const HOIST_RISE := 20.0
## Seconds for a hoisted stone to reach the top.
const HOIST_TIME := 1.2
## The most stones shown waiting in the pile at the site.
const MAX_PILE := 6
const FLASH_TIME := 0.5
const DUST := Color(0.85, 0.82, 0.72)
## The front layer is drawn above peasants on the wall and below everyone else.
const FRONT_Z := 2
## A peasant this close above or below a floor counts as standing on it.
const FLOOR_SNAP := 16.0
## Builders stand this far to either side of the piece they are placing.
const WORK_SPREAD := 20.0
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

## The pieces of the part being built, in the order they are placed. Each is
## {"kind", "rect", "color", "section", "stand", "line", "partial", "end"}:
## "stand" is where a builder stands to place it; "line" and "partial" say how
## much stone of its section is laid just before it (everything below line,
## and the partial stretch of the course being laid).
var _plan: Array = []
## "part:level" of the job the plan was made for.
var _plan_key := ""
var _plan_sections: Array = []
var _plan_scaffolded := false
## What is drawn of the old level while the job lasts.
var _plan_old: Array = []
## Fittings of the new level that the old one already had.
var _plan_same: Array = []
## Per section: the new level's stonework, its new fittings, and its first piece.
var _plan_solid: Array = []
var _plan_fit: Array = []
var _plan_first: Array = []
## How many pieces are in place.
var _placed := 0


func _ready() -> void:
	_front.z_index = FRONT_Z
	add_child(_front)
	_front.draw.connect(_draw_layer.bind(_front, true))
	_known_levels = GameState.part_levels.duplicate()
	GameState.castle_changed.connect(_on_castle_changed)
	GameState.job_progress_changed.connect(_on_progress)
	_update_plan()
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
	_update_plan()
	_rebuild_floors()
	_redraw()


## Work was done or materials moved: put the next pieces in place.
func _on_progress() -> void:
	var now := _pieces_done()
	if now > _placed:
		for i in range(maxi(_placed, now - MAX_BURSTS), now):
			var piece: Dictionary = _plan[i]
			get_tree().call_group("effects", "burst", to_global(piece.rect.get_center()), piece.color, 3)
		get_tree().call_group("sfx", "play", "place")
	_placed = now
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
		_draw_pile(canvas)
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


## A spot for a builder to work at: beside where the next piece goes.
## along (0 to 1) spreads the builders out.
func work_spot(along: float) -> Vector2:
	if _plan.is_empty():
		return Vector2(CastleData.PARTS[GameState.job_part].site_x, 0)
	var piece := _next_piece()
	var section: Array = _plan_sections[piece.section]
	var x: float = piece.stand.x + (along - 0.5) * 2.0 * WORK_SPREAD
	return Vector2(clampf(x, section[0] + 3.0, section[1] - 3.0), piece.stand.y)


## Where the builder who pulls the rope stands: at the top, beside the hoist.
func hoist_spot() -> Vector2:
	var piece := _next_piece()
	var section: Array = _plan_sections[piece.section]
	return Vector2(clampf(hoist_x(), section[0] + 4.0, section[1] - 4.0), piece.stand.y)


## The piece that goes in next (the last one, once all are placed).
func _next_piece() -> Dictionary:
	return _plan[mini(_placed, _plan.size() - 1)]


func _pieces_done() -> int:
	return mini(int(GameState.job_fraction() * _plan.size()), _plan.size())


## Makes the plan for the job in GameState, if it isn't made already.
func _update_plan() -> void:
	var part := GameState.job_part
	var key := "" if part == "" else "%s:%d" % [part, GameState.part_levels[part]]
	if key == _plan_key:
		return
	_plan_key = key
	_plan = []
	if part != "":
		_make_plan(part, GameState.part_levels[part])
	_placed = _pieces_done()


## Works out every piece needed to raise a part from a level to the next:
## section by section, the scaffolding first, then the stonework a course at a
## time (only the blocks the old level doesn't have), with each fitting set
## in once the stone has risen past it, and whatever crowns the top last.
func _make_plan(part: String, level: int) -> void:
	var old := CastleData.shapes(part, level)
	var fresh := CastleData.shapes(part, level + 1)
	_plan_sections = CastleData.sections(part, level + 1)
	_plan_scaffolded = not _plan_sections.is_empty()
	if not _plan_scaffolded:
		# Built from the ground: one stretch as wide as the whole part.
		var box: Rect2 = fresh[0][0]
		for shape: Array in fresh:
			box = box.merge(shape[0])
		_plan_sections = [[box.position.x, box.end.x]]

	var old_rects := {}
	var fresh_rects := {}
	var old_solid: Array[Rect2] = []
	for shape: Array in old:
		old_rects[shape[0]] = true
		if not CastleData.is_fitting(shape[0]):
			old_solid.append(shape[0])
	for shape: Array in fresh:
		fresh_rects[shape[0]] = true
	# Old fittings the new level doesn't have (the battlements, the flag) come
	# down when the work starts.
	_plan_old = old.filter(func(shape: Array) -> bool: return not CastleData.is_fitting(shape[0]) or fresh_rects.has(shape[0]))
	_plan_same = []
	_plan_solid = []
	_plan_fit = []
	_plan_first = []
	for i in _plan_sections.size():
		_plan_solid.append([])
		_plan_fit.append([])
	for shape: Array in fresh:
		var section := _nearest_section(shape[0].get_center().x)
		if not CastleData.is_fitting(shape[0]):
			_plan_solid[section].append(shape)
		elif old_rects.has(shape[0]):
			_plan_same.append(shape)
		else:
			_plan_fit[section].append(shape)
	for i in _plan_sections.size():
		_plan_first.append(_plan.size())
		_plan_section(i, CastleData.course(part), old_solid)


func _plan_section(index: int, course: float, old_solid: Array[Rect2]) -> void:
	var section: Array = _plan_sections[index]
	var solid: Array = _plan_solid[index]
	var fittings: Array = _plan_fit[index].duplicate()
	# Lowest first.
	fittings.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0].position.y > b[0].position.y or (a[0].position.y == b[0].position.y and a[0].position.x < b[0].position.x))
	var left: float = section[0]
	var right: float = section[1]
	var top := 0.0
	for shape: Array in solid:
		left = minf(left, shape[0].position.x)
		right = maxf(right, shape[0].end.x)
		top = minf(top, shape[0].position.y)
	var rows := ceili(-top / course)
	var columns := ceili((right - left) / CastleData.BLOCK_WIDTH)
	right = left + columns * CastleData.BLOCK_WIDTH

	# Which blocks of each course are new.
	var new_cells := []
	var first_row := -1
	for row in rows:
		var cells: Array[Rect2] = []
		for column in columns:
			var cell := Rect2(left + column * CastleData.BLOCK_WIDTH, -(row + 1) * course, CastleData.BLOCK_WIDTH, course)
			if _is_new(cell, solid, old_solid):
				cells.append(cell)
		new_cells.append(cells)
		if first_row < 0 and not cells.is_empty():
			first_row = row
	if first_row < 0 and fittings.is_empty():
		return

	# Builders start at the end where the ladder is and work back and forth.
	var cursor := _ladder_x(section, CastleData.hoist_x(GameState.job_part, section))
	if _plan_scaffolded:
		var start_y := -first_row * course if first_row >= 0 else top
		var lift := LIFT_ROWS * course
		var height := ceilf(-top / lift) * lift
		var bays := maxi(roundi((section[1] - section[0]) / BAY_WIDTH), 1)
		var bay_width: float = (section[1] - section[0]) / bays
		var forward := absf(cursor - section[0]) <= absf(cursor - section[1])
		for i in bays:
			var bay := i if forward else bays - 1 - i
			var rect := Rect2(section[0] + bay * bay_width, -height, bay_width, height)
			_plan.append({
				"kind": Kind.SCAFFOLD, "rect": rect, "color": SCAFFOLD_COLOR, "section": index,
				"stand": Vector2(clampf(rect.get_center().x, section[0] + 3.0, section[1] - 3.0), start_y),
				"line": start_y, "partial": Rect2(), "end": bay == bays - 1,
			})
		cursor = section[1] if forward else section[0]

	for row in rows:
		var row_top := -(row + 1) * course
		var cells: Array = new_cells[row]
		if not cells.is_empty():
			var forward := absf(cursor - left) <= absf(cursor - right)
			if not forward:
				cells.reverse()
			for cell: Rect2 in cells:
				var partial := Rect2(left, row_top, cell.position.x - left, course) if forward else Rect2(cell.end.x, row_top, right - cell.end.x, course)
				_plan.append({
					"kind": Kind.BLOCK, "rect": cell, "color": CastleData.STONE_LIGHT, "section": index,
					"stand": _stand(section, cell.get_center().x, -row * course),
					"line": -row * course, "partial": partial, "end": false,
				})
			cursor = right if forward else left
		# Fittings the stone has now risen past.
		while not fittings.is_empty() and fittings[0][0].position.y >= row_top - 0.01:
			_plan_fitting(index, fittings.pop_front(), maxf(row_top, top), row_top)
	# Whatever crowns the top goes on last.
	for shape: Array in fittings:
		_plan_fitting(index, shape, top, minf(-rows * course, top))


func _plan_fitting(index: int, shape: Array, stand_y: float, line: float) -> void:
	_plan.append({
		"kind": Kind.FITTING, "rect": shape[0], "color": shape[1], "section": index,
		"stand": _stand(_plan_sections[index], shape[0].get_center().x, stand_y),
		"line": line, "partial": Rect2(), "end": false,
	})


## Where a builder stands for a piece at x: on the stone laid so far, or on
## the ground for parts without a scaffold.
func _stand(section: Array, x: float, y: float) -> Vector2:
	return Vector2(clampf(x, section[0] + 3.0, section[1] - 3.0), y if _plan_scaffolded else 0.0)


## True if a block holds stonework of the new level that the old level lacks.
func _is_new(cell: Rect2, solid: Array, old_solid: Array[Rect2]) -> bool:
	for shape: Array in solid:
		var piece: Rect2 = shape[0].intersection(cell)
		if not piece.has_area():
			continue
		var had := false
		for old: Rect2 in old_solid:
			if old.encloses(piece):
				had = true
				break
		if not had:
			return true
	return false


func _nearest_section(x: float) -> int:
	var nearest := 0
	var best := INF
	for i in _plan_sections.size():
		var section: Array = _plan_sections[i]
		var off := absf(clampf(x, section[0], section[1]) - x)
		if off < best:
			best = off
			nearest = i
	return nearest


## The scaffold's ladder is at the end of the section nearest the hoist.
func _ladder_x(section: Array, hoist: float) -> float:
	var middle: float = (section[0] + section[1]) / 2.0
	return section[1] - 6.0 if hoist >= middle else section[0] + 6.0


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
	_draw_shapes(canvas, _plan_old)
	var done := _placed >= _plan.size()
	var piece := _next_piece()
	for i in _plan_sections.size():
		if done or i < piece.section:
			_draw_shapes(canvas, _plan_solid[i])
		elif i == piece.section:
			for shape: Array in _plan_solid[i]:
				_draw_clipped(canvas, shape, Rect2(-FAR, piece.line, FAR * 2.0, FAR))
				_draw_clipped(canvas, shape, piece.partial)
	_draw_shapes(canvas, _plan_same)
	for i in _plan_sections.size():
		if done or i < piece.section:
			_draw_shapes(canvas, _plan_fit[i])
	if not done:
		for i in range(_plan_first[piece.section], _placed):
			if _plan[i].kind == Kind.FITTING:
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
	var lift := LIFT_ROWS * CastleData.course(GameState.job_part)
	for i in range(_plan_first[piece.section], _placed):
		var bay: Dictionary = _plan[i]
		if bay.kind != Kind.SCAFFOLD:
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


## Materials that have been delivered but not lifted yet, stacked at the foot of the hoist.
func _draw_pile(canvas: CanvasItem) -> void:
	var waiting := float(GameState.job_waiting()) / GameState.job_units
	var x: float = hoist_x() + 8.0
	for i in clampi(ceili(waiting * MAX_PILE * 2.0), 0, MAX_PILE):
		canvas.draw_rect(Rect2(x + (i % 3) * 6 + (i / 3) * 3, -4 - (i / 3) * 4, 5, 4), CastleData.STONE_LIGHT)


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
