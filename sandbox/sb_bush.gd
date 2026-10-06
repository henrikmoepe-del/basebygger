extends "res://sandbox/sb_thing.gd"
## A berry bush: foraged a basket at a time; the basket is left beside it
## for someone to haul. Picked bare, it grows berries again.

const PICK_TIME := 2.5
const REGROW_TIME := 70.0

var berries := 3
var _full := 3
var _progress := 0.0
var _regrow := 0.0
var _shake := 0.0


func setup(n: int) -> void:
	kind = "bush"
	berries = n
	_full = n


func capacity() -> int:
	return 1


func is_open() -> bool:
	return berries > 0


## Work on the bush for `amount` seconds. Returns true when a basket is full.
func forage(amount: float) -> bool:
	if berries <= 0:
		return false
	_progress += amount
	_shake = 0.2
	if _progress < PICK_TIME:
		return false
	_progress = 0.0
	berries -= 1
	world.spawn_item("food", position + Vector2(randf_range(-8, 8), randf_range(3, 7)))
	if berries == 0:
		_regrow = REGROW_TIME
	queue_redraw()
	return true


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-9, -12), Vector2(18, 14)).has_point(p)


func label() -> String:
	return "a berry bush"


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		queue_redraw()
	if berries == 0:
		_regrow -= delta
		if _regrow <= 0.0:
			berries = _full
			queue_redraw()


func _draw() -> void:
	var j := 1.0 if _shake > 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0 else 0.0
	draw_circle(Vector2(j, -5), 7.0, SbData.GRASS1)
	draw_circle(Vector2(-3 + j, -7), 4.0, SbData.GRASS2)
	draw_circle(Vector2(3 + j, -6), 4.0, SbData.GRASS2)
	for i in berries * 2:
		draw_rect(Rect2(-5 + (i * 7) % 11 + j, -9 + (i * 5) % 7, 2, 2), SbData.RED1)
