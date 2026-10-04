extends "res://scripts/worker.gd"
## A peasant who builds. Nothing appears out of thin air: every piece of a
## job (a block of stone, a bundle of scaffold poles, a window) is handled by
## a builder at each step:
##   1. carried from the stockhouse to the yard at the foot of the site
##   2. shaped at the bench there (stone is dressed, fittings are put together)
##   3. pulled up to the top by the rope
##   4. picked up at the top, carried to its place and set in
## Scaffolding and ladders are pieces like any other, and when the part
## stands they are taken down again and carried back to the stockhouse.
## Builders share the steps out: each takes whatever is waiting, and a lone
## builder does them all in turn. GameState counts how far each piece has
## got; castle.gd says where to stand.

enum State { IDLE, TO_STOCK, TO_YARD, FORM, HOIST, TO_PIECE, PLACE, RETURN }

## Seconds to shape one piece at the bench, pull one up the rope, and set one in place.
const FORM_TIME := 2.5
const HOIST_TIME := 1.2
const PLACE_TIME := 1.5
## Builders go up to work at the top once this many pieces are waiting there
## for each builder already up, so nobody climbs the ladder for one block.
const BATCH := 4
const SKIN := Color(0.93, 0.76, 0.62)
const TOOL := Color(0.30, 0.30, 0.34)

var _state := State.IDLE
## How many pieces are being carried from the stockhouse, and their colour.
var _carrying := 0
var _carry_color := Color.WHITE
## The piece being carried to its place (its number in the plan), or -1.
var _piece := -1
var _offset := randf_range(-6.0, 6.0)
## Which bench this builder is shaping at.
var _bench := 0
## Seconds spent on the step in hand.
var _timer := 0.0
var _swing := randf() * TAU
var _hammering := false
var _pulling := false


func _work(delta: float) -> void:
	_hammering = false
	_pulling = false
	if GameState.job_part == "":
		# No job: bring back anything carried and wait by the castle.
		_piece = -1
		_state = State.IDLE
		if _walk_to(world.stock_x + _offset if _carrying > 0 else home_x, delta):
			_carrying = 0
		return

	var castle: Node2D = world.castle
	var before := _state
	match _state:
		State.IDLE:
			_state = _choose_task()
			if _state == State.IDLE and position.y > -0.5:
				# Nothing to do yet: wait by the yard, where the next work will be.
				_walk_to(castle.yard_x() + 14.0 + _offset * 2.0, delta)
		State.TO_STOCK:
			# Stone from the stone stack, timber from the wood stack, the rest from the shed.
			if _walk_to(world.store_x(castle.item_store(GameState.job_claimed)) + _offset, delta):
				_carry_color = castle.item_color(GameState.job_claimed)
				_carrying = GameState.job_take_load(int(GameState.builder_load() * _skill()))
				_state = State.TO_YARD if _carrying > 0 else State.IDLE
		State.TO_YARD:
			if _walk_to(castle.yard_x() + _offset, delta):
				GameState.job_deliver(_carrying)
				_carrying = 0
				_state = State.IDLE
		State.FORM:
			if GameState.job_rough() <= 0:
				_state = State.IDLE
			elif _walk_to(castle.bench_x(_bench), delta) and _toil(delta, FORM_TIME, "mine"):
				GameState.job_form()
				_state = State.IDLE
		State.HOIST:
			if GameState.job_ready() <= 0:
				_state = State.IDLE
			elif _go_to(castle.hoist_spot(), delta):
				# Hand over hand: the piece is at the top when the pull is done.
				_pulling = true
				if _timer <= 0.0:
					castle.show_hoist()
				_timer += delta
				_swing += delta * 10.0
				if _timer >= HOIST_TIME:
					GameState.job_lift()
					_state = State.IDLE
		State.TO_PIECE:
			if GameState.job_landed() <= 0:
				_state = State.IDLE
			elif _go_to(castle.pickup_spot(), delta):
				_piece = GameState.job_take_piece()
				_state = State.PLACE if _piece >= 0 else State.IDLE
		State.PLACE:
			if _go_to(castle.stand_spot(_piece), delta) and _toil(delta, PLACE_TIME, "hammer"):
				# Scaffolding that was taken down is carried back to the stockhouse.
				var taken_down: bool = castle.is_removal(_piece)
				_carry_color = castle.item_color(_piece)
				_piece = -1
				GameState.job_place()
				_carrying = 1 if taken_down else 0
				_state = State.RETURN if taken_down else State.IDLE
		State.RETURN:
			if _walk_to(world.store_x("wood") + _offset, delta):
				_carrying = 0
				_state = State.IDLE
	if _state != before:
		_timer = 0.0


