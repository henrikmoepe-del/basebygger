extends "res://scripts/gather_spot.gd"
## Where stone comes from. Without a quarry it is a few loose stones that
## are quickly used up; building and levelling the Quarry (a village
## building in CastleData) makes stone appear faster and pile up higher.
## The quarry itself is drawn by the castle; this draws only the loose stones.

var stone_left := 0.0


func _ready() -> void:
	stone_left = GameState.quarry_capacity()
	GameState.castle_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	stone_left = minf(stone_left + GameState.quarry_rate() * delta, GameState.quarry_capacity())


func can_gather() -> bool:
	return stone_left >= 1.0


func take() -> bool:
	if stone_left < 1.0:
		return false
	stone_left -= 1.0
	return true


func _draw() -> void:
	if GameState.part_levels.quarry > 0:
		return
	draw_rect(Rect2(-14, -8, 12, 8), Color(0.55, 0.57, 0.62))
	draw_rect(Rect2(-3, -12, 14, 12), Color(0.60, 0.62, 0.67))
	draw_rect(Rect2(10, -6, 8, 6), Color(0.52, 0.54, 0.59))
	draw_rect(Rect2(-3, -12, 14, 3), Color(0.72, 0.74, 0.78))
