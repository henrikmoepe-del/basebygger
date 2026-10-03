extends "res://scripts/worker.gd"
## A peasant who looks after the grove. While there is room for more trees
## they plant the next one; otherwise they walk among the trees tending them.
## (The regrowth bonus for tending is counted in GameState.tree_grow_mult.)

const TEND_PAUSE := 2.0

var _target_x := 0.0
var _pause := 0.01
var _planting := false


func _work(delta: float) -> void:
	_planting = false
	if GameState.trees < GameState.max_trees():
		if _walk_to(world.grove.plot_x(GameState.trees), delta):
			_planting = true
			GameState.add_planting_work(delta)
		return

	# Grove is full: wander from tree to tree.
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_target_x = world.grove.plot_x(randi() % GameState.trees) + randf_range(-4.0, 4.0)
	elif _walk_to(_target_x, delta):
		_pause = TEND_PAUSE


func _bob() -> float:
	return -absf(sin(Time.get_ticks_msec() / 120.0)) * 1.5 if _planting else 0.0


func _draw_extra(bob_y: float) -> void:
	if _planting:
		# A spade.
		draw_rect(Rect2(4, bob_y - 9, 1, 9), Color(0.48, 0.32, 0.20))
		draw_rect(Rect2(3, bob_y - 1, 3, 2), Color(0.30, 0.30, 0.34))
