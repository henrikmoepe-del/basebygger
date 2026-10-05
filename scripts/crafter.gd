extends "res://scripts/worker.gd"
## A peasant who works in a workshop (see workshop_data.gd): sawyers at the
## sawmill, bakers at the bakery. They take what a few batches need from the
## stockyard, carry it to the workshop, work it there, and carry what they
## made back to its store. With too little to work, or no room in the store
## for what they make, the time is their own.

const WorkshopData = preload("res://scripts/workshop_data.gd")

enum State { TO_INPUTS, TO_SHOP, WORK, TO_STORE }

## Seconds between strokes of the work (for the sound and the chips).
const STROKE_TIME := 0.4

var _state := State.TO_INPUTS
## How many batches are being carried or worked.
var _batches := 0
var _timer := 0.0
var _stroke := 0.0
var _working := false
var _offset := randf_range(-5.0, 5.0)
var _shop: Dictionary


func _work(delta: float) -> void:
	_shop = WorkshopData.WORKSHOPS[job]
	_working = false
	var first_input: String = _shop.inputs.keys()[0]
	match _state:
		State.TO_INPUTS:
			if _can_make() == 0 or GameState.store_full(_shop.output):
				_relax(delta, world.store_x(first_input), 60.0)
			elif _walk_to(world.store_x(first_input) + _offset, delta):
				# Everything for the batches is taken from the stockyard at once.
				_batches = _can_make()
				if _batches > 0:
					for type: String in _shop.inputs:
						GameState.resources[type] -= _shop.inputs[type] * _batches
					GameState.resources_changed.emit()
					_state = State.TO_SHOP
		State.TO_SHOP:
			if _walk_to(CastleData.PARTS[_shop.part].site_x + _offset, delta):
				_timer = _shop.time * _batches / _skill()
				_state = State.WORK
		State.WORK:
			_working = true
			_timer -= delta * GameState.work_mult()
			_stroke -= delta
			if _stroke <= 0.0:
				_stroke = STROKE_TIME
				get_tree().call_group("sfx", "play", _shop.sound)
				get_tree().call_group("effects", "burst", global_position + Vector2(6, -8), _shop.carry_out, 2)
			if _timer <= 0.0:
				_state = State.TO_STORE
		State.TO_STORE:
			if _walk_to(world.store_x(_shop.output) + _offset, delta):
				GameState.add_income(_shop.output, _shop.makes * _batches)
				_batches = 0
				_state = State.TO_INPUTS


## How many batches this crafter can take from the stockyard now.
func _can_make() -> int:
	var batches: int = int(_shop.batches * _skill())
	for type: String in _shop.inputs:
		batches = mini(batches, GameState.resources[type] / _shop.inputs[type])
	return maxi(batches, 0)


func _exit_tree() -> void:
	if _batches == 0 or _shop.is_empty():
		return
	if _state == State.TO_STORE:
		# Reassigned with the goods made: they are handed in.
		GameState.add_income(_shop.output, _shop.makes * _batches)
	else:
		# Reassigned before the work was done: the goods go back to their stores.
		for type: String in _shop.inputs:
			GameState.resources[type] += _shop.inputs[type] * _batches
		GameState.resources_changed.emit()


func _bob() -> float:
	return -absf(sin(Time.get_ticks_msec() / 110.0)) * 1.5 if _working else 0.0


func _draw_extra(bob_y: float) -> void:
	if _working:
		# The tool going back and forth over the work.
		var reach := 3.0 + sin(Time.get_ticks_msec() / 110.0) * 3.0
		draw_rect(Rect2(reach, bob_y - 8, 8, 1), Color(0.75, 0.76, 0.80))
		draw_rect(Rect2(reach - 1, bob_y - 10, 2, 4), _shop.carry_in)
	elif _batches > 0 and _state == State.TO_STORE:
		draw_rect(Rect2(-8, -19, 16, 2), _shop.carry_out)
		draw_rect(Rect2(-7, -17, 16, 1), _shop.carry_out.darkened(0.15))
	elif _batches > 0:
		draw_rect(Rect2(-6, -20, 12, 4), _shop.carry_in)
