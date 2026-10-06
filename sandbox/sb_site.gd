extends "res://sandbox/sb_thing.gd"
## A building site: a planned building drawn as a faint outline (like a
## blueprint), filled in block by block as builders bring material from the
## stockyard. Blocks are laid a course at a time from the bottom.

const BW := 10.0
const BH := 6.0

var title := "Hut"
## "thatch" (a hut), "battlements" (a wall), "spire" (a tower).
var style := "thatch"
var cols := 5
## One material per block, bottom course first, left to right.
var mats: Array = []
var placed := 0
## Material brought here by haulers, waiting to be laid, and what is on
## its way (so two haulers do not bring the same block).
var stock := {"wood": 0, "stone": 0, "planks": 0}
var incoming := {"wood": 0, "stone": 0, "planks": 0}
## For a workshop: its kind (a key of SbData.WORKSHOPS) and its bill.
var workshop := ""
var keep := 0
## Builders choosing for themselves prefer a site marked urgent.
var urgent := false
## The hurt lying in this building's beds (a finished Hut).
var sleepers: Array = []
var _window_light: PointLight2D
var selected := false
## The material actually laid in each place so far (a builder may bring the
## material of the course below when two arrive at once).
var laid: Array = []
var _flash := 0.0


func setup(title_: String, style_: String, cols_: int, courses: Array) -> void:
	kind = "site"
	title = title_
	style = style_
	cols = cols_
	mats.clear()
	for course in courses:
		for i in cols:
			mats.append(course)


func is_open() -> bool:
	return not done() or is_workshop()


## A finished workshop (something to craft at).
func is_workshop() -> bool:
	return workshop != "" and done()


## The workshop's recipe, or {}.
func recipe() -> Dictionary:
	return SbData.WORKSHOPS.get(workshop, {})


func done() -> bool:
	return placed >= mats.size()


## The material the next block needs, or "" when finished.
func next_material() -> String:
	return "" if done() else mats[placed]


## How many more of this material the site still needs brought, past what
## lies here or is on its way. At most a few at a time are wanted.
func wanted(res: String) -> int:
	var left := 0
	for i in range(placed, mats.size()):
		if mats[i] == res:
			left += 1
	return mini(left, 6) - stock[res] - incoming[res]


## Where delivered material lies: a pile at the front left of the site.
func has_beds() -> bool:
	return done() and title == "Hut"


func bed_spot(i: int) -> Vector2:
	return position + Vector2(-8.0 + 14.0 * float(i), 3.0)


func pile_spot() -> Vector2:
	return position + Vector2(-width() / 2.0 - 8.0, 8.0)


func add_block(material: String) -> void:
	if done():
		return
	laid.append(material)
	placed += 1
	world.sound("place", position)
	if done():
		_flash = 1.0
		world.sound("built", position)
		_light_window()
		world.announce("The %s is finished." % title)
	queue_redraw()


## Finished at once, without a word (for buildings standing when the map starts).
func finish_now() -> void:
	while placed < mats.size():
		laid.append(mats[placed])
		placed += 1
	_light_window()
	queue_redraw()


## A finished Hut has a lit window at night (and a workshop a lamp).
func _light_window() -> void:
	if _window_light == null and (title == "Hut" or workshop != ""):
		_window_light = preload("res://sandbox/sb_light.gd").add(self, Vector2(0, -height() * 0.6), 50.0, 0.7)


## Fire knocks blocks off the top.
func lose_block() -> void:
	if placed > 0:
		placed -= 1
		laid.pop_back()
	if _window_light != null:
		_window_light.queue_free()
		_window_light = null
	queue_redraw()


func burn() -> void:
	lose_block()


## A fire here needs something to burn: what has been laid so far.
func has_fuel() -> bool:
	return placed > 0


func rows() -> int:
	return mats.size() / cols


func width() -> float:
	return cols * BW


func height() -> float:
	return rows() * BH


## Where the next block goes, relative to the site, for the builder to face.
func next_slot() -> Vector2:
	var i := mini(placed, mats.size() - 1)
	return Vector2(-width() / 2.0 + (i % cols + 0.5) * BW, -(i / cols + 0.5) * BH)


func hit(p: Vector2) -> bool:
	var top := height() + 18.0
	return Rect2(position + Vector2(-width() / 2.0 - 2.0, -top), Vector2(width() + 4.0, top + 6.0)).has_point(p)


func work_spot(peasant: Node2D) -> Vector2:
	var i := workers.find(peasant)
	if i < 0:
		i = workers.size()
	# Builders line up along the front of the site, a step apart in depth.
	var along := -width() / 2.0 + 4.0 + fmod(float(i) * 9.0, width() - 6.0)
	return position + Vector2(along, 6.0 + 4.0 * float(i % 3))


