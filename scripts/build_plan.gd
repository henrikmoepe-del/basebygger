extends RefCounted
## Works out how a castle part is raised from one level to the next: the list
## of pieces the builders must fetch, shape, lift and put in place, in order.
##
## How a section is built:
##   1. The walls go up a course at a time. Builders work from the top of what
##      is laid so far (the section's "deck"). They get up there by the
##      building's own stairs: in at the door and out on top, or up the stair
##      ladder of the curtain wall. A section with neither gets one ladder,
##      which is taken away again at the end.
##   2. What crowns the top (battlements, roofs, flags) is set from the deck,
##      and what stands on the ground (doors, posts) from the ground.
##   3. Details on the face of the wall (windows, arrow slits) need
##      scaffolding: it is put up in front of the wall a lift at a time with
##      one ladder, the details are set from its platforms, and it is taken
##      down again from the top.
## Parts without sections (the palisade, the village) are low enough to build
## entirely from the ground.
##
## A plan is a Dictionary:
##   "pieces"      every piece, in the order it is placed (see below)
##   "fetch"       how many of them are fetched from the stockyard: all but
##                 the REMOVE pieces, which come last
##   "sections"    the stretches that are built one after another, [left, right]
##   "scaffolded"  true if builders climb to work (false: built from the ground)
##   "old"         what is drawn of the old level while the job lasts
##   "gone"        old fittings the new level doesn't have, each [rect, color,
##                 section]: they stay until new stone is laid over them
##   "same"        fittings of the new level that the old one already had
##   "solid"       per section: the new level's walls and roofs
##   "tops"        per section: the height of its deck when finished
##   "access"      per section: {"x", "hidden"}, the stair up to its deck
##   "platforms"   the scaffold platforms, each {"x0", "x1", "y", "ladder",
##                 "from", "until"}: it can be stood on while the number of
##                 pieces placed is from "from" to "until"
##
## Each piece is a Dictionary:
##   "kind"     Kind.BLOCK     one block of stone, plank, panel of daub, bundle of thatch...
##              Kind.FITTING   a window, door, battlement, post, flag
##              Kind.SCAFFOLD  one bay of one lift of scaffolding
##              Kind.LADDER    a ladder
##              Kind.REMOVE    taking a bay or ladder down again
##   "item"     what is carried for it: see FORMED and item_for()
##   "rect", "color"   what appears when it is placed
##   "section"  which section it belongs to
##   "stand"    where a builder stands to place it
##   "top"      true if it is placed from the section's deck (stand.y is then
##              the deck's height when this piece's turn comes)
##   "floor"    how high the section's deck is when this piece's turn comes
##   "form"     true if it must be shaped at the bench before it can go up
##   "lift"     true if it must be pulled up to the deck by the rope
##   "line", "partial"  how much of its section is laid just before it:
##              everything below line, and the partial stretch of its course
##   "end"      for scaffold bays: true for the last bay, which gets a pole
##              on its far side too
##   "removed_by"  for scaffolding and ladders: the REMOVE piece that takes
##              it down (-1 if it stays)
##   "target"   for REMOVE pieces: the piece that is taken down
##
## Later, an item can become something made at a workstation (a window from
## the glazier, say): have builders fetch it from there instead of from the
## stockyard.

enum Kind { BLOCK, FITTING, SCAFFOLD, LADDER, REMOVE }

const CastleData = preload("res://scripts/castle_data.gd")
## Items that are shaped at the bench before they go up: stone is dressed,
## planks are sawn, fittings are put together.
const FORMED := ["stone", "plank", "fitting"]
const SCAFFOLD_COLOR := Color(0.48, 0.32, 0.20)
## Scaffolding goes up in bays about this wide and lifts this high. A builder
## can reach this high from where they stand.
const BAY_WIDTH := 45.0
const LIFT_HEIGHT := 24.0
const FAR := 100000.0
## Marks scaffolding that has yet to be given the piece that removes it.
const TO_REMOVE := -2


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


## Which store of the stockyard an item is fetched from ("" = the shed).
static func store_for(item: String) -> String:
	match item:
		"stone":
			return "stone"
		"plank", "poles", "ladder":
			return "wood"
	return ""


