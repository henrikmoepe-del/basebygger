extends "res://sandbox/sb_thing.gd"
## The stockyard: a shed with a pile per resource. Haulers bring things here,
## builders fetch from here, raiders steal from here.

var stock := {"wood": 0, "stone": 0, "food": 0, "planks": 0}


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
	if world != null:
		world.sound("deliver", position)
	queue_redraw()


## A fire here burns some of the stock.
func burn() -> void:
	if stock.wood > 0:
		stock.wood -= 1
	queue_redraw()


func has_fuel() -> bool:
	return stock.wood > 0


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-34, -30), Vector2(92, 34)).has_point(p)


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
	# Baskets of food on a bench at the east end.
	draw_rect(Rect2(38, -5, 18, 2), SbData.WOOD1)
	draw_rect(Rect2(39, -3, 1, 3), SbData.WOOD0)
	draw_rect(Rect2(54, -3, 1, 3), SbData.WOOD0)
	for i in mini(stock.food, 12):
		var row := i / 4
		draw_rect(Rect2(38 + (i % 4) * 4 + (row % 2) * 2, -9 - row * 4, 4, 4), SbData.WOOD3)
		draw_rect(Rect2(39 + (i % 4) * 4 + (row % 2) * 2, -10 - row * 4, 2, 1), SbData.RED1)
	draw_string(ThemeDB.fallback_font, Vector2(42, -36), str(stock.food), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SbData.WHITE)
	# Planks leaning against the shed's back post.
	for i in mini(stock.planks, 12):
		draw_rect(Rect2(-37 + i % 2, -20 + (i / 2) * 3, 2, 3), SbData.PLANK)
	for i in mini(stock.planks, 10):
		draw_rect(Rect2(-31 + (i % 5) * 5, -14 - (i / 5) * 2, 5, 1), SbData.PLANK)
	if stock.planks > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-62, -12), "%d" % stock.planks, HORIZONTAL_ALIGNMENT_RIGHT, 22, 8, SbData.PLANK)
	draw_string(ThemeDB.fallback_font, Vector2(-30, -36), str(stock.wood), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SbData.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(10, -36), str(stock.stone), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SbData.WHITE)


func describe() -> String:
	return "The stockyard: %d wood, %d stone, %d food, %d planks" % [stock.wood, stock.stone, stock.food, stock.planks]
