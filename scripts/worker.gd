extends Node2D
## One peasant. This base script is an idle peasant who waits at home; each
## job has a script that extends it (gatherer.gd, builder.gd).
## Placeholder shapes until we have real art.

const JobData = preload("res://scripts/job_data.gd")

## The job id from JobData.JOBS, or "" for idle.
var job := ""
var home_x := 0.0
var speed := 50.0
## The Workers node, which knows where things are in the world.
var world: Node2D


func _process(delta: float) -> void:
	if GameState.is_night():
		# Everyone walks back to the stockhouse and sleeps inside until dawn.
		if _walk_to(world.stock_x, delta):
			hide()
	else:
		show()
		_work(delta)
	queue_redraw()


## What the peasant does each frame. Idle peasants just walk home and wait.
func _work(delta: float) -> void:
	_walk_to(home_x, delta)


func _draw() -> void:
	var tunic: Color = JobData.JOBS[job].color if job != "" else JobData.IDLE_COLOR
	var bob := _bob()
	draw_rect(Rect2(-3, bob - 10, 6, 10), tunic)
	draw_rect(Rect2(-2, bob - 14, 4, 4), Color(0.93, 0.76, 0.62))
	_draw_extra(bob)


## How far the body is lifted this frame (negative = up), for work animations.
func _bob() -> float:
	return 0.0


## Jobs draw what the peasant carries or holds here.
func _draw_extra(_bob_y: float) -> void:
	pass


## Moves towards x and returns true once there.
func _walk_to(x: float, delta: float) -> bool:
	position.x = move_toward(position.x, x, speed * GameState.peasant_speed_mult() * delta)
	return is_equal_approx(position.x, x)
