extends "res://sandbox/sb_thing.gd"
## The well: where buckets are filled to put out fires.


func setup() -> void:
	kind = "well"


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-9, -22), Vector2(18, 24)).has_point(p)


func work_spot(peasant: Node2D) -> Vector2:
	return position + Vector2(float(hash(peasant.name) % 16) - 8.0, 6.0)


func label() -> String:
	return "the well"


func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 8), SbData.STONE2)
	draw_rect(Rect2(-8, -8, 16, 2), SbData.STONE3)
	draw_rect(Rect2(-7, -20, 2, 12), SbData.WOOD1)
	draw_rect(Rect2(5, -20, 2, 12), SbData.WOOD1)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -18), Vector2(0, -25), Vector2(10, -18)]), SbData.WOOD2)
	draw_rect(Rect2(-1, -15, 2, 4), SbData.STONE1)


func describe() -> String:
	return "The well: buckets for putting out fires"
