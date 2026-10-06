extends Node2D
## Draws the art lab's test map from pictures made with PixelLab
## (art_lab/pixellab, prepared by prep.py into art_lab/pixellab/ready).
## Unlike painter.gd, nothing here is drawn shape by shape: the buildings,
## trees, background and peasants are pictures. The keep goes up out of its
## own picture, one piece (14 x 8 pixels) at a time, bottom course first.
## Drawn at 640 x 360, the game's own size; the background is 320 x 180
## shown twice as big, so it has bigger pixels, like a distant layer.

const W := 640.0
const H := 360.0
const GY := 300.0             ## the ground line the castle stands on
const DIR := "res://art_lab/pixellab/"
const BUILD_TIME := 50.0
const HOLD_TIME := 6.0
const PIECE := Vector2i(14, 8)
## The part of keep.png that is the keep: left, top, right, bottom (its foot).
const KEEP_BOX := Rect2i(9, 34, 110, 135)
const KEEP_X := 211.0         ## where keep.png's left edge goes on screen
const ROPE_X := 352.0
const FPS := 9.0

var style: Dictionary = {}
var t := 0.0
var tex := {}
var pieces: Array[Rect2i] = []   ## in keep.png's pixels, in the order they are laid
var row_ends: Array[int] = []
var laid := 0
var deck_y := GY
var finished := false


func setup(st: Dictionary) -> void:
	style = st
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for n in ["tower", "keep", "gatehouse", "house", "house2", "well", "pine", "oak", "log_pile"]:
		tex[n] = load(DIR + n + ".png")
	for n in ["backdrop", "wall", "block"]:
		tex[n] = load(DIR + "ready/" + n + ".png")
	for a in ["walk", "hammer", "pull", "climb"]:
		for c in ["", "_red", "_green", "_brown"]:
			tex[a + c] = load(DIR + "ready/" + a + c + ".png")
	_make_pieces()
	queue_redraw()


func block() -> Vector2:
	return Vector2(PIECE)


func piece_count() -> int:
	return pieces.size()


## The keep picture cut into pieces, every other course shifted by half a piece.
## Pieces that would be all empty (between the battlements) are left out.
func _make_pieces() -> void:
	pieces.clear()
	row_ends.clear()
	var img: Image = tex.keep.get_image()
	var bottom := KEEP_BOX.end.y
	var r := 0
	while bottom > KEEP_BOX.position.y:
		var top := maxi(bottom - PIECE.y, KEEP_BOX.position.y)
		var x := KEEP_BOX.position.x - (PIECE.x / 2 if r % 2 == 1 else 0)
		while x < KEEP_BOX.end.x:
			var a := maxi(x, KEEP_BOX.position.x)
			var e := mini(x + PIECE.x, KEEP_BOX.end.x)
			var rect := Rect2i(a, top, e - a, bottom - top)
			if e > a and not img.get_region(rect).is_invisible():
				pieces.append(rect)
			x += PIECE.x
		row_ends.append(pieces.size())
		bottom = top
		r += 1


func _keep_y() -> float:
	return GY - KEEP_BOX.end.y


# ---------------------------------------------------------------- the frame

func _draw() -> void:
	_update_build()
	draw_texture_rect(tex.backdrop, Rect2(0, 0, W, H), false)
	_draw_road()
	_put("oak", 196.0, GY - 2.0, 59)
	_draw_wall()
	_put("gatehouse", 52.0, GY, 115)
	_put("tower", 158.0, GY, 181)
	_draw_keep()
	_draw_works()
	_put("pine", 497.0, GY - 1.0, 60)
	_put("log_pile", 478.0, GY + 1.0, 30)
	_put("house", 548.0, GY + 1.0, 90)
	_put("well", 606.0, GY + 1.0, 45)
	_put("pine", 632.0, GY, 60)
	_draw_people()


