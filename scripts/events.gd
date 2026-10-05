extends Node2D
## Shows the events going on (GameState.events, see event_data.gd) in the
## world, and lets the player click the ones that can be clicked away.
## Placeholder shapes until we have real art.
##
## The badger digs at the wilds while it is there. Pointing at it shows a
## hand; a click chases it off. Either way it scuttles away to the east.
##
## This node sits at the ground, like the castle, so x is the world x.

const EventData = preload("res://scripts/event_data.gd")
## Moving the mouse further than this between press and release is a drag
## (which pans the camera), not a click.
const CLICK_SLOP := 4.0
## How far from a gathering site's centre the badger digs.
const BADGER_OFFSET := 34.0
const BADGER_FLEE_SPEED := 90.0
const BADGER_WANDER_SPEED := 25.0
const BADGER_GONE := 260.0
const DIG_TIME := 0.45
const FUR := Color(0.42, 0.42, 0.45)
const FUR_DARK := Color(0.22, 0.22, 0.24)
const FACE := Color(0.92, 0.91, 0.86)
const DIRT := Color(0.42, 0.30, 0.18)

## Events leaving the world: {"id", "x", "speed", "age"}.
var _leaving: Array[Dictionary] = []
var _hovered := ""
## The events going on the last time this node looked.
var _was_here := {}
var _press_position := Vector2.ZERO
var _time := 0.0
var _dig_time := 0.0


func _ready() -> void:
	# In front of the bushes and the peasants gathering there.
	z_index = 3
	add_to_group("events")
	_was_here = GameState.events.duplicate()
	GameState.events_changed.connect(_on_events_changed)


func _process(delta: float) -> void:
	_time += delta
	for gone in _leaving:
		gone.x += gone.speed * delta
		gone.age += delta
	_leaving = _leaving.filter(func(gone: Dictionary) -> bool: return gone.x < _home_x(gone.id) + BADGER_GONE)
	if GameState.events.has("badger"):
		# Dirt flies as it digs.
		_dig_time += delta
		if _dig_time >= DIG_TIME:
			_dig_time = 0.0
			get_tree().call_group("effects", "burst", to_global(Vector2(_home_x("badger") - 10.0, -2.0)), DIRT, 3)
	_set_hovered(_event_at(get_local_mouse_position()))
	if not GameState.events.is_empty() or not _leaving.is_empty():
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_position = event.position
	elif _hovered != "" and event.position.distance_to(_press_position) <= CLICK_SLOP:
		var id := _hovered
		get_tree().call_group("effects", "burst", to_global(Vector2(_home_x(id), -6.0)), DIRT, 10)
		get_tree().call_group("sfx", "play", "buy")
		GameState.end_event(id, "clicked")
		get_viewport().set_input_as_handled()


## Something that ended starts to leave; a clicked badger runs.
func _on_events_changed() -> void:
	for id: String in EventData.EVENTS:
		var shown := _leaving.any(func(gone: Dictionary) -> bool: return gone.id == id)
		if not GameState.events.has(id) and not shown and _was_here.has(id):
			var speed := BADGER_FLEE_SPEED if _hovered == id else BADGER_WANDER_SPEED
			_leaving.append({"id": id, "x": _home_x(id), "speed": speed, "age": 0.0})
	_was_here = GameState.events.duplicate()
	_set_hovered("")
	queue_redraw()


func _draw() -> void:
	for id: String in GameState.events:
		if id == "badger":
			_draw_badger(_home_x(id), true, id == _hovered)
	for gone in _leaving:
		if gone.id == "badger":
			_draw_badger(gone.x, false, false)


## A badger, snout to the west. Digging, its head dips in and out of the
## ground; running, its legs scuttle and it faces east.
func _draw_badger(x: float, digging: bool, lit: bool) -> void:
	var face := -1.0 if digging else 1.0
	var step := int(_time * (6.0 if digging else 14.0)) % 2
	if lit:
		draw_rect(Rect2(x - 11, -10, 22, 10), Color(1.0, 0.85, 0.40, 0.35))
	# Legs.
	for leg: float in [-5.0, -1.0, 2.0, 6.0]:
		var lift := 1.0 if (not digging and step == int(leg + 5.0) % 2) else 0.0
		draw_rect(Rect2(x + leg * face - 1.0, -2.0 - lift, 2, 2), FUR_DARK)
	# Body, darker along the back, and a stub of a tail.
	draw_rect(Rect2(x - 7, -7, 14, 5), FUR)
	draw_rect(Rect2(x - 6, -8, 12, 2), FUR_DARK)
	draw_rect(Rect2(x - (9.0 if face > 0 else -7.0), -7, 2, 2), FUR)
	# The head: white with a dark stripe, lower while digging.
	var dip := 2.0 if digging and step == 0 else 0.0
	var head_x := x + 7.0 * face - (5.0 if face < 0 else 0.0)
	draw_rect(Rect2(head_x, -7 + dip, 5, 4), FACE)
	draw_rect(Rect2(head_x + (1.0 if face < 0 else 1.0), -6 + dip, 3, 1), FUR_DARK)
	draw_rect(Rect2(head_x + (-1.0 if face < 0 else 5.0), -4 + dip, 1, 1), FUR_DARK)
	if digging:
		# A little heap of earth in front of it.
		draw_rect(Rect2(x - 15, -2, 5, 2), DIRT)


## Where an event happens: beside its gathering site.
func _home_x(id: String) -> float:
	var site: Node2D = get_parent().get_node_or_null(EventData.EVENTS[id].get("site", ""))
	return (site.position.x if site != null else 0.0) + BADGER_OFFSET


## The clickable event under a point, or "".
func _event_at(point: Vector2) -> String:
	for id: String in GameState.events:
		if EventData.EVENTS[id].get("click", false) and Rect2(_home_x(id) - 14.0, -14.0, 28.0, 16.0).has_point(point):
			return id
	return ""


func _set_hovered(id: String) -> void:
	if id == _hovered:
		return
	_hovered = id
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)
	queue_redraw()
