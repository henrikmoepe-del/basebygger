extends Node2D
## Spawns one builder for every builder counted in GameState.

const Builder = preload("res://scripts/builder.gd")
const CastleData = preload("res://scripts/castle_data.gd")

@export var castle: Node2D
@export var stock_x := 215.0


func _ready() -> void:
	GameState.builders_changed.connect(_sync)
	_sync()


## Where builders stand to work on the current job.
func site_x() -> float:
	return castle.position.x + CastleData.PARTS[GameState.job_part].site_x


func _sync() -> void:
	while get_child_count() < GameState.builders:
		var builder := Builder.new()
		builder.stock_x = stock_x
		builder.site_x = site_x
		# Idle builders line up in front of the castle.
		builder.rest_x = castle.position.x - 140.0 + (get_child_count() % 12) * 12.0
		builder.speed *= randf_range(0.9, 1.1)
		builder.position.x = builder.rest_x
		add_child(builder)
