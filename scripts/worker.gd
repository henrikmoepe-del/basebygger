extends Node2D
## One peasant. This base script is an idle peasant who waits at home; each
## job has a script that extends it (gatherer.gd, builder.gd).
## Placeholder shapes until we have real art.

const JobData = preload("res://scripts/job_data.gd")
const LEGS := Color(0.30, 0.24, 0.20)
const LEG_HEIGHT := 2.0
const HOP_TIME := 0.35

## The job id from JobData.JOBS, or "" for idle.
var job := ""
## Trained peasants do their job twice as well and wear a hat.
var trained := false
var home_x := 0.0
var speed := 50.0
## The Workers node, which knows where things are in the world.
var world: Node2D

var _walking := false
## Seconds since this peasant appeared; they hop once as they arrive.
var _age := 0.0
var _last_x := 0.0


func _process(delta: float) -> void:
	if GameState.is_night() and _sleeps():
		# Everyone walks back to the stockhouse and sleeps inside until dawn.
		if _walk_to(world.stock_x, delta):
			hide()
	else:
		show()
		_work(delta)
	_age += delta
	_walking = not is_equal_approx(position.x, _last_x)
	_last_x = position.x
	queue_redraw()


## Jobs that keep going through the night return false.
func _sleeps() -> bool:
	return true


## What the peasant does each frame. Idle peasants just walk home and wait.
func _work(delta: float) -> void:
	_walk_to(home_x, delta)


func _draw() -> void:
	var tunic: Color = JobData.JOBS[job].color if job != "" else JobData.IDLE_COLOR
	var bob := _bob()
	var hop := -sin(clampf(_age / HOP_TIME, 0.0, 1.0) * PI) * 7.0
	draw_set_transform(Vector2(0, hop))
	# Legs: while walking, they take turns stepping.
	var step := int(Time.get_ticks_msec() / 140.0 + position.x) % 2 if _walking else -1
	draw_rect(Rect2(-2, -3, 2, 2 if step == 0 else 3), LEGS)
	draw_rect(Rect2(1, -3, 2, 2 if step == 1 else 3), LEGS)
	# The body sits on top of the legs.
	draw_set_transform(Vector2(0, hop - LEG_HEIGHT))
	draw_rect(Rect2(-3, bob - 10, 6, 10), tunic)
	draw_rect(Rect2(-2, bob - 14, 4, 4), Color(0.93, 0.76, 0.62))
	if trained:
		draw_rect(Rect2(-3, bob - 16, 6, 2), JobData.TRAINED_HAT)
	_draw_extra(bob)
	draw_set_transform(Vector2.ZERO)


## How far the body is lifted this frame (negative = up), for work animations.
func _bob() -> float:
	return 0.0


## Jobs draw what the peasant carries or holds here.
func _draw_extra(_bob_y: float) -> void:
	pass


## 2 for a trained peasant, 1 otherwise: how much better they do their job.
func _skill() -> float:
	return GameState.TRAINED_MULT if trained else 1.0


## Moves towards x and returns true once there.
func _walk_to(x: float, delta: float) -> bool:
	position.x = move_toward(position.x, x, speed * GameState.peasant_speed_mult() * delta)
	return is_equal_approx(position.x, x)
