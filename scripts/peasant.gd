extends Node2D
## One peasant: finds a gather spot, walks there, works, carries the
## resource home, and repeats. Placeholder shapes until we have real art.

enum State { IDLE, TO_WORK, WORKING, TO_HOME }

const CARRY_COLORS := {"wood": Color(0.48, 0.32, 0.20), "stone": Color(0.55, 0.57, 0.62)}
const RETRY_TIME := 0.5

var resource_type := "wood"
var home_x := 0.0
var speed := 50.0
var work_time := 1.0
## Called with a resource type; returns a spot to gather at, or null.
var find_spot: Callable

var _state := State.IDLE
var _timer := 0.0
var _spot: Node2D
var _spot_offset := randf_range(-5.0, 5.0)
var _carrying := 0


func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			# Nothing to gather (e.g. all trees regrowing): wait and look again.
			_timer -= delta
			if _timer <= 0.0:
				_spot = find_spot.call(resource_type)
				_timer = RETRY_TIME
				if _spot != null:
					_state = State.TO_WORK
		State.TO_WORK:
			if not _spot.can_gather():
				_state = State.IDLE
				_timer = 0.0
			elif _walk_to(_spot.position.x + _spot_offset, delta):
				_state = State.WORKING
				_timer = work_time
		State.WORKING:
			_timer -= delta
			if _timer <= 0.0:
				if _spot.take():
					_carrying = 1
					_state = State.TO_HOME
				else:
					# Someone else took the last of it.
					_state = State.IDLE
					_timer = 0.0
				queue_redraw()
		State.TO_HOME:
			if _walk_to(home_x, delta):
				GameState.add_resource(resource_type, _carrying)
				_carrying = 0
				_state = State.IDLE
				_timer = 0.0
				queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-3, -10, 6, 10), Color(0.30, 0.38, 0.62))
	draw_rect(Rect2(-2, -14, 4, 4), Color(0.93, 0.76, 0.62))
	if _carrying > 0:
		draw_rect(Rect2(-3, -19, 6, 4), CARRY_COLORS[resource_type])


## Moves towards x and returns true once there.
func _walk_to(x: float, delta: float) -> bool:
	position.x = move_toward(position.x, x, speed * delta)
	return is_equal_approx(position.x, x)
