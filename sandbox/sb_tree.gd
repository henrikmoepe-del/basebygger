extends "res://sandbox/sb_thing.gd"
## A tree: chopped a log at a time; the log falls on the ground beside it for
## someone to haul. When the wood is gone a stump is left, which grows back.

const CHOP_TIME := 3.0
const REGROW_TIME := 90.0

var wood := 4
var _full := 4
var _progress := 0.0
var _shake := 0.0
var _regrow := 0.0
var _size := 1.0


func setup(logs: int, size: float) -> void:
	kind = "tree"
	wood = logs
	_full = logs
	_size = size


func is_open() -> bool:
	return wood > 0


## Work on the tree for `amount` seconds. Returns true when a log falls.
func chop(amount: float) -> bool:
	if wood <= 0:
		return false
	_progress += amount
	_shake = 0.25
	queue_redraw()
	if _progress < CHOP_TIME:
		return false
	_progress = 0.0
	wood -= 1
	world.spawn_item("wood", position + Vector2(randf_range(-12, 12), randf_range(3, 9)))
	if wood == 0:
		_regrow = REGROW_TIME
	return true


func hit(p: Vector2) -> bool:
	var h := 40.0 * _size if wood > 0 else 6.0
	return Rect2(position + Vector2(-10 * _size, -h), Vector2(20 * _size, h + 3)).has_point(p)


func label() -> String:
	return "a tree"


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		queue_redraw()
	if wood == 0:
		_regrow -= delta
		if _regrow <= 0.0:
			wood = _full
			queue_redraw()


func _draw() -> void:
	if wood == 0:
		draw_rect(Rect2(-3, -3, 6, 4), SbData.WOOD1)
		draw_rect(Rect2(-2, -3, 4, 1), SbData.WOOD3)
		return
	var sway := sin(Time.get_ticks_msec() / 30.0) * 1.5 if _shake > 0.0 else 0.0
	var s := _size
	draw_rect(Rect2(-2 * s, -16 * s, 4 * s, 16 * s + 1), SbData.WOOD1)
	draw_rect(Rect2(-2 * s, -16 * s, 1, 16 * s), SbData.WOOD2)
	# Canopy: a few round blobs, lit from the upper left.
	var c := Vector2(sway, -24 * s)
	draw_circle(c + Vector2(0, 2 * s), 12 * s, SbData.GRASS1)
	draw_circle(c + Vector2(-5 * s, -2 * s), 8 * s, SbData.GRASS2)
	draw_circle(c + Vector2(5 * s, 0), 8 * s, SbData.GRASS2)
	draw_circle(c + Vector2(-4 * s, -5 * s), 5 * s, SbData.GRASS3)
	# A notch shows how far the chopping has got.
	if wood < _full or _progress > 0.0:
		draw_rect(Rect2(-2 * s, -5, 2, 3), SbData.WOOD3)
