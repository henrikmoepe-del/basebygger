extends Node2D
## Lets the player build by pointing at the world. Hovering over a castle
## part or village building (or the spot where one can go) outlines it and
## tells the HUD, which shows a card with its cost, benefit and drawback.
## A click orders it. Spots with nothing built yet show a small "+" sign.
##
## This node sits at the castle's ground-centre point, so the shapes in
## CastleData line up with it.

signal hovered_changed(part: String)

const CastleData = preload("res://scripts/castle_data.gd")
const OUTLINE := Color(1.0, 0.95, 0.60)
const SIGN := Color(0.96, 0.95, 0.85)
const SIGN_POST := Color(0.48, 0.32, 0.20)
## Moving the mouse further than this between press and release is a drag
## (which pans the camera), not a click.
const CLICK_SLOP := 4.0
const MIN_OUTLINED_AREA := 300.0

## The part under the mouse, or "".
var hovered := ""
var _press_position := Vector2.ZERO


func _ready() -> void:
	GameState.castle_changed.connect(queue_redraw)
	GameState.resources_changed.connect(queue_redraw)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(_part_at(make_input_local(event).position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
		elif hovered != "" and event.position.distance_to(_press_position) <= CLICK_SLOP:
			GameState.order_part(hovered)


func _draw() -> void:
	for part: String in CastleData.PARTS:
		# A signpost marks every empty spot that could be built on right now.
		if GameState.part_levels[part] == 0 and GameState.part_block_reason(part) == "":
			# The sign stands where the builders would work.
			var foot := Vector2(CastleData.PARTS[part].site_x, 0)
			draw_rect(Rect2(foot.x, -12, 1, 12), SIGN_POST)
			draw_rect(Rect2(foot.x - 4, -16, 9, 7), SIGN if GameState.can_afford(GameState.part_cost(part)) else SIGN.darkened(0.35))
			draw_rect(Rect2(foot.x - 2, -13, 5, 1), SIGN_POST)
			draw_rect(Rect2(foot.x, -15, 1, 5), SIGN_POST)
	if hovered != "":
		for area in zones(hovered):
			# Outline the main bodies only, not every window and battlement.
			if area.get_area() >= MIN_OUTLINED_AREA:
				draw_rect(area, OUTLINE, false, 1.0)


## The areas a part takes up, including the room its next level needs.
## (A part can be in several pieces: the two towers, the row of houses.)
func zones(part: String) -> Array[Rect2]:
	var level: int = GameState.part_levels[part]
	var areas: Array[Rect2] = []
	for shape: Array in CastleData.shapes(part, level + 1):
		areas.append(shape[0].grow(3))
	return areas


## The part at a point, checking the ones drawn in front first.
func _part_at(point: Vector2) -> String:
	for i in range(CastleData.DRAW_ORDER.size() - 1, -1, -1):
		var part: String = CastleData.DRAW_ORDER[i]
		for area in zones(part):
			if area.has_point(point):
				return part
	return ""


func _set_hovered(part: String) -> void:
	if part == hovered:
		return
	hovered = part
	hovered_changed.emit(part)
	queue_redraw()