func label() -> String:
	return "the " + title


func work_spot_craft(peasant: Node2D) -> Vector2:
	return position + Vector2(-6.0 + float(workers.find(peasant)) * 10.0, 5.0)


func progress_text() -> String:
	if is_workshop():
		var r := recipe()
		return "%s: %s, keep %d in stock (now %d)" % [title, r.bill, keep, world.stockyard.stock.get(r.output, 0)]
	if done():
		return "%s: finished" % title
	return "%s: %d / %d blocks, next: %s, %d working" % [title, placed, mats.size(), next_material(), workers.size()]


func _process(delta: float) -> void:
	if (is_workshop() and not workers.is_empty()) or (done() and title == "Hut"):
		queue_redraw()
	if _window_light != null:
		_window_light.visible = world.darkness() > 0.05
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var w := width()
	var left := -w / 2.0
	# The site's footing: trodden earth.
	draw_rect(Rect2(left - 4.0, -1.0, w + 8.0, 4.0), SbData.DIRT.darkened(0.15))
	# Blueprint: every block still to come as a faint outline.
	var faint := Color(SbData.WHITE, 0.28)
	for i in range(placed, mats.size()):
		var r := Rect2(left + (i % cols) * BW, -(i / cols + 1) * BH, BW, BH)
		draw_rect(r, faint, false, 1.0)
	# The blocks laid so far.
	for i in placed:
		var course := i / cols
		var r := Rect2(left + (i % cols) * BW, -(course + 1) * BH, BW, BH)
		var shade := (i + course) % 2 == 0
		if laid[i] == "stone":
			draw_rect(r, SbData.STONE3 if shade else SbData.STONE2)
			draw_rect(Rect2(r.position, Vector2(BW, 1)), SbData.STONE4)
			draw_rect(Rect2(r.position + Vector2(BW - 1, 0), Vector2(1, BH)), SbData.STONE1)
		elif laid[i] == "planks":
			draw_rect(r, SbData.PLANK if shade else SbData.WOOD3)
			draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(BW, 1)), SbData.WOOD2)
			draw_rect(Rect2(r.position + Vector2(BW - 1, 0), Vector2(1, BH)), SbData.WOOD1)
		else:
			draw_rect(r, SbData.WOOD2 if shade else SbData.WOOD1)
			draw_rect(Rect2(r.position, Vector2(BW, 1)), SbData.WOOD3)
			draw_rect(Rect2(r.position + Vector2(BW - 1, 0), Vector2(1, BH)), SbData.WOOD0)
	if done():
		_draw_finish(left, w)
	if _flash > 0.0:
		draw_rect(Rect2(left, -height(), w, height()), Color(SbData.LIGHT, _flash * 0.6))
	# The pile of delivered material, beside the name board.
	var pile := pile_spot() - position
	var n := 0
	for res in ["stone", "wood", "planks"]:
		for i in mini(stock[res], 6):
			var c: Color = (SbData.STONE3 if i % 2 == 0 else SbData.STONE2) if res == "stone" else ((SbData.WOOD2 if i % 2 == 0 else SbData.WOOD3) if res == "wood" else SbData.PLANK)
			draw_rect(Rect2(pile.x - 6.0 + (n % 3) * 4.0, pile.y - 3.0 - (n / 3) * 3.0, 4, 3), c)
			n += 1
	if selected:
		draw_rect(Rect2(left - 3.0, -height() - 3.0, w + 6.0, height() + 6.0), SbData.GOLD, false, 1.0)
	if urgent and not done():
		# A red pennant on the name board: build this first.
		draw_rect(Rect2(left - 3.0, -16.0, 1, 12), SbData.WOOD0)
		draw_colored_polygon(PackedVector2Array([Vector2(left - 2.0, -16.0), Vector2(left + 5.0, -14.0), Vector2(left - 2.0, -12.0)]), SbData.RED1)
	# Name board while it is still a site.
	if not done():
		draw_rect(Rect2(left - 3.0, -4.0, 1, 4), SbData.WOOD1)
		draw_rect(Rect2(left - 6.0, -8.0, 7, 4), SbData.WOOD3)


