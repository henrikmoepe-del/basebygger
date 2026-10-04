extends RefCounted
## Works out how a castle part is raised from one level to the next: the list
## of pieces the builders must fetch, shape, lift and put in place, in order.
##
## A plan is a Dictionary:
##   "pieces"      every piece, in the order it is placed (see below)
##   "fetch"       how many of them are fetched from the stockhouse: all but
##                 the REMOVE pieces, which come last
##   "sections"    the stretches that are built one after another, [left, right]
##   "scaffolded"  true if builders climb to work (false: built from the ground)
##   "old"         what is drawn of the old level while the job lasts
##   "same"        fittings of the new level that the old one already had
##   "solid"       per section: the new level's walls and roofs
##   "fit"         per section: the new level's new fittings
##   "first"       per section: the index of its first piece
##
## Each piece is a Dictionary:
##   "kind"     Kind.BLOCK     one block of stone, plank, panel of daub, bundle of thatch...
##              Kind.FITTING   a window, door, battlement, post, flag
##              Kind.SCAFFOLD  one bay of one lift of scaffolding
##              Kind.LADDER    one length of ladder
##              Kind.REMOVE    taking a bay or ladder of the scaffolding down again
##   "item"     what is carried for it: see FORMED and item_for()
##   "rect", "color"   what appears when it is placed
##   "section"  which section it belongs to
##   "stand"    where a builder stands to place it
##   "form"     true if it must be shaped at the bench before it can go up
##   "lift"     true if it must be pulled up by the rope
##   "line", "partial"  how much of its section is laid just before it:
##              everything below line, and the partial stretch of its course
##   "end"      for scaffold bays: true for the last bay, which gets a pole
##              on its far side too
##   "removed_by"  for scaffolding: the REMOVE piece that takes it down (-1 if it stays)
##   "target"   for REMOVE pieces: the piece that is taken down
##
## A scaffolded section is built a lift at a time: a length of ladder, the
## bays of scaffolding for that lift, then the courses the lift reaches, with
## each fitting set in once the wall has risen past it. When everything
## stands, the scaffolding is taken down from the top.
##
## Later, an item can become something made at a workstation (a window from
## the glazier, say): have builders fetch it from there instead of from the
## stockhouse.

enum Kind { BLOCK, FITTING, SCAFFOLD, LADDER, REMOVE }

const CastleData = preload("res://scripts/castle_data.gd")
## Items that are shaped at the bench before they go up: stone is dressed,
## planks are sawn, fittings are put together.
const FORMED := ["stone", "plank", "fitting"]
const SCAFFOLD_COLOR := Color(0.48, 0.32, 0.20)
## Scaffolding goes up in bays about this wide, with planks this many courses apart.
const BAY_WIDTH := 60.0
const LIFT_ROWS := 2
const FAR := 100000.0


## What a wall or roof of this colour is built from.
static func item_for(color: Color) -> String:
	if color == CastleData.WOOD or color == CastleData.WOOD_DARK:
		return "plank"
	if color == CastleData.PLASTER:
		return "daub"
	if color == CastleData.THATCH:
		return "thatch"
	if color == CastleData.ROOF_RED or color == CastleData.ROOF_BLUE:
		return "tile"
	return "stone"


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
	var bands := _bands(plan.sections)
	for i in plan.sections.size():
		plan.solid.append([])
		plan.fit.append([])
	for shape: Array in fresh:
		if not CastleData.is_fitting(shape[0]):
			# A wall that runs through several sections is built a section at a time.
			for i in plan.sections.size():
				var within: Rect2 = shape[0].intersection(Rect2(bands[i][0], -FAR, bands[i][1] - bands[i][0], FAR * 2.0))
				if within.has_area():
					plan.solid[i].append([within, shape[1]])
		elif old_rects.has(shape[0]):
			plan.same.append(shape)
		else:
			plan.fit[_nearest_section(plan.sections, shape[0].get_center().x)].append(shape)

	# The stairs that stay (up to the wall walk, the watchtower's ladder) are
	# put up last, as far as the old ones didn't reach.
	var stairs := []
	var old_floors := CastleData.floors(part, level)
	for flat: Dictionary in CastleData.floors(part, level + 1):
		if flat.hidden:
			continue
		for x: float in flat.stairs:
			var from := 0.0
			for old_flat: Dictionary in old_floors:
				if old_flat.stairs.has(x):
					from = minf(from, old_flat.y)
			if flat.y < from:
				stairs.append(Rect2(x - 3.0, flat.y, 6.0, from - flat.y))

	for i in plan.sections.size():
		plan.first.append(plan.pieces.size())
		var mine := stairs.filter(func(stair: Rect2) -> bool: return _nearest_section(plan.sections, stair.get_center().x) == i)
		_plan_section(plan, part, i, old_solid, mine)

	# Last of all the scaffolding comes down, from the top.
	plan["fetch"] = plan.pieces.size()
	for i in range(plan.fetch - 1, -1, -1):
		var piece: Dictionary = plan.pieces[i]
		if piece.removed_by == -2:
			piece.removed_by = plan.pieces.size()
			plan.pieces.append({
				"kind": Kind.REMOVE, "item": "poles", "rect": piece.rect, "color": SCAFFOLD_COLOR,
				"section": piece.section, "stand": piece.stand, "form": false, "lift": false,
				"line": -FAR, "partial": Rect2(), "end": false, "removed_by": -1, "target": i,
			})
	return plan


## The scaffold's ladder is at the end of the section nearest the hoist.
static func ladder_x(section: Array, hoist: float) -> float:
	var middle: float = (section[0] + section[1]) / 2.0
	return section[1] - 6.0 if hoist >= middle else section[0] + 6.0


