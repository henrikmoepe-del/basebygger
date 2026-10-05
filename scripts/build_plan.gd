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
##   4. What rises too high above the deck to reach from it (a turret's
##      battlements, the great tower, a pointed roof) is built from a "perch":
##      the top of what is laid of it so far. Builders climb to it by the
##      building's own stairs where they run up inside it, or else by a ladder
##      stood on the deck. The old level's great tower is knocked down the
##      same way, by builders standing in it.
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
##   "gone"        what must come off the old level before the new one can go
##                 up (battlements, turrets, roofs, flags), in chunks, each
##                 [rect, color, piece]: it stays until that piece is done
##   "same"        fittings of the new level that the old one already had
##   "solid"       per section: the new level's walls and roofs
##   "tops"        per section: the height of its deck when finished
##   "decks"       per section: [left, right], how wide its deck is
##   "access"      per section: {"x", "hidden"}, the stair up to its deck; and
##                 "ladder", the x of the ladder used instead while the walls
##                 are still lower than START_LADDER
##   "platforms"   the scaffold platforms and the perches, each {"x0", "x1",
##                 "y", "ladder", "from", "until"}: it can be stood on while the
##                 number of pieces placed is from "from" to "until". A perch
##                 also has "hidden" (true if its stair is inside the building)
##                 or "base" (the height of the deck its ladder stands on)
##
## Each piece is a Dictionary:
##   "kind"     Kind.BLOCK     one block of stone, plank, panel of daub, bundle of thatch...
##              Kind.FITTING   a window, door, battlement, post, flag
##              Kind.SCAFFOLD  one bay of one lift of scaffolding
##              Kind.LADDER    a ladder
##              Kind.BENCH     a bench in the yard, where pieces are shaped
##              Kind.HOIST     the beam and rope on the deck that lifts pieces up
##              Kind.REMOVE    taking a bay or ladder down again
##              Kind.DISMANTLE knocking a piece of the old level down
##   "item"     what is carried for it: see FORMED and item_for()
##   "rect", "color"   what appears when it is placed
##   "section"  which section it belongs to
##   "stand"    where a builder stands to place it
##   "top"      true if it is placed from the section's deck (stand.y is then
##              the deck's height when this piece's turn comes)
##   "floor"    how high the section's deck is when this piece's turn comes
##   "fetch"    true if it is carried from the stockyard (false for what is
##              taken down)
##   "form"     true if it must be shaped at the bench before it can go up
##   "lift"     true if it must be pulled up to the deck by the rope
##   "line", "partial"  how much of its section is laid just before it:
##              everything below line, and the partial stretch of its course
##   "end"      for scaffold bays: true for the last bay, which gets a pole
##              on its far side too
##   "removed_by"  for scaffolding, ladders, benches and the hoist: the REMOVE
##              piece that takes it away again (-1 if it stays)
##   "target"   for REMOVE pieces: the piece that is taken down
##   "via"      for pieces set from a perch with a ladder: that ladder's piece
##
## Later, an item can become something made at a workstation (a window from
## the glazier, say): have builders fetch it from there instead of from the
## stockyard.

enum Kind { BLOCK, FITTING, SCAFFOLD, LADDER, BENCH, HOIST, REMOVE, DISMANTLE }

const CastleData = preload("res://scripts/castle_data.gd")
## Items that are shaped at the bench before they go up: stone is dressed,
## planks are sawn, fittings are put together.
const FORMED := ["stone", "boulder", "plank", "fitting"]
## Items too long or heavy for one: two builders carry them from the stockyard.
const HEAVY := ["ladder", "hoist", "bench", "boulder"]
## Foundation stones are this many times as wide as an ordinary block.
const FOUNDATION_WIDTH := 1.5
const SCAFFOLD_COLOR := Color(0.48, 0.32, 0.20)
## Scaffolding goes up in bays about this wide and lifts this high. A builder
## can reach this high from where they stand.
const BAY_WIDTH := 45.0
const LIFT_HEIGHT := 24.0
## A perch is at least this far above the deck, so the two can't be mixed up.
const PERCH_MIN := 18.0
## A building with stairs inside is reached by a ladder until its walls are this high.
const START_LADDER := 40.0
const FAR := 100000.0
## The yard at the foot of a section, as distances east of the rope: the
## shaped pieces wait by the rope, then the benches, then the rough pile.
const READY_PILE := 8.0
const BENCH_AT := 30.0
const BENCH_GAP := 14.0
const BENCHES := 2
const ROUGH_PILE := 58.0
const BENCH_COLOR := Color(0.40, 0.27, 0.17)
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
		"stone", "boulder":
			return "stone"
		"plank", "poles", "ladder":
			return "wood"
	return ""


