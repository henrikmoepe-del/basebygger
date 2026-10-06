extends "res://sandbox/sb_thing.gd"
## A rock outcrop: mined a stone at a time; the stone falls beside it for
## someone to haul. When it is used up it is gone.

const MINE_TIME := 4.0

var stone := 6
var _full := 6
var _progress := 0.0
var _shake := 0.0


func setup(stones: int) -> void:
	kind = "rock"
	stone = stones
	_full = stones


func is_open() -> bool:
	return stone > 0


## Work on the rock for `amount` seconds. Returns true when a stone comes loose.
func mine(amount: float) -> bool:
	if stone <= 0:
		return false
	_progress += amount
	_shake = 0.2
	queue_redraw()
	if _progress < MINE_TIME:
		return false
	_progress = 0.0
	stone -= 1
	world.spawn_item("stone", position + Vector2(randf_range(-12, 12), randf_range(3, 8)))
	if stone == 0:
		world.announce("A rock is used up.")
	return true


func hit(p: Vector2) -> bool:
	return stone > 0 and Rect2(position + Vector2(-14, -16), Vector2(28, 19)).has_point(p)


func label() -> String:
	return "a rock"


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	if stone <= 0:
		draw_rect(Rect2(-6, -2, 12, 2), SbData.STONE1)
		return
	var f := 0.5 + 0.5 * float(stone) / float(_full)
	var jig := 1.0 if _shake > 0.0 and int(Time.get_ticks_msec() / 50) % 2 == 0 else 0.0
	var pts := PackedVector2Array([Vector2(-13, 0), Vector2(-10, -10 * f), Vector2(-3, -15 * f),
			Vector2(6, -13 * f), Vector2(12, -6 * f), Vector2(13, 0)])
	for i in pts.size():
		pts[i].x += jig
	draw_colored_polygon(pts, SbData.STONE2)
	draw_colored_polygon(PackedVector2Array([Vector2(-10 + jig, -10 * f), Vector2(-3 + jig, -15 * f), Vector2(1 + jig, -9 * f), Vector2(-6 + jig, -6 * f)]), SbData.STONE3)
	draw_line(Vector2(2 + jig, -12 * f), Vector2(5 + jig, -4 * f), SbData.STONE1, 1.0)
