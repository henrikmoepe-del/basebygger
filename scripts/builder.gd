extends "res://scripts/worker.gd"
## A peasant who builds. While there is a building job they alternate between
## hauling materials from the stockhouse to the site and hammering them in.

enum State { IDLE, TO_STOCK, TO_SITE, HAMMER }

var _state := State.IDLE
var _carrying := 0
var _offset := randf_range(-8.0, 8.0)
var _swing := randf() * TAU
var _hammering := false


func _work(delta: float) -> void:
	_hammering = false
	if GameState.job_part == "":
		# No job: put down anything carried and wait by the castle.
		_carrying = 0
		_state = State.IDLE
		_walk_to(home_x, delta)
		return

	match _state:
		State.IDLE:
			_state = _choose_task()
		State.TO_STOCK:
			if _walk_to(world.stock_x + _offset, delta):
				_carrying = GameState.job_take_load(int(GameState.builder_load() * _skill()))
				_state = State.TO_SITE if _carrying > 0 else State.IDLE
		State.TO_SITE:
			if _walk_to(world.site_x() + _offset, delta):
				GameState.job_deliver(_carrying)
				_carrying = 0
				_state = State.IDLE
		State.HAMMER:
			if _walk_to(world.site_x() + _offset, delta):
				if GameState.job_can_hammer():
					_hammering = true
					# One clink each time the hammer comes down.
					if int((_swing + delta * 10.0) / PI) != int(_swing / PI):
						get_tree().call_group("sfx", "play", "hammer")
					_swing += delta * 10.0
					GameState.job_add_work(GameState.hammer_rate() * _skill() * delta)
				else:
					_state = State.IDLE


func _exit_tree() -> void:
	# Reassigned while carrying: the load goes back to the stockhouse.
	if _carrying > 0 and GameState.job_part != "":
		GameState.job_return_load(_carrying)


## Hammer in what has arrived first; otherwise fetch more; otherwise wait at the site.
func _choose_task() -> State:
	if GameState.job_can_hammer():
		return State.HAMMER
	if GameState.job_claimed < GameState.job_units:
		return State.TO_STOCK
	return State.HAMMER


func _bob() -> float:
	return -absf(sin(_swing)) * 2.0 if _hammering else 0.0


func _draw_extra(bob_y: float) -> void:
	if _carrying > 0:
		draw_rect(Rect2(-4, -20, 8, 5), Color(0.62, 0.62, 0.66))
	elif _hammering:
		# Hammer swings forward and back.
		var reach := 4.0 + absf(sin(_swing)) * 3.0
		draw_rect(Rect2(reach, bob_y - 12, 4, 3), Color(0.30, 0.30, 0.34))
		draw_rect(Rect2(3, bob_y - 10, reach - 2, 1), Color(0.48, 0.32, 0.20))


func _walk_to(x: float, delta: float) -> bool:
	position.x = move_toward(position.x, x, speed * GameState.builder_speed_mult() * delta)
	return is_equal_approx(position.x, x)
