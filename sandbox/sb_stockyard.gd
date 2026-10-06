extends "res://sandbox/sb_thing.gd"
## The stockyard: a shed with a pile per resource. Haulers bring things here,
## builders fetch from here, raiders steal from here.

var stock := {"wood": 0, "stone": 0}


func setup() -> void:
	kind = "stockyard"


func take(res: String) -> bool:
	if stock.get(res, 0) <= 0:
		return false
	stock[res] -= 1
	queue_redraw()
	return true


func put(res: String, n := 1) -> void:
	stock[res] = stock.get(res, 0) + n
	queue_redraw()


## A fire here burns some of the stock.
func burn() -> void:
	if stock.wood > 0:
		stock.wood -= 1
	queue_redraw()


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-34, -30), Vector2(68, 34)).has_point(p)


func work_spot(peasant: Node2D) -> Vector2:
	return position + Vector2(randf_range(-20, 20) if peasant == null else float(hash(peasant.name) % 30) - 15.0, 7.0)


func label() -> String:
	return "the stockyard"


func _draw() -> void:
	# Shed: posts and a plank roof.
	draw_rect(Rect2(-34, -26, 2, 26), SbData.WOOD1)
	draw_rect(Rect2(-6, -26, 2, 26), SbData.WOOD1)
	draw_colored_polygon(PackedVector2Array([Vector2(-38, -24), Vector2(-20, -32), Vector2(-2, -24)]), SbData.WOOD2)
	draw_rect(Rect2(-38, -25, 36, 2), SbData.WOOD3)
	# Log pile under the shed, stone pile beside it: they grow with the amount.
	var logs := mini(stock.wood, 24)
	for i in logs:
		var row := i / 6
		draw_rect(Rect2(-31 + (i % 6) * 4 + (row % 2) * 2, -3 - row * 3, 4, 3), SbData.WOOD2 if i % 2 == 0 else SbData.WOOD3)
	var stones := mini(stock.stone, 24)
	for i in stones:
		var row := i / 6
		draw_rect(Rect2(6 + (i % 6) * 5 + (row % 2) * 2, -4 - row * 4, 5, 4), SbData.STONE3 if i % 2 == 0 else SbData.STONE2)
	draw_string(ThemeDB.fallback_font, Vector2(-30, -36), str(stock.wood), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SbData.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(10, -36), str(stock.stone), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SbData.WHITE)
