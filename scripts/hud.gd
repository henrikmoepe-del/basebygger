extends CanvasLayer
## On-screen text and buttons. Only reads GameState and reacts to its signals.

@onready var resources_label: Label = %ResourcesLabel


func _ready() -> void:
	GameState.resources_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	resources_label.text = "Wood: %d   Stone: %d" % [GameState.resources.wood, GameState.resources.stone]
