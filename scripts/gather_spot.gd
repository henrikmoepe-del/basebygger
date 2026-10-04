extends Node2D
## A spot peasants gather a resource from.
## Used as-is for the rock (never runs out); tree.gd extends it.
## Drawn with placeholder shapes until we have real art.

@export var resource_type := "stone"
@export var size := Vector2(40, 26)
## "rock", "bushes" or "none": which placeholder to draw.
@export var look := "rock"


## True if there is something to gather here right now.
func can_gather() -> bool:
	return true


## Removes one unit from the spot. Returns false if there was nothing to take.
func take() -> bool:
	return true


func _draw() -> void:
	if look == "none":
		return
	var r := _rect()
	if look == "bushes":
		# The wilds: thick bushes with berries, where hunters find food.
		draw_rect(r, Color(0.16, 0.36, 0.24))
		draw_rect(Rect2(r.position + Vector2(4, -8), Vector2(size.x * 0.5, 10)), Color(0.20, 0.42, 0.26))
		for i in 6:
			draw_rect(Rect2(r.position.x + 5 + i * 6, r.position.y + 6 + (i % 3) * 7, 2, 2), Color(0.75, 0.20, 0.30))
		return
	draw_rect(r, Color(0.55, 0.57, 0.62))
	draw_rect(Rect2(r.position, Vector2(size.x, 6)), Color(0.72, 0.74, 0.78))


func _rect() -> Rect2:
	# Anchored at bottom-centre so the spot stands on the ground.
	return Rect2(-size.x / 2, -size.y, size.x, size.y)
