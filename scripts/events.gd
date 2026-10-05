extends Node2D
## Shows the events going on (GameState.events, see event_data.gd) in the
## world, and lets the player click the ones that can be clicked away.
## Placeholder shapes until we have real art.
##
## The badger digs at the wilds while it is there. Pointing at it shows a
## hand; a click chases it off. Either way it scuttles away to the east.
## The trader's cart waits east of the stockyard with its offer written over
## it; a click trades. A fire burns in the stockyard until it is clicked out.
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
const CART := Color(0.55, 0.38, 0.22)
const CART_DARK := Color(0.34, 0.22, 0.13)
const CLOTH := Color(0.80, 0.30, 0.25)
const HORSE := Color(0.48, 0.34, 0.24)
const TRADER := Color(0.30, 0.45, 0.62)
const SKIN := Color(0.93, 0.76, 0.62)
const FLAME := Color(0.98, 0.55, 0.15)
const FLAME_HOT := Color(1.0, 0.85, 0.35)
const SMOKE := Color(0.35, 0.33, 0.32)
const STEAM := Color(0.92, 0.94, 0.96)
const TAG_BACK := Color(0.16, 0.11, 0.08, 0.8)
const TAG_TEXT := Color(0.96, 0.91, 0.78)
## Where each kind of event can be clicked, around the place it happens.
const HIT_BOXES := {
	"badger": Rect2(-14, -14, 28, 16),
	"trader": Rect2(-26, -26, 52, 28),
	"fire": Rect2(-20, -30, 40, 32),
}

var _font: Font = ThemeDB.fallback_font

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
	_dig_time += delta
	if _dig_time >= DIG_TIME:
		_dig_time = 0.0
		# Dirt flies as the badger digs; sparks fly from a fire.
		if GameState.events.has("badger"):
			get_tree().call_group("effects", "burst", to_global(Vector2(_home_x("badger") - 10.0, -2.0)), DIRT, 3)
		if GameState.events.has("fire"):
			get_tree().call_group("effects", "burst", to_global(Vector2(_home_x("fire") + randf_range(-10, 10), -18.0)), FLAME_HOT, 2)
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
		get_viewport().set_input_as_handled()
		if GameState.click_event(id):
			get_tree().call_group("effects", "burst", to_global(Vector2(_home_x(id), -6.0)), STEAM if id == "fire" else DIRT, 10)
			get_tree().call_group("sfx", "play", "buy")


## Something that ended starts to leave; a clicked badger runs.
func _on_events_changed() -> void:
	for id: String in EventData.EVENTS:
		var shown := _leaving.any(func(gone: Dictionary) -> bool: return gone.id == id)
		if not GameState.events.has(id) and not shown and _was_here.has(id) and id in ["badger", "trader"]:
			var speed := BADGER_FLEE_SPEED if _hovered == id else BADGER_WANDER_SPEED
			_leaving.append({"id": id, "x": _home_x(id), "speed": speed, "age": 0.0})
	_was_here = GameState.events.duplicate()
	_set_hovered("")
	queue_redraw()


func _draw() -> void:
	for id: String in GameState.events:
		match id:
			"badger":
				_draw_badger(_home_x(id), true, id == _hovered)
			"trader":
				_draw_cart(_home_x(id), true, id == _hovered)
			"fire":
				_draw_fire(_home_x(id), id == _hovered)
	for gone in _leaving:
		if gone.id == "badger":
			_draw_badger(gone.x, false, false)
		elif gone.id == "trader":
			_draw_cart(gone.x, false, false)