## One section, a lift at a time: see the top of this file.
static func _plan_section(plan: Dictionary, part: String, index: int, old_solid: Array[Rect2], stairs: Array) -> void:
	var course := CastleData.course(part)
	var block := CastleData.block_width(part)
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
	var columns := ceili((right - left) / block)
	right = left + columns * block

	# Which blocks of each course are new, and what each is made of.
	var new_cells := []
	var any_new := false
	for row in rows:
		var cells := []
		for column in columns:
			var cell := Rect2(left + column * block, -(row + 1) * course, block, course)
			var made_of := _new_shape(cell, solid, old_solid)
			if made_of >= 0:
				cells.append([cell, solid[made_of][1]])
				any_new = true
		new_cells.append(cells)
	if not any_new and fittings.is_empty() and stairs.is_empty():
		return

	# Builders start at the end where the ladder is and work back and forth.
	var ladder := ladder_x(section, CastleData.hoist_x(part, section))
	var cursor := ladder
	var lift_height := LIFT_ROWS * course
	var bays := maxi(roundi((section[1] - section[0]) / BAY_WIDTH), 1)
	var bay_width: float = (section[1] - section[0]) / bays
	var line := 0.0
	for lift in ceili(float(rows) / LIFT_ROWS) if rows > 0 else 0:
		var floor_y := -lift * lift_height
		if plan.scaffolded:
			_add(plan, Kind.LADDER, "ladder", Rect2(ladder - 3.0, floor_y - lift_height, 6.0, lift_height), SCAFFOLD_COLOR, index, Vector2(ladder, floor_y), line, Rect2())
			plan.pieces[-1].removed_by = -2
			var forward := absf(cursor - section[0]) <= absf(cursor - section[1])
			for i in bays:
				var bay := i if forward else bays - 1 - i
				var rect := Rect2(section[0] + bay * bay_width, floor_y - lift_height, bay_width, lift_height)
				_add(plan, Kind.SCAFFOLD, "poles", rect, SCAFFOLD_COLOR, index, Vector2(rect.get_center().x, floor_y), line, Rect2())
				plan.pieces[-1].end = bay == bays - 1
				plan.pieces[-1].removed_by = -2
			cursor = section[1] if forward else section[0]
		for row in range(lift * LIFT_ROWS, mini((lift + 1) * LIFT_ROWS, rows)):
			var row_top := -(row + 1) * course
			var cells: Array = new_cells[row]
			if not cells.is_empty():
				var forward := absf(cursor - left) <= absf(cursor - right)
				if not forward:
					cells.reverse()
				for cell: Array in cells:
					var area: Rect2 = cell[0]
					var partial := Rect2(left, row_top, area.position.x - left, course) if forward else Rect2(area.end.x, row_top, right - area.end.x, course)
					_add(plan, Kind.BLOCK, item_for(cell[1]), area, cell[1], index, Vector2(area.get_center().x, -row * course), line, partial)
				cursor = right if forward else left
			line = row_top
			# Fittings the wall has now risen past.
			while not fittings.is_empty() and fittings[0][0].position.y >= row_top - 0.01:
				var shape: Array = fittings.pop_front()
				_add(plan, Kind.FITTING, "fitting", shape[0], shape[1], index, Vector2(shape[0].get_center().x, maxf(row_top, top)), line, Rect2())
	# Whatever crowns the top goes on last, then the stairs that stay.
	line = minf(line, top)
	for shape: Array in fittings:
		_add(plan, Kind.FITTING, "fitting", shape[0], shape[1], index, Vector2(shape[0].get_center().x, top), line, Rect2())
	for stair: Rect2 in stairs:
		_add(plan, Kind.LADDER, "ladder", stair, SCAFFOLD_COLOR, index, Vector2(stair.get_center().x, top), line, Rect2())


static func _add(plan: Dictionary, kind: Kind, item: String, rect: Rect2, color: Color, index: int, stand: Vector2, line: float, partial: Rect2) -> void:
	var section: Array = plan.sections[index]
	# Builders stand on what is built so far, or on the ground for parts without a scaffold.
	var spot := Vector2(clampf(stand.x, section[0] + 3.0, section[1] - 3.0), stand.y if plan.scaffolded else 0.0)
	plan.pieces.append({
		"kind": kind, "item": item, "rect": rect, "color": color, "section": index,
		"stand": spot, "form": item in FORMED, "lift": spot.y < -0.5,
		"line": line, "partial": partial, "end": false, "removed_by": -1, "target": -1,
	})


## Which of the new level's shapes a block holds that the old level lacks
## (its place in solid), or -1 if the block is nothing new.
static func _new_shape(cell: Rect2, solid: Array, old_solid: Array[Rect2]) -> int:
	for i in solid.size():
		var piece: Rect2 = solid[i][0].intersection(cell)
		if not piece.has_area():
			continue
		var had := false
		for old: Rect2 in old_solid:
			if old.encloses(piece):
				had = true
				break
		if not had:
			return i
	return -1


## The stretch of ground each section answers for: up to half way to its neighbours.
static func _bands(sections: Array) -> Array:
	var order := range(sections.size())
	order.sort_custom(func(a: int, b: int) -> bool: return sections[a][0] < sections[b][0])
	var bands := []
	bands.resize(sections.size())
	for k in order.size():
		var low: float = -FAR if k == 0 else (sections[order[k - 1]][1] + sections[order[k]][0]) / 2.0
		var high: float = FAR if k == order.size() - 1 else (sections[order[k]][1] + sections[order[k + 1]][0]) / 2.0
		bands[order[k]] = [low, high]
	return bands


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