func _update_build() -> void:
	var cyc := fmod(t, BUILD_TIME + HOLD_TIME)
	finished = cyc >= BUILD_TIME
	var p := 1.0 if finished else 0.25 + 0.75 * cyc / BUILD_TIME
	laid = clampi(int(p * pieces.size()), 0, pieces.size())
	var full := 0
	for e in row_ends:
		if e <= laid:
			full += 1
	deck_y = GY - minf(full * PIECE.y, KEEP_BOX.size.y)


## A picture placed with its middle at x and the foot of what it shows at
## bottom; foot is the row in the picture where the thing stands.
func _put(name: String, x: float, bottom: float, foot: int) -> void:
	var t2: Texture2D = tex[name]
	draw_texture(t2, Vector2(round(x - t2.get_width() * 0.5), round(bottom - foot)))


func _draw_road() -> void:
	draw_rect(Rect2(0, GY - 2, W, 12), Color("#c9a877"))
	draw_rect(Rect2(0, GY - 2, W, 1), Color("#a8875a"))
	draw_rect(Rect2(0, GY + 10, W, 1), Color("#8fae4a"))
	for i in 90:
		var x := floorf(_hash(i, 1.0) * W)
		var y := GY + floorf(_hash(i, 2.0) * 10.0)
		draw_rect(Rect2(x, y, 2, 1), Color("#b39363") if i % 3 else Color("#dcc496"))


func _draw_wall() -> void:
	var wall: Texture2D = tex.wall
	var top := GY - wall.get_height()
	draw_texture_rect_region(wall, Rect2(0, top, 200, wall.get_height()), Rect2(0, 0, 200, wall.get_height()))
	# a guard walks the wall, behind the battlements
	var gx := 110.0 + sin(t * 0.25) * 40.0
	_peasant("walk_brown", _frame(1, 8), gx, top + 21.0, cos(t * 0.25) > 0.0)
	draw_texture_rect_region(wall, Rect2(0, top, 200, 16), Rect2(0, 0, 200, 16))


func _draw_keep() -> void:
	var origin := Vector2(KEEP_X, _keep_y())
	for i in laid:
		var r := pieces[i]
		draw_texture_rect_region(tex.keep, Rect2(origin + Vector2(r.position), Vector2(r.size)), Rect2(r))


## The ladder against the keep, the hoist on its deck, the rope and the
## stone pile, all while building.
func _draw_works() -> void:
	var wood := Color("#7a4a2a")
	var dark := Color("#4f2e18")
	# stone pile, made of the keep's own block
	var b: Texture2D = tex.block
	for row in 3:
		for i in 4 - row:
			draw_texture(b, Vector2(424.0 + i * 14.0 + row * 7.0, GY - (row + 1) * 8.0))
	if finished:
		return
	var right := KEEP_X + KEEP_BOX.end.x
	var lt := deck_y - 6.0
	# ladder
	draw_rect(Rect2(right + 2, lt, 2, GY - lt), wood)
	draw_rect(Rect2(right + 10, lt, 2, GY - lt), wood)
	var ry := GY - 4.0
	while ry > lt:
		draw_rect(Rect2(right + 2, ry, 10, 1), dark)
		ry -= 6.0
	# hoist: an A-frame on the deck with a beam out over the yard
	var top := deck_y - 22.0
	draw_line(Vector2(right - 16, deck_y), Vector2(right - 10, top), dark, 2.0)
	draw_line(Vector2(right - 4, deck_y), Vector2(right - 10, top), dark, 2.0)
	draw_rect(Rect2(right - 14, top - 2, ROPE_X - right + 16, 3), wood)
	draw_circle(Vector2(ROPE_X, top + 2), 2.5, dark)
	# the rope and the block on it
	var rc := fmod(t / 6.0, 1.0)
	var end_y := GY - 9.0
	var has_block := true
	if rc >= 0.2 and rc < 0.85:
		end_y = lerpf(GY - 9.0, deck_y - 18.0, (rc - 0.2) / 0.65)
	elif rc >= 0.85:
		end_y = deck_y - 20.0
		has_block = false
	var rope := Color("#5a4632")
	draw_line(Vector2(ROPE_X, top + 4), Vector2(ROPE_X, end_y), rope, 1.0)
	draw_line(Vector2(ROPE_X - 2, top + 3), Vector2(right - 12, deck_y - 14), rope, 1.0)
	if has_block:
		draw_texture(b, Vector2(ROPE_X - 7, end_y + 1))


