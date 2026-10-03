extends Node2D
## A clickable spot (tree, rock) that gives a resource on each click.
## Drawn with placeholder shapes until we have real art.

@export var resource_type := "wood"
@export var amount := 1
@export var size := Vector2(40, 64)


func _draw() -> void:
	var r := _rect()
	if resource_type == "wood":
		# Trunk with a canopy on top.
		draw_rect(Rect2(-5, -size.y * 0.4, 10, size.y * 0.4), Color(0.45, 0.30, 0.18))
		draw_rect(Rect2(r.position, Vector2(size.x, size.y * 0.7)), Color(0.20, 0.50, 0.30))
	else:
		draw_rect(r, Color(0.55, 0.57, 0.62))
		draw_rect(Rect2(r.position, Vector2(size.x, 6)), Color(0.72, 0.74, 0.78))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _rect().has_point(make_input_local(event).position):
			GameState.add_resource(resource_type, amount)
			_pop()
			get_viewport().set_input_as_handled()


func _rect() -> Rect2:
	# Anchored at bottom-centre so the spot stands on the ground.
	return Rect2(-size.x / 2, -size.y, size.x, size.y)


func _pop() -> void:
	# Quick squash-and-return so a click feels like it did something.
	scale = Vector2(1.15, 0.9)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.12)