## The plan for raising a part from level to level + 1.
static func make(part: String, level: int) -> Dictionary:
	var old := CastleData.shapes(part, level)
	var fresh := CastleData.shapes(part, level + 1)
	var plan := {"pieces": [], "gone": [], "same": [], "solid": [], "tops": [], "decks": [], "access": [], "platforms": []}
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
		if not CastleData.is_fitting_shape(shape):
			old_solid.append(shape[0])
	for shape: Array in fresh:
		fresh_rects[shape[0]] = true
	# What the new level keeps of the old one is drawn all through the job.
	# The rest (battlements, flags, overhangs that will sit higher) stays
	# only until new stone is laid over it.
	plan["old"] = []
	var gone := []
	for i in plan.sections.size():
		gone.append([])
	for shape: Array in old:
		var kept: bool = fresh_rects.has(shape[0])
		if not kept and not CastleData.is_fitting_shape(shape):
			for other: Array in fresh:
				if not CastleData.is_fitting_shape(other) and other[0].encloses(shape[0]):
					kept = true
					break
		if kept:
			plan.old.append(shape)
		else:
			gone[_nearest_section(plan.sections, shape[0].get_center().x)].append(shape)
	var bands := _bands(plan.sections)
	var fittings := []
	for i in plan.sections.size():
		plan.solid.append([])
		fittings.append([])
	for shape: Array in fresh:
		if not CastleData.is_fitting_shape(shape):
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
		_plan_section(plan, part, i, old_solid, fittings[i], floors, gone[i])

	# Last of all, the scaffolding and the builders' ladders come down, from the top.
	plan["fetch"] = plan.pieces.size()
	for i in range(plan.fetch - 1, -1, -1):
		var piece: Dictionary = plan.pieces[i]
		if piece.removed_by == TO_REMOVE:
			piece.removed_by = plan.pieces.size()
			plan.pieces.append({
				"kind": Kind.REMOVE, "item": piece.item, "rect": piece.rect, "color": piece.color,
				"section": piece.section, "stand": piece.stand, "top": piece.top, "floor": plan.tops[piece.section],
				"fetch": false, "form": false, "lift": false, "line": -FAR, "partial": Rect2(), "end": false,
				"removed_by": -1, "target": i,
			})
	# A platform can be stood on from when its last bay is up until its first bay comes down.
	for platform: Dictionary in plan.platforms:
		var until: int = platform.get("until", plan.pieces.size())
		for bay: int in platform.bays:
			until = mini(until, plan.pieces[bay].removed_by)
		platform["until"] = until
	return plan


## The end of a section nearest the hoist: where a ladder stands.
static func ladder_x(section: Array, hoist: float) -> float:
	var middle: float = (section[0] + section[1]) / 2.0
	return section[1] - 6.0 if hoist >= middle else section[0] + 6.0


