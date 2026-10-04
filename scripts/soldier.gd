extends "res://scripts/worker.gd"
## A peasant who guards the castle. Soldiers keep watch from the wall walk,
## the tower tops and the roofs, day and night, pacing to a new spot now and
## then. Each one adds to the castle's defence (counted in
## GameState.total_defence).

## Which post this soldier keeps, from 0 to 1 (see Workers.guard_post).
var _beat := randf()
var _post := Vector2.INF
var _wait := 0.0
var _seen_version := -1


func _sleeps() -> bool:
	return false


func _work(delta: float) -> void:
	if _seen_version != world.castle.version:
		# The castle changed: the old post may have moved.
		_seen_version = world.castle.version
		_post = world.guard_post(_beat, home_x)
	if _go_to(_post, delta):
		_wait -= delta
		if _wait <= 0.0:
			_wait = randf_range(5.0, 14.0)
			_post = world.guard_post(_beat, home_x)


func _draw_extra(bob_y: float) -> void:
	# Helmet and spear.
	draw_rect(Rect2(-2, bob_y - 15, 4, 2), Color(0.62, 0.62, 0.66))
	draw_rect(Rect2(4, bob_y - 18, 1, 18), Color(0.48, 0.32, 0.20))
	draw_rect(Rect2(3, bob_y - 20, 3, 3), Color(0.75, 0.76, 0.80))
