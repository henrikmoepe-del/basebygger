extends "res://scripts/worker.gd"
## A peasant who builds. Materials are carried from the stockhouse to the foot
## of the site, pulled up to the top by rope, and put in place up there piece
## by piece (castle.gd decides which piece is next and where to stand for it). Builders share the work out: some carry, one pulls the rope, and
## the rest lay stone. A lone builder does each in turn.
## Parts without a scaffold are built from the ground, with no rope.

enum State { IDLE, TO_STOCK, TO_FOOT, HOIST, HAMMER }

## Seconds to pull one load up the rope.
const HOIST_TIME := 1.2
## The rope lifts this many builder's loads at once.
const HOIST_LOADS := 2
## A lone builder carries this many loads to the site before climbing up.
const SOLO_PILE_LOADS := 3
## A builder this close to the piece being placed can work on it from where they stand.
const WORK_REACH := 40.0
## Following the work along the top is quicker than walking with a load.
const SHUFFLE_SPEED := 2.0

var _state := State.IDLE
var _carrying := 0
var _offset := randf_range(-8.0, 8.0)
## Where along the top this builder works, from 0 to 1.
var _along := randf()
var _swing := randf() * TAU
var _hammering := false
var _pulling := false
var _pull_time := 0.0


func _work(delta: float) -> void:
	_hammering = false
	_pulling = false
	_hurry = 1.0
	if GameState.job_part == "":
		# No job: put down anything carried and wait by the castle.
		_carrying = 0
		_state = State.IDLE
		_walk_to(home_x, delta)
		return

	var castle: Node2D = world.castle
	match _state:
		State.IDLE:
			_state = _choose_task()
		State.TO_STOCK:
			if _walk_to(world.stock_x + _offset, delta):
				_carrying = GameState.job_take_load(int(GameState.builder_load() * _skill()))
				_state = State.TO_FOOT if _carrying > 0 else State.IDLE
		State.TO_FOOT:
			if _walk_to(castle.hoist_x() + 10.0 + _offset, delta):
				GameState.job_deliver(_carrying)
				_carrying = 0
				_state = State.IDLE
		State.HOIST:
			if GameState.job_waiting() <= 0:
				_state = State.IDLE
			elif _go_to(castle.hoist_spot(), delta):
				# Hand over hand: the load is at the top when the pull is done.
				_pulling = true
				if _pull_time <= 0.0:
					castle.show_hoist()
				_pull_time += delta
				_swing += delta * 10.0
				if _pull_time >= HOIST_TIME:
					_pull_time = 0.0
					GameState.job_lift(int(GameState.builder_load() * _skill()) * HOIST_LOADS)
					_state = State.IDLE
		State.HAMMER:
			var spot: Vector2 = castle.work_spot(_along)
			var level := absf(position.y - spot.y) < 0.5
			if absf(position.y - spot.y) <= castle.FLOOR_SNAP:
				_hurry = SHUFFLE_SPEED
			if (level and absf(position.x - spot.x) <= WORK_REACH) or _go_to(spot, delta):
				if GameState.job_can_hammer():
					_hammering = true
					# One clink each time the hammer comes down.
					if int((_swing + delta * 10.0) / PI) != int(_swing / PI):
						get_tree().call_group("sfx", "play", "hammer")
					_swing += delta * 10.0
					GameState.job_add_work(GameState.hammer_rate() * _skill() * delta)
				else:
					_state = State.IDLE
	if _state != State.HOIST:
		_pull_time = 0.0


func _exit_tree() -> void:
	# Reassigned while carrying: the load goes back to the stockhouse.
	if _carrying > 0 and GameState.job_part != "":
		GameState.job_return_load(_carrying)


## True while this builder is one of those working at the top.
func is_top_crew() -> bool:
	return _state == State.HOIST or _state == State.HAMMER


func is_hoisting() -> bool:
	return _state == State.HOIST


func is_carrying() -> bool:
	return _state == State.TO_STOCK or _state == State.TO_FOOT


func _choose_task() -> State:
	var to_fetch := GameState.job_claimed < GameState.job_units
	if not world.castle.job_has_scaffold():
		# Built from the ground: hammer in what has arrived, else fetch more.
		if GameState.job_can_hammer() or not to_fetch:
			return State.HAMMER
		return State.TO_STOCK
	if position.y < -0.5:
		# Up on the scaffold already: do what there is to do up here.
		if _can_hoist():
			return State.HOIST
		if GameState.job_can_hammer():
			return State.HAMMER
		# Nothing to lay: go for more, unless someone else is carrying.
		if to_fetch and world.builders_carrying(self) == 0:
			return State.TO_STOCK
		return State.HAMMER
	# On the ground: carry, unless more hands are needed at the top.
	var work_above := GameState.job_can_hammer() or GameState.job_waiting() > 0
	if to_fetch and not (work_above and world.builders_aloft(self) < _crew_wanted()):
		return State.TO_STOCK
	return State.HOIST if _can_hoist() else State.HAMMER


## True if there is a load to pull up and nobody else is at the rope.
func _can_hoist() -> bool:
	return GameState.job_waiting() > 0 and not world.hoist_manned(self)


## How many builders should be working at the top while there is still
## carrying to do: half of them, or a lone builder once a pile has built up.
func _crew_wanted() -> int:
	var builders: int = GameState.jobs.build
	if builders <= 1:
		return 1 if GameState.job_waiting() >= GameState.builder_load() * SOLO_PILE_LOADS else 0
	return builders / 2


func _pace() -> float:
	return GameState.builder_speed_mult()


func _bob() -> float:
	if _hammering:
		return -absf(sin(_swing)) * 2.0
	return absf(sin(_swing * 0.5)) * 2.0 if _pulling else 0.0


func _draw_extra(bob_y: float) -> void:
	if _carrying > 0:
		draw_rect(Rect2(-4, -20, 8, 5), Color(0.62, 0.62, 0.66))
	elif _hammering:
		# Hammer swings forward and back.
		var reach := 4.0 + absf(sin(_swing)) * 3.0
		draw_rect(Rect2(reach, bob_y - 12, 4, 3), Color(0.30, 0.30, 0.34))
		draw_rect(Rect2(3, bob_y - 10, reach - 2, 1), Color(0.48, 0.32, 0.20))
	elif _pulling:
		# Arms out over the edge, hauling on the rope.
		draw_rect(Rect2(3, bob_y - 9, 5, 2), Color(0.93, 0.76, 0.62))