## One section: see the top of this file.
static func _plan_section(plan: Dictionary, part: String, index: int, old_solid: Array[Rect2], fittings: Array, floors: Array, gone: Array) -> void:
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
	var span := right - left
	# The far edge of the widest course (see the foundation stones below).
	right = left + maxf(ceilf(span / block) * block, ceilf(span / (block * FOUNDATION_WIDTH)) * block * FOUNDATION_WIDTH)

	# The courses, each [top, bottom], from the ground up. They are counted
	# from the top of what already stands here, so the first new course sits
	# exactly on the old wall.
	var old_body := Rect2()
	for old: Rect2 in old_solid:
		if old.end.x > section[0] and old.position.x < section[1] and old.get_area() > old_body.get_area():
			old_body = old
	var courses := []
	var y := 0.0
	var odd := fposmod(-old_body.position.y, course)
	if odd > 0.5:
		courses.append([-odd, 0.0])
		y = -odd
	while y > top + 0.01:
		courses.append([y - course, y])
		y -= course

	# The deck is the floor the finished section has, if it has one (the wall
	# walk, a tower top), or else the top of its main body: builders stand
	# there to build anything higher. The stair up to it is the building's
	# own, or else a ladder.
	var deck := 0.0
	var deck_x := [section[0], section[1]]
	var hoist := CastleData.hoist_x(part, section)
	var access := {"x": ladder_x(section, hoist), "hidden": false}
	var own_stair := false
	if plan.scaffolded:
		var body := Rect2()
		for shape: Array in solid:
			if shape[0].get_area() > body.get_area():
				body = shape[0]
		deck = body.position.y
		deck_x = [body.position.x, body.end.x]
		access.x = clampf(access.x, deck_x[0] + 4.0, deck_x[1] - 4.0)
	for flat: Dictionary in floors:
		# The rooms inside are floors too, but the deck is the roof.
		if flat.get("inside", false):
			continue
		if flat.x1 > section[0] and flat.x0 < section[1]:
			deck = flat.y
			deck_x = [maxf(flat.x0, section[0]), minf(flat.x1, section[1])]
			for x: float in flat.stairs:
				if x >= section[0] and x <= section[1]:
					access = {"x": x, "hidden": flat.hidden}
					own_stair = true
	if own_stair and access.hidden and old_body.position.y > -START_LADDER:
		# A building this low has no stairs inside yet: until its walls are
		# up a storey or so, builders use a ladder against it.
		access["ladder"] = clampf(ladder_x(section, hoist), deck_x[0] + 4.0, deck_x[1] - 4.0)
	plan.tops.append(deck)
	plan.decks.append(deck_x)
	plan.access.append(access)

	# Which blocks of each course are new, and what each is made of.
	var new_cells := []
	for band: Array in courses:
		var cells := []
		# The bottom course of a stone building is of big foundation stones.
		var foundation: bool = plan.scaffolded and part in CastleData.BLOCK_BUILT and band[1] > -0.5
		var width := block * FOUNDATION_WIDTH if foundation else block
		for column in ceili(span / width):
			var cell := Rect2(left + column * width, band[0], width, band[1] - band[0])
			var made_of := _new_shape(cell, solid, old_solid)
			if made_of >= 0:
				var item := item_for(solid[made_of][1])
				cells.append([cell, solid[made_of][1], "boulder" if foundation and item == "stone" else item, solid[made_of][0].intersection(cell)])
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

	# state.floor is how high the deck is so far; state.ladder and state.hoist
	# whether the way up and the rope are there yet; state.line how far the
	# walls have risen.
	var state := {
		"floor": 0.0, "ladder": own_stair and access.hidden and not access.has("ladder"), "hoist": false, "line": 0.0,
		"permanent": own_stair and not access.has("ladder"), "deck": deck_x, "ladders": {}, "perches": {},
	}
	var any_work := not fittings.is_empty() or not gone.is_empty()
	for cells: Array in new_cells:
		any_work = any_work or not cells.is_empty()
	if not any_work:
		return
	# First the benches are carried to the yard and set up.
	for bench in BENCHES:
		var at := hoist + BENCH_AT + bench * BENCH_GAP
		_add(plan, Kind.BENCH, "bench", Rect2(at - 6.0, -7.0, 12.0, 7.0), BENCH_COLOR, index, Vector2(at, 0.0), false, state, Rect2())
		plan.pieces[-1].stand = Vector2(at - 7.0, 0.0)
		plan.pieces[-1].removed_by = TO_REMOVE
	# Then whatever must come off the old level is knocked down, from the top,
	# by builders standing on the old wall.
	if not gone.is_empty():
		state.floor = old_body.position.y if plan.scaffolded else 0.0
		_rise(plan, part, index, state, deck)
		var first_perch: int = plan.platforms.size()
		var chunks := []
		for shape: Array in gone:
			var area: Rect2 = shape[0]
			if CastleData.is_fitting_shape(shape):
				chunks.append([area, shape[1]])
				continue
			# Walls and roofs come down a block at a time.
			var chunk_y := area.position.y
			while chunk_y < area.end.y - 0.01:
				var chunk_x := area.position.x
				while chunk_x < area.end.x - 0.01:
					chunks.append([Rect2(chunk_x, chunk_y, minf(block, area.end.x - chunk_x), minf(course, area.end.y - chunk_y)), shape[1]])
					chunk_x += block
				chunk_y += course
		chunks.sort_custom(func(a: Array, b: Array) -> bool:
			return a[0].position.y < b[0].position.y or (a[0].position.y == b[0].position.y and a[0].position.x < b[0].position.x))
		for chunk: Array in chunks:
			# A tall tower with stairs inside is knocked down by builders standing in it.
			var spot := _perch(plan, index, state, chunk[0], gone, state.floor, Rect2(), false) if plan.scaffolded else Vector2.INF
			_add(plan, Kind.DISMANTLE, "rubble", chunk[0], chunk[1], index, Vector2(chunk[0].get_center().x, state.floor), plan.scaffolded and spot == Vector2.INF, state, Rect2())
			if spot != Vector2.INF:
				plan.pieces[-1].stand = spot
			plan.pieces[-1].fetch = false
			plan.pieces[-1].lift = false
			plan.gone.append([chunk[0], chunk[1], plan.pieces.size() - 1])
		# The perches in the old tower are gone with it.
		for perch in range(first_perch, plan.platforms.size()):
			plan.platforms[perch]["until"] = plan.pieces.size() - 1
		state.perches.clear()
	var cursor: float = access.x
	for row in courses.size():
		var row_top: float = courses[row][0]
		var row_bottom: float = courses[row][1]
		var cells: Array = new_cells[row]
		if not cells.is_empty():
			# The deck only ever rises: builders who are up on the old wall
			# stay there, even to patch something lower down.
			state.floor = minf(state.floor, maxf(row_bottom, deck)) if plan.scaffolded else 0.0
			_rise(plan, part, index, state, deck)
			var forward := absf(cursor - left) <= absf(cursor - right)
			if not forward:
				cells.reverse()
			# The first block of a course is laid from the course below; each
			# one after it from on top of the block just laid.
			var stand_x: float = cells[0][0].get_center().x
			for cell: Array in cells:
				var area: Rect2 = cell[0]
				var partial := Rect2(left, row_top, area.position.x - left, row_bottom - row_top) if forward else Rect2(area.end.x, row_top, right - area.end.x, row_bottom - row_top)
				# What is too high to reach from the finished deck is laid from a perch.
				var spot := _perch(plan, index, state, cell[3], solid, deck, partial, true) if plan.scaffolded and row_bottom < deck - 0.5 else Vector2.INF
				_add(plan, Kind.BLOCK, cell[2], area, cell[1], index, Vector2(stand_x, state.floor), plan.scaffolded and spot == Vector2.INF, state, partial)
				if spot != Vector2.INF:
					_from_perch(plan, state, spot)
				stand_x = area.get_center().x
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
		_rise(plan, part, index, state, deck)
		for shape: Array in crown:
			var spot := _perch(plan, index, state, shape[0], solid, deck, Rect2(), true)
			_add(plan, Kind.FITTING, "fitting", shape[0], shape[1], index, Vector2(shape[0].get_center().x, deck), spot == Vector2.INF, state, Rect2())
			if spot != Vector2.INF:
				_from_perch(plan, state, spot)
	if own_stair and not access.hidden and not plan.scaffolded:
		# A part built from the ground that has a ladder of its own (the watchtower).
		state.floor = deck
		state.ladder = false
		state.hoist = true
		_rise(plan, part, index, state, deck)
		state.floor = 0.0
	if not face.is_empty():
		_plan_scaffold(plan, part, index, face, state)