## The trader's cart: a horse in front, a covered cart with goods, and the
## trader beside it. Waiting, the offer is written over it.
func _draw_cart(x: float, waiting: bool, lit: bool) -> void:
	if lit:
		draw_rect(Rect2(x - 26, -26, 52, 28), Color(1.0, 0.85, 0.40, 0.3))
	var step := int(_time * 8.0) % 2 if not waiting else 0
	# The horse, facing east.
	draw_rect(Rect2(x + 10, -12, 12, 6), HORSE)
	draw_rect(Rect2(x + 20, -16, 4, 6), HORSE)
	draw_rect(Rect2(x + 23, -15, 3, 3), HORSE.darkened(0.2))
	for leg: float in [11.0, 14.0, 17.0, 20.0]:
		draw_rect(Rect2(x + leg, -6 - (1 if step == int(leg) % 2 else 0), 1, 6), HORSE.darkened(0.25))
	# The cart: wheels, bed, a cloth over the goods, and crates.
	draw_rect(Rect2(x - 18, -9, 28, 3), CART)
	draw_rect(Rect2(x - 16, -19, 22, 10), CLOTH)
	draw_rect(Rect2(x - 17, -20, 24, 2), CLOTH.darkened(0.2))
	draw_rect(Rect2(x - 14, -6, 6, 6), CART_DARK)
	draw_rect(Rect2(x - 1, -6, 6, 6), CART_DARK)
	draw_rect(Rect2(x + 9, -9, 3, 1), CART_DARK)
	# The trader, standing at the back of the cart.
	draw_rect(Rect2(x - 24, -12, 5, 10), TRADER)
	draw_rect(Rect2(x - 23, -16, 4, 4), SKIN)
	draw_rect(Rect2(x - 24, -18, 6, 2), CART_DARK)
	draw_rect(Rect2(x - 23, -2, 1, 2), CART_DARK)
	draw_rect(Rect2(x - 21, -2, 1, 2), CART_DARK)
	if waiting:
		var offer := GameState.event_offer("trader")
		if not offer.is_empty():
			_draw_tag(Vector2(x, -30), "%s  ->  %s" % [GameState.amounts_text(offer.give), GameState.amounts_text(offer.get)])


## Flames and smoke among the stores. Lit when pointed at.
func _draw_fire(x: float, lit: bool) -> void:
	if lit:
		draw_rect(Rect2(x - 20, -30, 40, 32), Color(0.6, 0.85, 1.0, 0.25))
	for i in 5:
		var flicker := sin(_time * 9.0 + i * 1.7) * 3.0
		var tall := 10.0 + (i % 3) * 5.0 + flicker
		draw_rect(Rect2(x - 14 + i * 6, -tall, 5, tall), FLAME)
		draw_rect(Rect2(x - 13 + i * 6, -tall * 0.6, 3, tall * 0.6), FLAME_HOT)
	# Smoke rises and drifts east.
	for i in 4:
		var rise := fmod(_time * 12.0 + i * 9.0, 36.0)
		var size := 4.0 + rise * 0.25
		draw_rect(Rect2(x - 6 + i * 3 + rise * 0.4, -22 - rise, size, size), Color(SMOKE, 0.7 - rise / 60.0))


## A line of text on a dark band, centred over a point.
func _draw_tag(at: Vector2, text: String) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_rect(Rect2(at.x - width / 2.0 - 2, at.y - 8, width + 4, 10), TAG_BACK)
	draw_string(_font, Vector2(at.x - width / 2.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TAG_TEXT)


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


## Where an event happens: at its "site_x", or beside its gathering site.
func _home_x(id: String) -> float:
	var info: Dictionary = EventData.EVENTS[id]
	if info.has("site_x"):
		return info.site_x
	var site: Node2D = get_parent().get_node_or_null(info.get("site", ""))
	return (site.position.x if site != null else 0.0) + BADGER_OFFSET


## The clickable event under a point, or "".
func _event_at(point: Vector2) -> String:
	for id: String in GameState.events:
		var box: Rect2 = HIT_BOXES.get(id, HIT_BOXES.badger)
		if EventData.EVENTS[id].get("click", false) and Rect2(box.position + Vector2(_home_x(id), 0), box.size).has_point(point):
			return id
	return ""


func _set_hovered(id: String) -> void:
	if id == _hovered:
		return
	_hovered = id
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)
	queue_redraw()
