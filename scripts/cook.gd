extends "res://scripts/worker.gd"
## A peasant who cooks: at the pot by the stockyard at first, and in the
## keep's kitchen once there is a keep. Cooks make food go further (the
## saving is counted in GameState.food_needed).


func _work(delta: float) -> void:
	_go_to(world.kitchen_spot(home_x - world.stock_x), delta)


func _bob() -> float:
	return -absf(sin(Time.get_ticks_msec() / 200.0 + home_x)) * 1.0


func _draw_extra(bob_y: float) -> void:
	# A ladle.
	draw_rect(Rect2(3, bob_y - 9, 4, 1), Color(0.48, 0.32, 0.20))