func _draw_finish(left: float, w: float) -> void:
	var top := -height()
	match style:
		"flowers":
			# Little flowers along the low stone edging.
			for i in 7:
				var fx := left + 2.0 + float(i) * (w - 4.0) / 6.0
				draw_rect(Rect2(fx, top - 3.0, 1, 3), SbData.GRASS2)
				var col: Color = [SbData.RED1, SbData.GOLD, SbData.WHITE, Color("#6a3a6a")][i % 4]
				draw_rect(Rect2(fx - 1.0, top - 5.0, 3, 2), col)
		"watch":
			# A wooden lookout on long legs, with a roof.
			draw_rect(Rect2(left - 3.0, top - 10.0, w + 6.0, 2), SbData.WOOD2)
			draw_rect(Rect2(left - 3.0, top - 10.0, 1, 10), SbData.WOOD1)
			draw_rect(Rect2(left + w + 2.0, top - 10.0, 1, 10), SbData.WOOD1)
			draw_colored_polygon(PackedVector2Array([Vector2(left - 5, top - 10), Vector2(left + w / 2.0, top - 18), Vector2(left + w + 5, top - 10)]), SbData.THATCH)
			if world.watchman() != null:
				# The guard on watch, a small figure up top.
				draw_rect(Rect2(left + w / 2.0 - 2.0, top - 8.0, 4, 6), SbData.JOBS.guard.tunic)
				draw_rect(Rect2(left + w / 2.0 - 1.0, top - 11.0, 3, 3), SbData.SKIN1)
		"workshop":
			# An open timber shed: posts, a plank roof, the saw bench inside.
			draw_rect(Rect2(left, top - 14, 2, 14), SbData.WOOD1)
			draw_rect(Rect2(left + w - 2, top - 14, 2, 14), SbData.WOOD1)
			draw_colored_polygon(PackedVector2Array([Vector2(left - 4, top - 12), Vector2(left + w / 2.0, top - 22), Vector2(left + w + 4, top - 12)]), SbData.WOOD2)
			draw_rect(Rect2(left - 4, top - 13, w + 8, 2), SbData.PLANK)
			draw_rect(Rect2(left + 10, -8, w - 20, 2), SbData.WOOD3)
			draw_rect(Rect2(left + 12, -6, 2, 6), SbData.WOOD0)
			draw_rect(Rect2(left + w - 14, -6, 2, 6), SbData.WOOD0)
			var t := Time.get_ticks_msec() / 80.0 if not workers.is_empty() else 0.0
			draw_circle(Vector2(left + w / 2.0, -10), 4.0, SbData.STONE3)
			draw_line(Vector2(left + w / 2.0, -10), Vector2(left + w / 2.0, -10) + Vector2(cos(t), sin(t)) * 4.0, SbData.STONE1, 1.0)
			if keep > 0:
				draw_string(ThemeDB.fallback_font, Vector2(left, top - 24), "keep %d" % keep, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SbData.WHITE)
		"thatch":
			# A thatched roof and a door.
			var roof := PackedVector2Array([Vector2(left - 4, top), Vector2(left + w / 2.0, top - 14), Vector2(left + w + 4, top)])
			draw_colored_polygon(roof, SbData.THATCH)
			for row in 3:
				var y := top - 3.0 - row * 4.0
				var half := (w / 2.0 + 4.0) * (1.0 - (row * 4.0 + 3.0) / 14.0)
				draw_line(Vector2(left + w / 2.0 - half, y), Vector2(left + w / 2.0 + half, y), SbData.WOOD3, 1.0)
			draw_rect(Rect2(left + w / 2.0 - 3.0, -9.0, 6, 9), SbData.WOOD0)
			# A small window, glowing at night.
			var lit: bool = world.darkness() > 0.3
			draw_rect(Rect2(left + 4.0, top + 5.0, 6, 5), SbData.LIGHT if lit else SbData.INK)
			draw_rect(Rect2(left + 6.0, top + 5.0, 1, 5), SbData.WOOD0)
		"battlements":
			var i := 0
			var x := left
			while x < left + w - 0.5:
				if i % 2 == 0:
					draw_rect(Rect2(x, top - 5.0, minf(5.0, left + w - x), 5.0), SbData.STONE3)
				x += 5.0
				i += 1
			draw_rect(Rect2(left + w / 2.0 - 1.0, top + 6.0, 2, 4), SbData.INK)
		"spire":
			var roof := PackedVector2Array([Vector2(left - 3, top), Vector2(left + w / 2.0, top - 22), Vector2(left + w + 3, top)])
			draw_colored_polygon(roof, SbData.SLATE1)
			draw_line(Vector2(left + w / 2.0, top - 22), Vector2(left + w / 2.0, top - 32), SbData.WOOD0, 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(left + w / 2.0, top - 32), Vector2(left + w / 2.0 + 7, top - 30), Vector2(left + w / 2.0, top - 28)]), SbData.RED1)
			draw_rect(Rect2(left + w / 2.0 - 1.0, top + 8.0, 2, 4), SbData.INK)
			draw_rect(Rect2(left + w / 2.0 - 3.0, -10.0, 6, 10), SbData.WOOD0)


func describe() -> String:
	return progress_text() + (" (forbidden)" if forbidden else "")
