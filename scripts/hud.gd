extends CanvasLayer
## On-screen text and buttons. Only reads GameState and reacts to its signals.

@onready var resources_label: Label = %ResourcesLabel
@onready var defence_label: Label = %DefenceLabel
@onready var build_button: Button = %BuildButton


func _ready() -> void:
	GameState.resources_changed.connect(_refresh)
	GameState.castle_changed.connect(_refresh)
	build_button.pressed.connect(GameState.build_next)
	_refresh()


func _refresh() -> void:
	resources_label.text = "Wood: %d   Stone: %d" % [GameState.resources.wood, GameState.resources.stone]
	defence_label.text = "Defence: %d" % GameState.total_defence()

	var piece := GameState.next_piece()
	if piece.is_empty():
		build_button.text = "Castle complete"
		build_button.disabled = true
		return
	build_button.text = "Build %s\n%s" % [piece.name, _cost_text(piece.cost)]
	build_button.disabled = not GameState.can_afford(piece.cost)


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for type: String in cost:
		parts.append("%d %s" % [cost[type], type])
	return ", ".join(parts)
