extends "res://scripts/worker.gd"
## A peasant who saws planks. They carry logs from the wood stack to the
## sawmill, saw them there, and carry the planks back to the plank stack in
## the stockyard. One log makes one plank. With no wood to saw, or no room
## for more planks, the time is their own.

enum State { TO_WOOD, TO_MILL, SAW, TO_STACK }

## How many logs a sawyer carries at once, and how long each takes to saw.
const LOAD := 2
const SAW_TIME := 3.0
## Seconds between strokes of the saw (for the sound).
const STROKE_TIME := 0.4
const LOG := Color(0.52, 0.36, 0.22)
const PLANK := Color(0.78, 0.60, 0.36)

var _state := State.TO_WOOD
var _carrying := 0
var _timer := 0.0
var _stroke := 0.0
var _sawing := false
var _offset := randf_range(-5.0, 5.0)


func _work(delta: float) -> void:
	_sawing = false
	match _state:
		State.TO_WOOD:
			if GameState.resources.wood <= 0 or GameState.store_full("planks"):
				_relax(delta, world.store_x("wood"), 60.0)
			elif _walk_to(world.store_x("wood") + _offset, delta):
				_carrying = GameState.take_wood(int(LOAD * _skill()))
				if _carrying > 0:
					_state = State.TO_MILL
		State.TO_MILL:
			if _walk_to(CastleData.SAWMILL_X + _offset, delta):
				_timer = SAW_TIME * _carrying / _skill()
				_state = State.SAW
		State.SAW:
			_sawing = true
			_timer -= delta * GameState.work_mult()
			_stroke -= delta
			if _stroke <= 0.0:
				_stroke = STROKE_TIME
				get_tree().call_group("sfx", "play", "chop")
				get_tree().call_group("effects", "burst", global_position + Vector2(6, -8), PLANK, 2)
			if _timer <= 0.0:
				_state = State.TO_STACK
		State.TO_STACK:
			if _walk_to(world.store_x("planks") + _offset, delta):
				GameState.add_income("planks", _carrying)
				_carrying = 0
				_state = State.TO_WOOD


func _exit_tree() -> void:
	# Reassigned with logs in hand: they go back on the stack.
	if _carrying > 0 and _state != State.TO_STACK:
		GameState.resources.wood += _carrying
		GameState.resources_changed.emit()
	elif _carrying > 0:
		GameState.add_income("planks", _carrying)


func _bob() -> float:
	return -absf(sin(Time.get_ticks_msec() / 110.0)) * 1.5 if _sawing else 0.0


func _draw_extra(bob_y: float) -> void:
	if _sawing:
		# The saw going back and forth.
		var reach := 3.0 + sin(Time.get_ticks_msec() / 110.0) * 3.0
		draw_rect(Rect2(reach, bob_y - 8, 8, 1), Color(0.75, 0.76, 0.80))
		draw_rect(Rect2(reach - 1, bob_y - 10, 2, 4), LOG)
	elif _carrying > 0 and _state == State.TO_STACK:
		draw_rect(Rect2(-8, -19, 16, 2), PLANK)
		draw_rect(Rect2(-7, -17, 16, 1), PLANK.darkened(0.15))
	elif _carrying > 0:
		draw_rect(Rect2(-6, -20, 12, 4), LOG)
