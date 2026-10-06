extends Node2D
## The hooded stranger (the mystical man), standing at the edge of the wood
## while the player decides about his gift. Only for looks.

const SbData := preload("res://sandbox/sb_data.gd")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# A dark robe and hood, a staff, and a faint purple glow.
	draw_circle(Vector2(0, -9), 9.0 + sin(t * 2.0), Color(SbData.TEAL.lerp(Color("#6a3a6a"), 0.7), 0.18))
	draw_rect(Rect2(-3, -14, 7, 14), SbData.INK)
	draw_rect(Rect2(-4, -2, 9, 2), SbData.INK)
	draw_rect(Rect2(-2, -18, 5, 5), SbData.INK)
	draw_rect(Rect2(0, -16, 2, 1), Color("#6a3a6a"))
	draw_rect(Rect2(5, -20, 1, 20), SbData.WOOD0)
	draw_rect(Rect2(4, -22, 3, 2), Color("#6a3a6a").lightened(0.3 + 0.2 * sin(t * 3.0)))
