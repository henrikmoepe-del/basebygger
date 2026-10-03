extends Node2D
## A spot that gives a resource, to the player on click and to peasants.
## Used as-is for the rock (never runs out); tree.gd extends it.
## Drawn with placeholder shapes until we have real art.

@export var resource_type := "stone"
@export var size := Vector2(40, 26)


## True if there is something to gather here right now.
func can_gather() -> bool:
	return true


## Removes one unit from the spot. Returns false if there was nothing to take.
func take() -> bool:
	return true


func _draw() -> void:
	var r := _rect()
	draw_rect(r, Color(0.55, 0.57, 0.62))
	draw_rect(Rect2(r.position, Vector2(size.x, 6)), Color(0.72, 0.74, 0.78))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _rect().has_point(make_input_local(event).position) and take():
			GameState.add_resource(resource_type, 1)
			_pop()
			get_viewport().set_input_as_handled()


func _rect() -> Rect2:
	# Anchored at bottom-centre so the spot stands on the ground.
	return Rect2(-size.x / 2, -size.y, size.x, size.y)


func _pop() -> void:
	# Quick squash-and-return so a click feels like it did something.
	scale = Vector2(1.15, 0.9)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.12)
