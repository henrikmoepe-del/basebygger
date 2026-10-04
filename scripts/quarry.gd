extends "res://scripts/gather_spot.gd"
## A gathering site with a limited stock that refills over time: the stone
## site and the hunting grounds. How fast it refills and how much it holds
## come from GameState, and grow with the building for that resource (the
## Quarry for stone, the Farm for food).

var stock := 0.0


func _ready() -> void:
	stock = GameState.site_capacity(resource_type)
	GameState.castle_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	stock = minf(stock + GameState.site_rate(resource_type) * delta, GameState.site_capacity(resource_type))


func can_gather() -> bool:
	return stock >= 1.0


func take() -> bool:
	if stock < 1.0:
		return false
	stock -= 1.0
	return true


func _draw() -> void:
	if resource_type != "stone":
		super._draw()
		return
	# Loose stones, until a quarry is built here (the castle draws the quarry).
	if GameState.part_levels.quarry > 0:
		return
	draw_rect(Rect2(-14, -8, 12, 8), Color(0.55, 0.57, 0.62))
	draw_rect(Rect2(-3, -12, 14, 12), Color(0.60, 0.62, 0.67))
	draw_rect(Rect2(10, -6, 8, 6), Color(0.52, 0.54, 0.59))
	draw_rect(Rect2(-3, -12, 14, 3), Color(0.72, 0.74, 0.78))
