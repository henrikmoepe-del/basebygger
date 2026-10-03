extends CanvasLayer
## On-screen text and buttons. Only reads GameState and reacts to its signals.

@onready var resources_label: Label = %ResourcesLabel
@onready var defence_label: Label = %DefenceLabel
@onready var hire_button: Button = %HireButton
@onready var plant_button: Button = %PlantButton
@onready var build_button: Button = %BuildButton


func _ready() -> void:
	GameState.resources_changed.connect(_refresh)
	GameState.castle_changed.connect(_refresh)
	GameState.peasants_changed.connect(_refresh)
	GameState.trees_changed.connect(_refresh)
	hire_button.pressed.connect(GameState.hire_peasant)
	plant_button.pressed.connect(GameState.plant_tree)
	build_button.pressed.connect(GameState.build_next)
	_refresh()


func _refresh() -> void:
	resources_label.text = "Wood: %d   Stone: %d" % [GameState.resources.wood, GameState.resources.stone]
	defence_label.text = "Defence: %d" % GameState.total_defence()

	_set_button(hire_button, "Hire Peasant (%d)" % GameState.peasants, GameState.peasant_cost(), "")
	_set_button(plant_button, "Plant Tree (%d/%d)" % [GameState.trees, GameState.MAX_TREES],
			GameState.tree_cost(), "Grove full")
	var piece := GameState.next_piece()
	_set_button(build_button, "Build %s" % piece.get("name", ""), piece.get("cost", {}), "Castle complete")


## Shows "title + cost" and greys the button out when it can't be afforded.
## An empty cost means there is nothing left to buy: show done_text instead.
func _set_button(button: Button, title: String, cost: Dictionary, done_text: String) -> void:
	if cost.is_empty():
		button.text = done_text
		button.disabled = true
		return
	button.text = "%s\n%s" % [title, _cost_text(cost)]
	button.disabled = not GameState.can_afford(cost)


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for type: String in cost:
		parts.append("%d %s" % [cost[type], type])
	return ", ".join(parts)
