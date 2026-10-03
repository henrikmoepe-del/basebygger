extends Node2D
## One builder. While there is a building job they alternate between hauling
## materials from the stockhouse to the site and hammering them in.
## Placeholder shapes until we have real art.

enum State { IDLE, TO_STOCK, TO_SITE, HAMMER }

var stock_x := 0.0
var rest_x := 0.0
## Returns the x position of the current building site.
var site_x: Callable
var speed := 45.0

var _state := State.IDLE
var _carrying := 0
var _offset := randf_range(-8.0, 8.0)
var _swing := randf() * TAU


func _process(delta: float) -> void:
	if GameState.job_part == "":
		# No job: put down anything carried and wait by the castle.
		_carrying = 0
		_state = State.IDLE
		_walk_to(rest_x, delta)
		queue_redraw()
		return

	match _state:
		State.IDLE:
			_state = _choose_task()
		State.TO_STOCK:
			if _walk_to(stock_x + _offset, delta):
				_carrying = GameState.job_take_load(GameState.builder_load())
				_state = State.TO_SITE if _carrying > 0 else State.IDLE
		State.TO_SITE:
			if _walk_to(site_x.call() + _offset, delta):
				GameState.job_deliver(_carrying)
				_carrying = 0
				_state = State.IDLE
		State.HAMMER:
			if _walk_to(site_x.call() + _offset, delta):
				if GameState.job_can_hammer():
					_swing += delta * 10.0
					GameState.job_add_work(GameState.hammer_rate() * delta)
				else:
					_state = State.IDLE
	queue_redraw()


## Hammer in what has arrived first; otherwise fetch more; otherwise wait at the site.
func _choose_task() -> State:
	if GameState.job_can_hammer():
		return State.HAMMER
	if GameState.job_claimed < GameState.job_units:
		return State.TO_STOCK
	return State.HAMMER


func _draw() -> void:
	var hammering := _state == State.HAMMER and GameState.job_can_hammer()
	var bob := -absf(sin(_swing)) * 2.0 if hammering else 0.0
	draw_rect(Rect2(-3, bob - 10, 6, 10), Color(0.80, 0.52, 0.20))
	draw_rect(Rect2(-2, bob - 14, 4, 4), Color(0.93, 0.76, 0.62))
	if _carrying > 0:
		draw_rect(Rect2(-4, -20, 8, 5), Color(0.62, 0.62, 0.66))
	elif hammering:
		# Hammer swings forward and back.
		var reach := 4.0 + absf(sin(_swing)) * 3.0
		draw_rect(Rect2(reach, bob - 12, 4, 3), Color(0.30, 0.30, 0.34))
		draw_rect(Rect2(3, bob - 10, reach - 2, 1), Color(0.48, 0.32, 0.20))


## Moves towards x and returns true once there.
func _walk_to(x: float, delta: float) -> bool:
	position.x = move_toward(position.x, x, speed * GameState.builder_speed_mult() * delta)
	return is_equal_approx(position.x, x)
