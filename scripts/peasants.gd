extends Node2D
## Spawns one walking peasant for every peasant hired in GameState,
## and draws the stockpile they carry resources back to.

const Peasant = preload("res://scripts/peasant.gd")

@export var grove: Node2D
@export var rock: Node2D
@export var home_x := 275.0


func _ready() -> void:
	GameState.peasants_changed.connect(_sync)
	_sync()


func _draw() -> void:
	# Stockpile crate.
	draw_rect(Rect2(home_x - 9, -10, 18, 10), Color(0.48, 0.32, 0.20))
	draw_rect(Rect2(home_x - 9, -6, 18, 2), Color(0.33, 0.21, 0.13))


## Where a peasant should go for this resource right now (null = nowhere).
func find_spot(resource_type: String) -> Node2D:
	if resource_type == "wood":
		return grove.best_tree()
	return rock


func _sync() -> void:
	while get_child_count() < GameState.peasants:
		var peasant := Peasant.new()
		# Alternate jobs so wood and stone both come in.
		peasant.resource_type = "wood" if get_child_count() % 2 == 0 else "stone"
		peasant.find_spot = find_spot
		peasant.home_x = home_x + randf_range(-6.0, 6.0)
		peasant.speed *= randf_range(0.9, 1.1)
		peasant.position.x = peasant.home_x
		add_child(peasant)