# ---------------------------------------------------------------- people

func _frame(first: int, last: int, fps := FPS) -> int:
	return first + int(t * fps) % (last - first + 1)


## One frame of a peasant animation strip, feet at (x, fy). The pictures face
## right; flip turns them to face left.
func _peasant(anim: String, frame: int, x: float, fy: float, face_right := true) -> void:
	var strip: Texture2D = tex[anim]
	var src := Rect2(frame * 32, 0, 32, 32)
	var pos := Vector2(round(x), round(fy - 31.0))
	if face_right:
		draw_texture_rect_region(strip, Rect2(pos.x - 16.0, pos.y, 32, 32), src)
	else:
		draw_set_transform(Vector2(pos.x + 17.0, pos.y), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(strip, Rect2(0, 0, 32, 32), src)
		draw_set_transform(Vector2.ZERO)


func _carried(x: float, fy: float, face_right: bool) -> void:
	draw_texture(tex.block, Vector2(round(x - 7.0 + (-3.0 if face_right else 3.0)), round(fy - 31.0)))


func _draw_people() -> void:
	# the stonemason shaping blocks: the hammer animation brings its own anvil
	_peasant("hammer", _frame(1, 8, 7.0), 398.0, GY + 2.0, true)
	# carrier from the stone pile to the yard and back
	var cf := fmod(t / 9.0, 1.0)
	if cf < 0.45:
		var x := lerpf(468.0, 372.0, cf / 0.45)
		_peasant("walk_green", _frame(1, 8), x, GY + 6.0, false)
		_carried(x, GY + 6.0, false)
	elif cf < 0.5:
		_peasant("walk_green", 0, 372.0, GY + 6.0, false)
	elif cf < 0.95:
		_peasant("walk_green", _frame(1, 8), lerpf(372.0, 468.0, (cf - 0.5) / 0.45), GY + 6.0, true)
	else:
		_peasant("walk_green", 0, 468.0, GY + 6.0, true)
	# a villager on the road
	var vl := fmod(t * 14.0, 200.0)
	_peasant("walk_red", _frame(1, 8), 520.0 + pingpong(t * 14.0, 100.0), GY + 9.0, vl < 100.0)
	if finished:
		_peasant("walk", 0, 360.0, GY + 4.0, false)
		_peasant("walk", 0, 340.0, GY + 6.0, true)
		return
	var rc := fmod(t / 6.0, 1.0)
	var right := KEEP_X + KEEP_BOX.end.x
	# the one who ties blocks on the rope
	_peasant("pull_brown" if rc < 0.2 else "walk_brown", _frame(1, 3) if rc < 0.2 else 0, ROPE_X + 9.0, GY + 3.0, false)
	# the hauler at the hoist
	if rc >= 0.2 and rc < 0.85:
		_peasant("pull_red", _frame(3, 8), right - 24.0, deck_y, true)
	else:
		_peasant("walk_red", 0, right - 24.0, deck_y, true)
	# the mason fetches a block from the hoist and walks it to where it goes
	if laid < pieces.size():
		var nb := pieces[laid]
		var goal := KEEP_X + nb.position.x + nb.size.x + 6.0
		goal = minf(goal, right - 40.0)
		var mf := fmod(t / 5.0, 1.0)
		var from := right - 40.0
		var x := lerpf(from, goal, pingpong(mf * 2.0, 1.0))
		var going := mf < 0.5
		var still := absf(from - goal) < 2.0
		_peasant("walk", 0 if still else _frame(1, 8), x, deck_y, not going)
		if going:
			_carried(x, deck_y, false)
	# someone on the ladder
	var lf := absf(fmod(t / 7.0, 1.0) * 2.0 - 1.0)
	_peasant("climb_green", _frame(2, 8), right + 7.0, lerpf(GY, deck_y + 2.0, lf), true)


func _hash(a: float, b: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floor(v)