## Once the deck is off the ground, builders need the way up to it (the
## stair ladder that stays, or a builders' ladder that is taken away at the
## end) and the hoist on it to pull pieces up.
static func _rise(plan: Dictionary, part: String, index: int, state: Dictionary, deck: float) -> void:
	if state.floor > -0.5:
		return
	var floor_now: float = state.floor
	if not state.ladder:
		state.ladder = true
		var way: Dictionary = plan.access[index]
		var x: float = way.get("ladder", way.x)
		# A ladder that is only for the start of the work is a short one.
		var top := maxf(deck, -START_LADDER - 8.0) if way.has("ladder") else deck
		# It is put up from the ground, before anyone is on the deck.
		state.floor = 0.0
		_add(plan, Kind.LADDER, "ladder", Rect2(x - 3.0, top, 6.0, -top), SCAFFOLD_COLOR, index, Vector2(x, 0.0), false, state, Rect2())
		if not state.permanent:
			plan.pieces[-1].removed_by = TO_REMOVE
		state.floor = floor_now
	if not state.hoist:
		state.hoist = true
		# Carried up by hand and set at the edge of the deck.
		var x := clampf(CastleData.hoist_x(part, plan.sections[index]), state.deck[0] + 4.0, state.deck[1] - 4.0)
		_add(plan, Kind.HOIST, "hoist", Rect2(x - 4.0, floor_now - 20.0, 16.0, 20.0), SCAFFOLD_COLOR, index, Vector2(x, floor_now), true, state, Rect2())
		plan.pieces[-1].lift = false
		plan.pieces[-1].removed_by = TO_REMOVE


