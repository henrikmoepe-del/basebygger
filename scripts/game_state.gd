extends Node
## Global game data (autoload). Scenes read and change the game through this,
## so the 2D builder and the later 3D mode can share the same state.

signal resources_changed

var resources := {"wood": 0, "stone": 0}


func add_resource(type: String, amount: int) -> void:
	resources[type] += amount
	resources_changed.emit()
