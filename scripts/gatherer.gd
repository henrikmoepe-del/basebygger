extends "res://scripts/worker.gd"
## A peasant who gathers: finds a spot, walks there, works, carries the
## resource back to the stockhouse, and repeats. What they gather comes
## from their job (woodcutters wood, quarrymen stone, hunters food).

enum State { IDLE, TO_WORK, WORKING, TO_HOME }

const CARRY_COLORS := {"wood": Color(0.48, 0.32, 0.20), "stone": Color(0.62, 0.62, 0.66), "food": Color(0.70, 0.25, 0.30)}
const RETRY_TIME := 0.5
const WORK_TIME := 1.0

var _state := State.IDLE
var _timer := 0.0
var _spot: Node2D
var _spot_offset := randf_range(-5.0, 5.0)
var _carrying := 0
var _resource := ""


func _work(delta: float) -> void:
	_resource = JobData.JOBS[job].get("gathers", job)
	match _state:
		State.IDLE:
			# Nothing to gather (e.g. all trees regrowing): wait and look again.
			_timer -= delta
			if _timer <= 0.0:
				_spot = world.find_spot(_resource)
				_timer = RETRY_TIME
				if _spot != null:
					_state = State.TO_WORK
		State.TO_WORK:
			if not _spot.can_gather():
				_state = State.IDLE
				_timer = 0.0
			elif _walk_to(_spot.position.x + _spot_offset, delta):
				_state = State.WORKING
				_timer = WORK_TIME * GameState.gather_time_mult() / _skill()
		State.WORKING:
			_timer -= delta
			if _timer <= 0.0:
				# Take as much as the basket holds, or whatever is left.
				while _carrying < GameState.carry_amount(job) * _skill() and _spot.take():
					_carrying += 1
				# If someone else took the last of it, look for another spot.
				_state = State.TO_HOME if _carrying > 0 else State.IDLE
				_timer = 0.0
		State.TO_HOME:
			if _walk_to(home_x, delta):
				GameState.add_income(_resource, _carrying)
				_carrying = 0
				_state = State.IDLE
				_timer = 0.0


func _bob() -> float:
	return -absf(sin(_timer * 12.0)) * 1.5 if _state == State.WORKING else 0.0


func _draw_extra(_bob_y: float) -> void:
	if _carrying > 0:
		draw_rect(Rect2(-3, -19, 6, 4), CARRY_COLORS[_resource])
