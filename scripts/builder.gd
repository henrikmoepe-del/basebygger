extends "res://scripts/worker.gd"
## A peasant who builds. Nothing appears out of thin air: every piece of a
## job (a block of stone, a bundle of scaffold poles, a window) is handled by
## a builder at each step:
##   1. carried from the stockhouse to the yard at the foot of the site
##   2. shaped at the bench there (stone is dressed, fittings are put together)
##   3. pulled up to the top by the rope
##   4. picked up at the top, carried to its place and set in
## Scaffolding, ladders, benches and the hoist are pieces like any other, and
## when the part stands they are taken down again and carried back.
## Long and heavy things (a ladder, a bench, the hoist) take two to carry
## from the stockyard: the one who picks it up waits for a helper, and they
## walk it over together. A builder with nobody to help drags it, slowly.
## Builders share the steps out: each takes whatever is waiting, and a lone
## builder does them all in turn. GameState counts how far each piece has
## got; castle.gd says where to stand.

enum State { IDLE, TO_STOCK, TO_YARD, FORM, HOIST, TO_PIECE, PLACE, RETURN, HELP }

## Seconds to shape one piece at the bench, pull one up the rope, and set one in place.
const FORM_TIME := 2.5
const HOIST_TIME := 1.2
const PLACE_TIME := 1.5
## Builders go up to work at the top once this many pieces are waiting there
## for each builder already up, so nobody climbs the ladder for one block.
const BATCH := 4
## Builders waiting for work stay within this distance of the yard.
const LEISURE_REACH := 70.0
## How long a builder with a heavy load waits for a helper before dragging it alone.
const HELP_WAIT := 15.0
## The helper walks this far behind, carrying the other end.
const HELP_GAP := 15.0
const DRAG_SPEED := 0.5
const SKIN := Color(0.93, 0.76, 0.62)
const TOOL := Color(0.30, 0.30, 0.34)

var _state := State.IDLE
## How many pieces are being carried from the stockhouse, and their colour.
var _carrying := 0
var _carry_color := Color.WHITE
var _carry_item := ""
## True if the load takes two; the builder helping to carry it; and, for a
## helper, the builder being helped.
var _heavy := false
var _helper: Node2D
var _lead: Node2D
var _help_wait := 0.0
## The piece being carried to its place (its number in the plan), or -1.
var _piece := -1
var _offset := randf_range(-14.0, 14.0)
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
		# No job: bring back anything carried, then the day is their own.
		_piece = -1
		_state = State.IDLE
		if _carrying == 0:
			_relax(delta)
		elif _walk_to(world.store_x("wood") + _offset, delta):
			_carrying = 0
		return

	var castle: Node2D = world.castle
	var before := _state
	match _state:
		State.IDLE:
			_state = _choose_task()
			if _state == State.IDLE:
				# Nothing to do yet: pass the time near the yard, where the next work will be.
				_relax(delta, castle.yard_x(), LEISURE_REACH)
		State.TO_STOCK:
			# Stone from the stone stack, timber from the wood stack, the rest from the shed.
			if _walk_to(world.store_x(castle.item_store(GameState.job_claimed)) + _offset, delta):
				var next: int = GameState.job_claimed
				_carry_color = castle.item_color(next)
				_carry_item = castle.item_name(next)
				_heavy = castle.is_heavy(next)
				_helper = null
				_help_wait = 0.0
				_carrying = GameState.job_take_load(castle.light_run(next, int(GameState.builder_load() * _skill())))
				_state = State.TO_YARD if _carrying > 0 else State.IDLE
		State.TO_YARD:
			if _heavy and not _has_helper() and GameState.jobs.build > 1 and _help_wait < HELP_WAIT:
				# Too much for one: wait for a second pair of hands.
				_help_wait += delta
			elif _has_helper() and absf(_helper.position.x - position.x) > HELP_GAP + 8.0:
				# Wait for the helper to take the other end.
				pass
			elif _walk_to(castle.yard_x() + _offset, delta):
				GameState.job_deliver(_carrying)
				_carrying = 0
				_heavy = false
				_helper = null
				_state = State.IDLE
		State.HELP:
			if not is_instance_valid(_lead) or _lead._helper != self:
				_state = State.IDLE
			else:
				_walk_to(_lead.position.x + HELP_GAP, delta)
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
				if castle.is_dismantle(_piece):
					# Knocked loose: it falls to the ground.
					castle.drop(_piece)
				var taken_down: bool = castle.is_removal(_piece)
				_carry_color = castle.item_color(_piece)
				_carry_item = castle.item_name(_piece)
				_heavy = false
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


## True if this builder is standing with a heavy load, waiting for a helper.
func wants_help() -> bool:
	return _state == State.TO_YARD and _heavy and not _has_helper()


