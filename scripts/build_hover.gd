extends Node2D
## Build mode. Pressing B (or the Build button) turns it on and off. While it
## is on, a small circle marks every castle part and village building that
## can be built or raised. Pointing at a circle tells the HUD, which shows a
## round preview of the part with its cost, benefit and drawback; a click
## orders it. Outside build mode nothing in the world can be ordered.
## A new storey of the keep is not ordered at once: the HUD first asks which
## rooms to build there (rooms_wanted).
## Outside build mode, clicking a standing building that has boosts (see
## boost_data.gd) asks the HUD to show them (boosts_wanted).
##
## This node sits at the castle's ground-centre point, so the positions in
## CastleData line up with it.

signal hovered_changed(part: String)
signal mode_changed
## The player clicked a part whose new rooms they must choose first.
signal rooms_wanted(part: String)
## The player clicked a building that has boosts, outside build mode.
signal boosts_wanted(part: String)

const CastleData = preload("res://scripts/castle_data.gd")
const BoostData = preload("res://scripts/boost_data.gd")
const CAN_BUILD := Color(1.0, 0.85, 0.40)
const CANT_AFFORD := Color(0.75, 0.62, 0.40)
const BLOCKED := Color(0.55, 0.55, 0.55)
const SPOT_FILL := Color(0.16, 0.11, 0.08, 0.85)
## Moving the mouse further than this between press and release is a drag
## (which pans the camera), not a click.
const CLICK_SLOP := 4.0
## Circles are drawn over the castle and the peasants on it.
const OVERLAY_Z := 4
## The size of a circle on screen, whatever the zoom, and how much it grows
## when pointed at.
const SPOT_RADIUS := 6.0
const HOVER_GROW := 1.5
## How high above the ground the circles float.
const SPOT_HEIGHT := 18.0

## True while build mode is on.
var active := false
## The part whose circle is under the mouse, or "".
var hovered := ""
var _press_position := Vector2.ZERO
## The building with boosts under the mouse outside build mode, or "".
var _boost_hovered := ""
var _zoom := 1.0


func _ready() -> void:
	z_index = OVERLAY_Z
	GameState.castle_changed.connect(queue_redraw)
	GameState.resources_changed.connect(queue_redraw)


func set_active(on: bool) -> void:
	active = on
	_set_hovered("")
	mode_changed.emit()
	queue_redraw()


func _process(_delta: float) -> void:
	# The circles keep their size on screen, so they are redrawn when the zoom changes.
	var camera := get_viewport().get_camera_2d()
	if active and camera != null and camera.zoom.x != _zoom:
		_zoom = camera.zoom.x
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_B:
		set_active(not active)
	elif event.keycode == KEY_ESCAPE and active:
		set_active(false)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		_boost_input(event)
		return
	if event is InputEventMouseMotion:
		_set_hovered(_part_at(make_input_local(event).position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
		elif hovered != "" and event.position.distance_to(_press_position) <= CLICK_SLOP:
			if GameState.needs_room_choice(hovered) and GameState.part_block_reason(hovered) == "" \
					and GameState.can_afford(GameState.part_cost(hovered)):
				rooms_wanted.emit(hovered)
			else:
				GameState.order_part(hovered)


func _draw() -> void:
	if not active:
		return
	for part: String in CastleData.PARTS:
		if not _has_spot(part):
			continue
		var radius := SPOT_RADIUS / _zoom * (HOVER_GROW if part == hovered else 1.0)
		var color := BLOCKED
		if GameState.part_block_reason(part) == "":
			color = CAN_BUILD if GameState.can_afford(GameState.part_cost(part)) else CANT_AFFORD
		var centre := spot(part)
		draw_circle(centre, radius, SPOT_FILL)
		draw_arc(centre, radius, 0.0, TAU, 24, color, 1.5 / _zoom)
		# A plus sign in the middle.
		var arm := radius * 0.5
		draw_line(centre - Vector2(arm, 0), centre + Vector2(arm, 0), color, 1.5 / _zoom)
		draw_line(centre - Vector2(0, arm), centre + Vector2(0, arm), color, 1.5 / _zoom)


## Outside build mode: a hand over a building with boosts, and a click asks
## for its boosts.
func _boost_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var part := _boost_part_at(make_input_local(event).position)
		if part != _boost_hovered:
			_boost_hovered = part
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if part != "" else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
		elif _boost_hovered != "" and event.position.distance_to(_press_position) <= CLICK_SLOP:
			boosts_wanted.emit(_boost_hovered)
			get_viewport().set_input_as_handled()


## The smallest standing building with boosts at a point, or "".
func _boost_part_at(point: Vector2) -> String:
	var found := ""
	var smallest := INF
	var with_boosts := {}
	for boost: String in BoostData.BOOSTS:
		with_boosts[BoostData.BOOSTS[boost].building] = true
	for part: String in with_boosts:
		var level: int = GameState.part_levels[part]
		if level == 0 or part == GameState.job_part:
			continue
		var area := Rect2()
		for shape: Array in CastleData.shapes(part, level):
			area = shape[0] if area.size == Vector2.ZERO else area.merge(shape[0])
		if area.has_point(point) and area.get_area() < smallest:
			smallest = area.get_area()
			found = part
	return found


## Where a part's circle floats.
func spot(part: String) -> Vector2:
	return Vector2(CastleData.PARTS[part].site_x, -SPOT_HEIGHT)


## Parts that can never be raised again have no circle.
func _has_spot(part: String) -> bool:
	return GameState.part_block_reason(part) != "Fully built"


## The part whose circle is at a point, or "".
func _part_at(point: Vector2) -> String:
	var reach := SPOT_RADIUS * HOVER_GROW / _zoom
	var found := ""
	for part: String in CastleData.PARTS:
		var distance := spot(part).distance_to(point)
		if _has_spot(part) and distance <= reach:
			reach = distance
			found = part
	return found


func _set_hovered(part: String) -> void:
	if part == hovered:
		return
	hovered = part
	hovered_changed.emit(part)
	queue_redraw()
