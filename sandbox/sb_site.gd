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
	return not done()


func done() -> bool:
	return placed >= mats.size()


## The material the next block needs, or "" when finished.
func next_material() -> String:
	return "" if done() else mats[placed]


func add_block(material: String) -> void:
	if done():
		return
	laid.append(material)
	placed += 1
	if done():
		_flash = 1.0
		world.announce("The %s is finished." % title)
	queue_redraw()


## Fire knocks blocks off the top.
func lose_block() -> void:
	if placed > 0:
		placed -= 1
		laid.pop_back()
	queue_redraw()


func burn() -> void:
	lose_block()


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


func progress_text() -> String:
	return "%s: %d / %d blocks" % [title, placed, mats.size()]


func _process(delta: float) -> void:
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
		else:
			draw_rect(r, SbData.WOOD2 if shade else SbData.WOOD1)
			draw_rect(Rect2(r.position, Vector2(BW, 1)), SbData.WOOD3)
			draw_rect(Rect2(r.position + Vector2(BW - 1, 0), Vector2(1, BH)), SbData.WOOD0)
	if done():
		_draw_finish(left, w)
	if _flash > 0.0:
		draw_rect(Rect2(left, -height(), w, height()), Color(SbData.LIGHT, _flash * 0.6))
	# Name board while it is still a site.
	if not done():
		draw_rect(Rect2(left - 3.0, -4.0, 1, 4), SbData.WOOD1)
		draw_rect(Rect2(left - 6.0, -8.0, 7, 4), SbData.WOOD3)


func _draw_finish(left: float, w: float) -> void:
	var top := -height()
	match style:
		"thatch":
			# A thatched roof and a door.
			var roof := PackedVector2Array([Vector2(left - 4, top), Vector2(left + w / 2.0, top - 14), Vector2(left + w + 4, top)])
			draw_colored_polygon(roof, SbData.THATCH)
			for row in 3:
				var y := top - 3.0 - row * 4.0
				var half := (w / 2.0 + 4.0) * (1.0 - (row * 4.0 + 3.0) / 14.0)
				draw_line(Vector2(left + w / 2.0 - half, y), Vector2(left + w / 2.0 + half, y), SbData.WOOD3, 1.0)
			draw_rect(Rect2(left + w / 2.0 - 3.0, -9.0, 6, 9), SbData.WOOD0)
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