## Another builder comes to carry the other end.
func join(helper: Node2D) -> void:
	_helper = helper


func _has_helper() -> bool:
	return is_instance_valid(_helper) and _helper._lead == self and _helper._state == State.HELP


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
	var picking: int = world.builders_picking(self)
	var can_place: bool = GameState.job_landed() > picking
	if can_place and world.castle.needs_turn(GameState.job_taken):
		can_place = picking == 0 and GameState.job_taken == GameState.job_placed
	if can_place and world.castle.is_removal(GameState.job_taken):
		# Nothing is taken down while anyone else is still up there.
		can_place = world.builders_above(self) == 0
	var place_above: bool = can_place and pieces[GameState.job_taken].lift
	var can_hoist: bool = GameState.job_ready() > 0 and world.castle.hoist_ready() and not world.hoist_manned(self)
	var forming: int = world.builders_forming(self)
	var can_form: bool = GameState.job_rough() > forming and forming < world.castle.benches_ready()
	_bench = forming
	var to_fetch: bool = GameState.job_can_fetch()
	if position.y > -0.5:
		# Someone is standing with a load too heavy for one: lend a hand first.
		var lead: Node2D = world.heavy_carrier(self)
		if lead != null:
			_lead = lead
			lead.join(self)
			return State.HELP
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


## What is being carried, on the shoulder: each kind of thing has its own
## shape. A heavy load with a helper reaches from one builder to the other.
func _draw_item(item: String, color: Color) -> void:
	if _heavy and _has_helper():
		var gap: float = _helper.position.x - position.x
		draw_rect(Rect2(minf(gap, 0.0) - 2.0, -20, absf(gap) + 4.0, 2), color)
		if item == "ladder":
			draw_rect(Rect2(minf(gap, 0.0) - 2.0, -17, absf(gap) + 4.0, 1), color)
		return
	match item:
		"plank":
			draw_rect(Rect2(-8, -19, 16, 2), color)
		"poles":
			draw_rect(Rect2(-10, -20, 20, 1), color)
			draw_rect(Rect2(-9, -18, 20, 1), color.darkened(0.15))
		"ladder":
			draw_rect(Rect2(-11, -21, 22, 1), color)
			draw_rect(Rect2(-11, -18, 22, 1), color)
			for rung in 5:
				draw_rect(Rect2(-9 + rung * 4, -20, 1, 2), color.lightened(0.15))
		"hoist":
			draw_rect(Rect2(-10, -20, 20, 2), color)
			draw_rect(Rect2(6, -18, 3, 3), Color(0.75, 0.68, 0.50))
		"bench":
			draw_rect(Rect2(-6, -21, 12, 2), color)
			draw_rect(Rect2(-5, -19, 2, 3), color)
			draw_rect(Rect2(3, -19, 2, 3), color)
		"thatch":
			draw_rect(Rect2(-4, -22, 8, 6), color)
			draw_rect(Rect2(-5, -20, 10, 2), color.darkened(0.15))
		"tile":
			draw_rect(Rect2(-3, -21, 6, 2), color)
			draw_rect(Rect2(-3, -18, 6, 2), color.darkened(0.12))
		"daub":
			# A bucket in the hand.
			draw_rect(Rect2(3, -9, 5, 4), Color(0.40, 0.27, 0.17))
			draw_rect(Rect2(4, -10, 3, 1), color)
		"fitting":
			draw_rect(Rect2(-3, -22, 7, 7), color.lightened(0.2))
			draw_rect(Rect2(-2, -21, 5, 5), color)
		_:
			draw_rect(Rect2(-4, -20, 8, 5), color)


func _pace() -> float:
	var dragging := _state == State.TO_YARD and _heavy and not _has_helper()
	return GameState.builder_speed_mult() * (DRAG_SPEED if dragging else 1.0)


func _bob() -> float:
	if _hammering:
		return -absf(sin(_swing)) * 2.0
	return absf(sin(_swing * 0.5)) * 2.0 if _pulling else 0.0


func _draw_extra(bob_y: float) -> void:
	if _carrying > 0:
		_draw_item(_carry_item, _carry_color)
	elif _piece >= 0 and not _hammering and not world.castle.is_dismantle(_piece) and not world.castle.is_removal(_piece):
		_draw_item(world.castle.item_name(_piece), world.castle.item_color(_piece))
	elif _hammering:
		# Hammer swings forward and back.
		var reach := 4.0 + absf(sin(_swing)) * 3.0
		draw_rect(Rect2(reach, bob_y - 12, 4, 3), TOOL)
		draw_rect(Rect2(3, bob_y - 10, reach - 2, 1), Color(0.48, 0.32, 0.20))
	elif _pulling:
		# Arms out over the edge, hauling on the rope.
		draw_rect(Rect2(3, bob_y - 9, 5, 2), SKIN)
