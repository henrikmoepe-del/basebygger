extends Node2D
## One peasant: walks to a gather spot, works, carries one resource home,
## and repeats. Drawn with placeholder shapes until we have real art.

enum State { TO_WORK, WORKING, TO_HOME }

const CARRY_COLORS := {"wood": Color(0.48, 0.32, 0.20), "stone": Color(0.55, 0.57, 0.62)}

var resource_type := "wood"
var work_x := 0.0
var home_x := 0.0
var speed := 50.0
var work_time := 1.0

var _state := State.TO_WORK
var _timer := 0.0


func _process(delta: float) -> void:
	match _state:
		State.TO_WORK:
			if _walk_to(work_x, delta):
				_state = State.WORKING
				_timer = work_time
		State.WORKING:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.TO_HOME
				queue_redraw()
		State.TO_HOME:
			if _walk_to(home_x, delta):
				GameState.add_resource(resource_type, 1)
				_state = State.TO_WORK
				queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-3, -10, 6, 10), Color(0.30, 0.38, 0.62))
	draw_rect(Rect2(-2, -14, 4, 4), Color(0.93, 0.76, 0.62))
	if _state == State.TO_HOME:
		draw_rect(Rect2(-3, -19, 6, 4), CARRY_COLORS[resource_type])


## Moves towards x and returns true once there.
func _walk_to(x: float, delta: float) -> bool:
	position.x = move_toward(position.x, x, speed * delta)
	return is_equal_approx(position.x, x)