## The plan for raising a part from level to level + 1.
static func make(part: String, level: int) -> Dictionary:
	var old := CastleData.shapes(part, level)
	var fresh := CastleData.shapes(part, level + 1)
	var plan := {"pieces": [], "gone": [], "same": [], "solid": [], "tops": [], "access": [], "platforms": []}
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
	plan["old"] = []
	for shape: Array in old:
		if not CastleData.is_fitting(shape[0]) or fresh_rects.has(shape[0]):
			plan.old.append(shape)
		else:
			plan.gone.append([shape[0], shape[1], _nearest_section(plan.sections, shape[0].get_center().x)])
	var bands := _bands(plan.sections)
	var fittings := []
	for i in plan.sections.size():
		plan.solid.append([])
		fittings.append([])
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
			fittings[_nearest_section(plan.sections, shape[0].get_center().x)].append(shape)

	var floors := CastleData.floors(part, level + 1)
	for i in plan.sections.size():
		_plan_section(plan, part, i, old_solid, fittings[i], floors)

	# Last of all, the scaffolding and the builders' ladders come down, from the top.
	plan["fetch"] = plan.pieces.size()
	for i in range(plan.fetch - 1, -1, -1):
		var piece: Dictionary = plan.pieces[i]
		if piece.removed_by == TO_REMOVE:
			piece.removed_by = plan.pieces.size()
			plan.pieces.append({
				"kind": Kind.REMOVE, "item": "poles", "rect": piece.rect, "color": SCAFFOLD_COLOR,
				"section": piece.section, "stand": piece.stand, "top": false, "floor": plan.tops[piece.section],
				"form": false, "lift": false, "line": -FAR, "partial": Rect2(), "end": false,
				"removed_by": -1, "target": i,
			})
	# A platform can be stood on from when its last bay is up until its first bay comes down.
	for platform: Dictionary in plan.platforms:
		var until: int = plan.pieces.size()
		for bay: int in platform.bays:
			until = mini(until, plan.pieces[bay].removed_by)
		platform["until"] = until
	return plan


## The end of a section nearest the hoist: where a ladder stands.
static func ladder_x(section: Array, hoist: float) -> float:
	var middle: float = (section[0] + section[1]) / 2.0
	return section[1] - 6.0 if hoist >= middle else section[0] + 6.0


## One section: see the top of this file.
static func _plan_section(plan: Dictionary, part: String, index: int, old_solid: Array[Rect2], fittings: Array, floors: Array) -> void:
	var course := CastleData.course(part)
	var block := CastleData.block_width(part)
	var section: Array = plan.sections[index]
	var solid: Array = plan.solid[index]
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

	# The deck is the floor the finished section has, if it has one (the wall
	# walk, a tower top): builders stand there to build anything higher.
	# The stair up to it is the building's own, or else a ladder.
	var deck := top if plan.scaffolded else 0.0
	var access := {"x": ladder_x(section, CastleData.hoist_x(part, section)), "hidden": false}
	var own_stair := false
	for flat: Dictionary in floors:
		if flat.x1 > section[0] and flat.x0 < section[1]:
			deck = flat.y
			for x: float in flat.stairs:
				if x >= section[0] and x <= section[1]:
					access = {"x": x, "hidden": flat.hidden}
					own_stair = true
	plan.tops.append(deck)
	plan.access.append(access)

	# Which blocks of each course are new, and what each is made of.
	var new_cells := []
	for row in rows:
		var cells := []
		for column in columns:
			var cell := Rect2(left + column * block, -(row + 1) * course, block, course)
			var made_of := _new_shape(cell, solid, old_solid)
			if made_of >= 0:
				cells.append([cell, solid[made_of][1]])
		new_cells.append(cells)

	# Fittings are set from the ground, from the deck, or from scaffolding.
	var low := []
	var crown := []
	var face := []
	for shape: Array in fittings:
		var area: Rect2 = shape[0]
		if not plan.scaffolded or area.end.y > -LIFT_HEIGHT:
			low.append(shape)
		elif area.end.y <= deck + 0.5:
			crown.append(shape)
		else:
			face.append(shape)
	var by_height := func(a: Array, b: Array) -> bool:
		return a[0].position.y > b[0].position.y or (a[0].position.y == b[0].position.y and a[0].position.x < b[0].position.x)
	low.sort_custom(by_height)
	crown.sort_custom(by_height)

	# state.floor is how high the deck is so far; state.ladder whether the
	# way up is there yet; state.line how far the walls have risen.
	var state := {"floor": 0.0, "ladder": own_stair and access.hidden, "line": 0.0, "permanent": own_stair}
	var cursor: float = access.x
	for row in rows:
		var row_top := -(row + 1) * course
		var cells: Array = new_cells[row]
		if not cells.is_empty():
			state.floor = maxf(-row * course, deck) if plan.scaffolded else 0.0
			_add_ladder(plan, index, state, deck)
			var forward := absf(cursor - left) <= absf(cursor - right)
			if not forward:
				cells.reverse()
			for cell: Array in cells:
				var area: Rect2 = cell[0]
				var partial := Rect2(left, row_top, area.position.x - left, course) if forward else Rect2(area.end.x, row_top, right - area.end.x, course)
				_add(plan, Kind.BLOCK, item_for(cell[1]), area, cell[1], index, Vector2(area.get_center().x, state.floor), plan.scaffolded, state, partial)
			cursor = right if forward else left
		state.line = row_top
		# Doors and posts the wall has now risen past.
		while not low.is_empty() and low[0][0].position.y >= row_top - 0.01:
			var shape: Array = low.pop_front()
			_add(plan, Kind.FITTING, "fitting", shape[0], shape[1], index, Vector2(shape[0].get_center().x, 0.0), false, state, Rect2())
	state.line = minf(state.line, top)
	for shape: Array in low:
		_add(plan, Kind.FITTING, "fitting", shape[0], shape[1], index, Vector2(shape[0].get_center().x, 0.0), false, state, Rect2())
	if not crown.is_empty():
		state.floor = deck
		_add_ladder(plan, index, state, deck)
		for shape: Array in crown:
			_add(plan, Kind.FITTING, "fitting", shape[0], shape[1], index, Vector2(shape[0].get_center().x, deck), true, state, Rect2())
	if own_stair and not access.hidden and not plan.scaffolded:
		# A part built from the ground that has a ladder of its own (the watchtower).
		state.floor = deck
		state.ladder = false
		_add_ladder(plan, index, state, deck)
		state.floor = 0.0
	if not face.is_empty():
		_plan_scaffold(plan, part, index, face, state)