## Where a builder stands to set (or knock down) something that is too high
## to reach from the deck: on a perch, the top of what stands under it. The
## perch is added to the plan's platforms, with the way up to it: the stairs
## inside the building if they come up there, else a ladder stood on the deck
## (only if ladders is true). shapes are the walls and roofs to stand on.
## Returns Vector2.INF if it is set from the deck after all.
static func _perch(plan: Dictionary, index: int, state: Dictionary, area: Rect2, shapes: Array, deck: float, partial: Rect2, ladders: bool) -> Vector2:
	if area.end.y >= deck - LIFT_HEIGHT - 0.01:
		return Vector2.INF
	var x := area.get_center().x
	# What it sits on or is set into, or else the highest thing below it.
	var host := Rect2()
	var y := deck
	for shape: Array in shapes:
		var body: Rect2 = shape[0]
		if CastleData.is_fitting_shape(shape) or body.size.y < 1.5 or body.position.y > deck - 0.5:
			continue
		if body.position.x > x or body.end.x < x:
			continue
		if body.position.y <= area.end.y + 1.0 and body.end.y >= area.end.y + 1.0:
			host = body
			y = area.end.y
			break
		if body.position.y >= area.end.y - 0.01 and body.position.y < y:
			host = body
			y = body.position.y
	# A perch barely above the deck is no use: it is set from the deck.
	if not host.has_area() or y >= deck - PERCH_MIN:
		return Vector2.INF
	var x0 := host.position.x + 1.0
	var x1 := host.end.x - 1.0
	var way: Dictionary = plan.access[index]
	var perch := {"x0": x0, "x1": x1, "y": y, "bays": []}
	var ladder := -1
	if way.hidden and way.x >= x0 and way.x <= x1:
		# The stairs inside come up here.
		perch["ladder"] = way.x
		perch["hidden"] = true
	elif not ladders:
		return Vector2.INF
	else:
		var at := clampf(host.get_center().x, state.deck[0] + 2.0, state.deck[1] - 2.0)
		var key := roundi(at)
		if not state.ladders.has(key):
			_add(plan, Kind.LADDER, "ladder", Rect2(at - 3.0, y, 6.0, deck - y), SCAFFOLD_COLOR, index, Vector2(at, deck), true, state, partial)
			plan.pieces[-1].lift = false
			plan.pieces[-1].removed_by = TO_REMOVE
			state.ladders[key] = plan.pieces.size() - 1
		ladder = state.ladders[key]
		# One ladder per turret, as tall as the highest perch on it.
		var rect: Rect2 = plan.pieces[ladder].rect
		var top := minf(rect.position.y, y)
		plan.pieces[ladder].rect = Rect2(rect.position.x, top, rect.size.x, deck - top)
		perch["ladder"] = at
		perch["base"] = deck
		perch["bays"] = [ladder]
		perch.x0 = minf(x0, at)
		perch.x1 = maxf(x1, at)
	var name := "%s:%s:%s" % [perch.x0, perch.x1, y]
	if not state.perches.has(name):
		state.perches[name] = true
		perch["from"] = plan.pieces.size()
		plan.platforms.append(perch)
	state["via"] = ladder
	return Vector2(clampf(x, minf(x0 + 2.0, host.get_center().x), maxf(x1 - 2.0, host.get_center().x)), y)


## Makes the piece just added one that is set from a perch: pulled up to the
## deck by the rope, then carried up to where the builder stands.
static func _from_perch(plan: Dictionary, state: Dictionary, spot: Vector2) -> void:
	var piece: Dictionary = plan.pieces[-1]
	piece.stand = spot
	piece.lift = true
	piece["via"] = state.via


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
	# Builders on the deck keep to the deck; others keep to the section.
	var within: Array = state.deck if top else plan.sections[index]
	var spot := Vector2(clampf(stand.x, within[0] + 3.0, within[1] - 3.0), stand.y)
	plan.pieces.append({
		"kind": kind, "item": item, "rect": rect, "color": color, "section": index,
		"stand": spot, "top": top, "floor": state.floor, "fetch": true, "form": item in FORMED, "lift": top and spot.y < -0.5,
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
