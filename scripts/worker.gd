extends Node2D
## One peasant. This base script is an idle peasant who strolls about the
## castle; each job has a script that extends it (gatherer.gd, builder.gd).
## Peasants walk on the ground and on the castle's floors, and get from one
## to the other by its stairs (see castle.gd).
## Placeholder shapes until we have real art.

const JobData = preload("res://scripts/job_data.gd")
const LEGS := Color(0.30, 0.24, 0.20)
const LEG_HEIGHT := 2.0
const HOP_TIME := 0.35
## Climbing is slower than walking.
const CLIMB_SPEED := 0.6
## Peasants on the curtain wall are drawn behind the courtyard buildings
## (castle.gd draws those at z 2), everyone else in front of them.
const BACK_Z := 1
const FRONT_Z := 3

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
var _last_position := Vector2.ZERO
## The steps still to take to where the peasant is going (see castle.route).
var _route: Array = []
var _route_to := Vector2.INF
var _route_version := -1
## True while inside a building: on its stairs, or asleep.
var _inside := false
var _back := false
## The door this peasant sleeps behind tonight (NAN during the day).
var _bed_x := NAN
## Where an idle peasant is strolling to, and how long they stay there.
var _stroll := Vector2.INF
var _stroll_wait := 0.0


func _process(delta: float) -> void:
	_inside = false
	if GameState.is_night() and _sleeps():
		# Everyone goes in at the nearest door and sleeps inside until dawn.
		if is_nan(_bed_x):
			_bed_x = world.bed_x(position.x)
		if _walk_to(_bed_x, delta):
			_inside = true
	else:
		_bed_x = NAN
		_work(delta)
	visible = not _inside
	z_index = BACK_Z if _back else FRONT_Z
	_age += delta
	_walking = not position.is_equal_approx(_last_position)
	_last_position = position
	queue_redraw()


## Jobs that keep going through the night return false.
func _sleeps() -> bool:
	return true


## What the peasant does each frame. Idle peasants stroll around the castle.
func _work(delta: float) -> void:
	if _stroll == Vector2.INF:
		_stroll = Vector2(home_x, 0)
	if _go_to(_stroll, delta):
		_stroll_wait -= delta
		if _stroll_wait <= 0.0:
			_stroll_wait = randf_range(4.0, 12.0)
			_stroll = world.stroll_spot(home_x)


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


## How much faster than their own speed the peasant moves.
func _pace() -> float:
	return GameState.peasant_speed_mult()


## Moves along the ground towards x and returns true once there.
func _walk_to(x: float, delta: float) -> bool:
	return _go_to(Vector2(x, 0), delta)


## Moves towards a point on the ground or on one of the castle's floors,
## taking the stairs where needed. Returns true once there.
func _go_to(target: Vector2, delta: float) -> bool:
	if position.is_equal_approx(target):
		_route.clear()
		return true
	var castle: Node2D = world.castle
	if _route.is_empty() or _route_version != castle.version or not target.is_equal_approx(_route_to):
		_route = castle.route(position, target)
		_route_to = target
		_route_version = castle.version
	var step: Dictionary = _route[0]
	var climbing := is_equal_approx(step.pos.x, position.x)
	position = position.move_toward(step.pos, speed * _pace() * delta * (CLIMB_SPEED if climbing else 1.0))
	_inside = step.hidden
	_back = step.back
	if position.is_equal_approx(step.pos):
		_route.pop_front()
	return position.is_equal_approx(target)
