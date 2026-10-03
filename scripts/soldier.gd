extends "res://scripts/worker.gd"
## A peasant who guards the castle. Soldiers stand watch on top of the walls,
## day and night, and each one adds to the castle's defence (counted in
## GameState.total_defence).

var _on_wall := false


func _sleeps() -> bool:
	return false


func _work(delta: float) -> void:
	_on_wall = _walk_to(home_x, delta)
	# Once in place they climb up; while walking they are on the ground.
	position.y = world.wall_top_y() if _on_wall else 0.0


func _draw_extra(bob_y: float) -> void:
	# Helmet and spear.
	draw_rect(Rect2(-2, bob_y - 15, 4, 2), Color(0.62, 0.62, 0.66))
	draw_rect(Rect2(4, bob_y - 18, 1, 18), Color(0.48, 0.32, 0.20))
	draw_rect(Rect2(3, bob_y - 20, 3, 3), Color(0.75, 0.76, 0.80))
