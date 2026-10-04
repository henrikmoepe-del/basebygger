extends RefCounted
## Works out how a castle part is raised from one level to the next: the list
## of pieces the builders must fetch, shape, lift and put in place, in order.
##
## A plan is a Dictionary:
##   "pieces"      every piece, in the order it is placed (see below)
##   "sections"    the stretches that are built one after another, [left, right]
##   "scaffolded"  true if builders climb to work (false: built from the ground)
##   "old"         what is drawn of the old level while the job lasts
##   "same"        fittings of the new level that the old one already had
##   "solid"       per section: the new level's stonework
##   "fit"         per section: the new level's new fittings
##   "first"       per section: the index of its first piece
##
## Each piece is a Dictionary:
##   "kind"     Kind.SCAFFOLD (a bay of poles and planks), Kind.BLOCK (one
##              block of stone) or Kind.FITTING (a window, door, battlement...)
##   "item"     what is carried for it: see ITEMS
##   "rect", "color"   what appears when it is placed
##   "section"  which section it belongs to
##   "stand"    where a builder stands to place it
##   "form"     true if it must be shaped at the bench before it can go up
##   "lift"     true if it must be pulled up by the rope
##   "line", "partial"  how much stone of its section is laid just before it:
##              everything below line, and the partial stretch of its course
##   "end"      for scaffold bays: true for the last bay, which gets a pole
##              on its far side too
##
## Later, an item can become something made at a workstation (a window from
## the glazier, say): give it a recipe in ITEMS and have builders fetch it
## from there instead of from the stockhouse.

enum Kind { BLOCK, FITTING, SCAFFOLD }

const CastleData = preload("res://scripts/castle_data.gd")
## What a builder carries for each kind of piece, and whether it is shaped at
## the bench first (stone is dressed, fittings are put together).
const ITEMS := {
	Kind.BLOCK: {"item": "stone", "form": true, "color": Color(0.62, 0.62, 0.66)},
	Kind.FITTING: {"item": "fitting", "form": true, "color": Color(0.48, 0.32, 0.20)},
	Kind.SCAFFOLD: {"item": "poles", "form": false, "color": Color(0.48, 0.32, 0.20)},
}
const SCAFFOLD_COLOR := Color(0.48, 0.32, 0.20)
## Scaffolding goes up in bays about this wide, with planks this many courses apart.
const BAY_WIDTH := 60.0
const LIFT_ROWS := 2


## The plan for raising a part from level to level + 1.
static func make(part: String, level: int) -> Dictionary:
	var old := CastleData.shapes(part, level)
	var fresh := CastleData.shapes(part, level + 1)
	var plan := {"pieces": [], "same": [], "solid": [], "fit": [], "first": []}
	plan["sections"] = CastleData.sections(part, level + 1)
	plan["scaffolded"] = not plan.sections.is_empty()
	if not plan.scaffolded:
		# Built from the ground: one stretch as wide as the whole part.
		var box: Rect2 = fresh[0][0]
		for shape: Array in fresh:
			box = box.merge(shape[0])
		plan["sections"] = [[box.position.x, box.end.x]]

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
	plan["old"] = old.filter(func(shape: Array) -> bool: return not CastleData.is_fitting(shape[0]) or fresh_rects.has(shape[0]))
	for i in plan.sections.size():
		plan.solid.append([])
		plan.fit.append([])
	for shape: Array in fresh:
		var section := _nearest_section(plan.sections, shape[0].get_center().x)
		if not CastleData.is_fitting(shape[0]):
			plan.solid[section].append(shape)
		elif old_rects.has(shape[0]):
			plan.same.append(shape)
		else:
			plan.fit[section].append(shape)
	for i in plan.sections.size():
		plan.first.append(plan.pieces.size())
		_plan_section(plan, part, i, old_solid)
	return plan


## The scaffold's ladder is at the end of the section nearest the hoist.
static func ladder_x(section: Array, hoist: float) -> float:
	var middle: float = (section[0] + section[1]) / 2.0
	return section[1] - 6.0 if hoist >= middle else section[0] + 6.0


## One section: the scaffolding first, then the stonework a course at a time
## (only the blocks the old level doesn't have), with each fitting set in
## once the stone has risen past it, and whatever crowns the top last.
static func _plan_section(plan: Dictionary, part: String, index: int, old_solid: Array[Rect2]) -> void:
	var course := CastleData.course(part)
	var section: Array = plan.sections[index]
	var solid: Array = plan.solid[index]
	var fittings: Array = plan.fit[index].duplicate()
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
	var cursor := ladder_x(section, CastleData.hoist_x(part, section))
	if plan.scaffolded:
		var start_y := -first_row * course if first_row >= 0 else top
		var lift := LIFT_ROWS * course
		var height := ceilf(-top / lift) * lift
		var bays := maxi(roundi((section[1] - section[0]) / BAY_WIDTH), 1)
		var bay_width: float = (section[1] - section[0]) / bays
		var forward := absf(cursor - section[0]) <= absf(cursor - section[1])
		for i in bays:
			var bay := i if forward else bays - 1 - i
			var rect := Rect2(section[0] + bay * bay_width, -height, bay_width, height)
			_add(plan, Kind.SCAFFOLD, rect, SCAFFOLD_COLOR, index, Vector2(rect.get_center().x, start_y), start_y, Rect2(), bay == bays - 1)
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
				_add(plan, Kind.BLOCK, cell, CastleData.STONE_LIGHT, index, Vector2(cell.get_center().x, -row * course), -row * course, partial, false)
			cursor = right if forward else left
		# Fittings the stone has now risen past.
		while not fittings.is_empty() and fittings[0][0].position.y >= row_top - 0.01:
			var shape: Array = fittings.pop_front()
			_add(plan, Kind.FITTING, shape[0], shape[1], index, Vector2(shape[0].get_center().x, maxf(row_top, top)), row_top, Rect2(), false)
	# Whatever crowns the top goes on last.
	for shape: Array in fittings:
		_add(plan, Kind.FITTING, shape[0], shape[1], index, Vector2(shape[0].get_center().x, top), minf(-rows * course, top), Rect2(), false)


static func _add(plan: Dictionary, kind: Kind, rect: Rect2, color: Color, index: int, stand: Vector2, line: float, partial: Rect2, end: bool) -> void:
	var section: Array = plan.sections[index]
	# Builders stand on the stone laid so far, or on the ground for parts without a scaffold.
	var spot := Vector2(clampf(stand.x, section[0] + 3.0, section[1] - 3.0), stand.y if plan.scaffolded else 0.0)
	plan.pieces.append({
		"kind": kind, "item": ITEMS[kind].item, "rect": rect, "color": color, "section": index,
		"stand": spot, "form": ITEMS[kind].form, "lift": spot.y < -0.5,
		"line": line, "partial": partial, "end": end,
	})


## True if a block holds stonework of the new level that the old level lacks.
static func _is_new(cell: Rect2, solid: Array, old_solid: Array[Rect2]) -> bool:
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


static func _nearest_section(sections: Array, x: float) -> int:
	var nearest := 0
	var best := INF
	for i in sections.size():
		var section: Array = sections[i]
		var off := absf(clampf(x, section[0], section[1]) - x)
		if off < best:
			best = off
			nearest = i
	return nearest
