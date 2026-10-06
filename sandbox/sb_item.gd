extends "res://sandbox/sb_thing.gd"
## A loose resource lying on the ground (a log, a stone) waiting to be
## hauled to the stockyard.

var res := "wood"


func setup(res_: String) -> void:
	kind = "item"
	res = res_


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-7, -7), Vector2(14, 10)).has_point(p)


func work_spot(_peasant: Node2D) -> Vector2:
	return position + Vector2(-4, 1)


func label() -> String:
	return {"wood": "a log", "stone": "a stone", "food": "a basket of berries", "planks": "some planks"}.get(res, "something")


func _draw() -> void:
	if res == "food":
		draw_rect(Rect2(-4, -4, 8, 4), SbData.WOOD3)
		draw_rect(Rect2(-4, -4, 8, 1), SbData.WOOD2)
		draw_rect(Rect2(-3, -6, 2, 2), SbData.RED1)
		draw_rect(Rect2(0, -6, 2, 2), SbData.RED1)
		draw_rect(Rect2(2, -5, 1, 1), SbData.RED0)
	elif res == "planks":
		draw_rect(Rect2(-6, -3, 12, 1), SbData.PLANK)
		draw_rect(Rect2(-5, -2, 12, 1), SbData.WOOD3)
		draw_rect(Rect2(-6, -1, 12, 1), SbData.PLANK)
	elif res == "wood":
		draw_rect(Rect2(-6, -4, 12, 4), SbData.WOOD2)
		draw_rect(Rect2(-6, -4, 12, 1), SbData.WOOD3)
		draw_rect(Rect2(5, -4, 2, 4), SbData.DAUB)
	else:
		draw_rect(Rect2(-4, -5, 8, 5), SbData.STONE3)
		draw_rect(Rect2(-4, -5, 8, 1), SbData.STONE4)
		draw_rect(Rect2(3, -5, 1, 5), SbData.STONE1)