## The way up to the deck, once the deck is off the ground: the stair ladder
## that stays, or a builders' ladder that is taken away at the end.
static func _add_ladder(plan: Dictionary, index: int, state: Dictionary, deck: float) -> void:
	if state.ladder or state.floor > -0.5:
		return
	state.ladder = true
	var x: float = plan.access[index].x
	var floor_now: float = state.floor
	# It is put up from the ground, before anyone is on the deck.
	state.floor = 0.0
	_add(plan, Kind.LADDER, "ladder", Rect2(x - 3.0, deck, 6.0, -deck), SCAFFOLD_COLOR, index, Vector2(x, 0.0), false, state, Rect2())
	if not state.permanent:
		plan.pieces[-1].removed_by = TO_REMOVE
	state.floor = floor_now


## Scaffolding in front of a section's face, for the details set into it. It
## goes up a lift at a time: the bays of a lift (set from the platform below),
## then the details that can be reached from the new platform.
static func _plan_scaffold(plan: Dictionary, part: String, index: int, face: Array, state: Dictionary) -> void:
	var section: Array = plan.sections[index]
	var x0 := INF
	var x1 := -INF
	var lifts := 0
	for shape: Array in face:
		x0 = minf(x0, shape[0].position.x - 6.0)
		x1 = maxf(x1, shape[0].end.x + 6.0)
		lifts = maxi(lifts, int(-shape[0].end.y / LIFT_HEIGHT))
	x0 = maxf(x0, section[0] - 4.0)
	x1 = minf(x1, section[1] + 4.0)
	var ladder := ladder_x([x0 + 2.0, x1 - 2.0], CastleData.hoist_x(part, section))
	var bays := maxi(roundi((x1 - x0) / BAY_WIDTH), 1)
	var bay_width: float = (x1 - x0) / bays
	for lift in range(1, lifts + 1):
		var platform_y := -lift * LIFT_HEIGHT
		var below := platform_y + LIFT_HEIGHT
		var placed := []
		for bay in bays:
			var rect := Rect2(x0 + bay * bay_width, platform_y, bay_width, LIFT_HEIGHT)
			_add(plan, Kind.SCAFFOLD, "poles", rect, SCAFFOLD_COLOR, index, Vector2(rect.get_center().x, below), false, state, Rect2())
			plan.pieces[-1].stand = Vector2(clampf(rect.get_center().x, x0 + 3.0, x1 - 3.0), below)
			plan.pieces[-1].end = bay == bays - 1
			plan.pieces[-1].removed_by = TO_REMOVE
			placed.append(plan.pieces.size() - 1)
		if lift == 1:
			# One ladder, as tall as the scaffolding will be, leant against the first lift.
			_add(plan, Kind.LADDER, "ladder", Rect2(ladder - 3.0, -lifts * LIFT_HEIGHT, 6.0, lifts * LIFT_HEIGHT), SCAFFOLD_COLOR, index, Vector2(ladder, 0.0), false, state, Rect2())
			plan.pieces[-1].stand = Vector2(ladder, 0.0)
			plan.pieces[-1].removed_by = TO_REMOVE
		plan.platforms.append({"x0": x0, "x1": x1, "y": platform_y, "ladder": ladder, "from": plan.pieces.size(), "bays": placed})
		for shape: Array in face:
			if int(-shape[0].end.y / LIFT_HEIGHT) == lift:
				_add(plan, Kind.FITTING, "fitting", shape[0], shape[1], index, Vector2(shape[0].get_center().x, platform_y), false, state, Rect2())
				plan.pieces[-1].stand = Vector2(clampf(shape[0].get_center().x, x0 + 3.0, x1 - 3.0), platform_y)


static func _add(plan: Dictionary, kind: Kind, item: String, rect: Rect2, color: Color, index: int, stand: Vector2, top: bool, state: Dictionary, partial: Rect2) -> void:
	var section: Array = plan.sections[index]
	var spot := Vector2(clampf(stand.x, section[0] + 3.0, section[1] - 3.0), stand.y)
	plan.pieces.append({
		"kind": kind, "item": item, "rect": rect, "color": color, "section": index,
		"stand": spot, "top": top, "floor": state.floor, "form": item in FORMED, "lift": top and spot.y < -0.5,
		"line": state.line, "partial": partial, "end": false, "removed_by": -1, "target": -1,
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