func _exit_tree() -> void:
	# Reassigned while carrying: what is carried goes back where it came from.
	if GameState.job_part == "":
		return
	if _carrying > 0 and _state != State.RETURN:
		GameState.job_return_load(_carrying)
	if _piece >= 0:
		GameState.job_untake()


## True while this builder is one of those working at the top.
func is_top_crew() -> bool:
	return _state == State.HOIST or _state == State.TO_PIECE or _state == State.PLACE


func is_hoisting() -> bool:
	return _state == State.HOIST


func is_forming() -> bool:
	return _state == State.FORM


func is_picking() -> bool:
	return _state == State.TO_PIECE


## Hammers away at the step in hand. Returns true when it is done.
func _toil(delta: float, seconds: float, sound: String) -> bool:
	_hammering = true
	# One clink each time the hammer comes down.
	if int((_swing + delta * 10.0) / PI) != int(_swing / PI):
		get_tree().call_group("sfx", "play", sound)
	_swing += delta * 10.0
	_timer += delta * GameState.hammer_rate() * _skill()
	return _timer >= seconds * GameState.build_time_mult()


## Picks the next step to do. A builder already at the top keeps working
## there while there is anything to do; one on the ground places what can be
## placed from the ground, goes up when enough is waiting above, and
## otherwise shapes pieces at the bench or fetches more.
func _choose_task() -> State:
	var pieces: Array = GameState.job_pieces()
	# Only as many builders set off for a step as there are pieces waiting for it.
	var can_place: bool = GameState.job_landed() > world.builders_picking(self)
	var place_above: bool = can_place and pieces[GameState.job_taken].lift
	var can_hoist: bool = GameState.job_ready() > 0 and not world.hoist_manned(self)
	var forming: int = world.builders_forming(self)
	var can_form: bool = GameState.job_rough() > forming and forming < world.castle.BENCHES
	_bench = forming
	var to_fetch := GameState.job_claimed < GameState.job_fetch()
	if position.y < -0.5:
		if can_place:
			return State.TO_PIECE
		if can_hoist:
			return State.HOIST
	if can_place and not place_above:
		return State.TO_PIECE
	# Work waiting at the top, or to go up: is it worth the climb yet?
	var above := GameState.job_ready() + (GameState.job_landed() if place_above else 0)
	var go_up := State.TO_PIECE if place_above else (State.HOIST if can_hoist else State.IDLE)
	if go_up != State.IDLE and above >= BATCH * (world.builders_aloft(self) + 1):
		return go_up
	if can_form:
		return State.FORM
	if to_fetch:
		return State.TO_STOCK
	# Nothing left to do on the ground.
	return go_up


func _pace() -> float:
	return GameState.builder_speed_mult()


func _bob() -> float:
	if _hammering:
		return -absf(sin(_swing)) * 2.0
	return absf(sin(_swing * 0.5)) * 2.0 if _pulling else 0.0


func _draw_extra(bob_y: float) -> void:
	if _carrying > 0:
		draw_rect(Rect2(-4, -20, 8, 5), _carry_color)
	elif _piece >= 0 and not _hammering:
		draw_rect(Rect2(-4, -20, 8, 5), world.castle.item_color(_piece))
	elif _hammering:
		# Hammer swings forward and back.
		var reach := 4.0 + absf(sin(_swing)) * 3.0
		draw_rect(Rect2(reach, bob_y - 12, 4, 3), TOOL)
		draw_rect(Rect2(3, bob_y - 10, reach - 2, 1), Color(0.48, 0.32, 0.20))
	elif _pulling:
		# Arms out over the edge, hauling on the rope.
		draw_rect(Rect2(3, bob_y - 9, 5, 2), SKIN)
