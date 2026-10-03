extends CanvasLayer
## On-screen text and buttons. Only reads GameState and reacts to its signals.

@onready var resources_label: Label = %ResourcesLabel
@onready var defence_label: Label = %DefenceLabel
@onready var hire_button: Button = %HireButton
@onready var plant_button: Button = %PlantButton
@onready var builder_button: Button = %BuilderButton
@onready var build_button: Button = %BuildButton
@onready var upgrades_box: VBoxContainer = %Upgrades

## Upgrade id -> its button.
var _upgrade_buttons := {}


func _ready() -> void:
	for changed: Signal in [
		GameState.resources_changed, GameState.castle_changed, GameState.build_progress_changed,
		GameState.peasants_changed, GameState.trees_changed, GameState.builders_changed,
		GameState.upgrades_changed,
	]:
		changed.connect(_refresh)
	hire_button.pressed.connect(GameState.hire_peasant)
	plant_button.pressed.connect(GameState.plant_tree)
	builder_button.pressed.connect(GameState.hire_builder)
	build_button.pressed.connect(GameState.start_build)
	_make_upgrade_buttons()
	_refresh()


## One button per upgrade in GameState.UPGRADES, so adding an upgrade there
## is all it takes to get it on screen.
func _make_upgrade_buttons() -> void:
	for id: String in GameState.UPGRADES:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(GameState.buy_upgrade.bind(id))
		upgrades_box.add_child(button)
		_upgrade_buttons[id] = button


func _refresh() -> void:
	resources_label.text = "Wood: %d   Stone: %d" % [GameState.resources.wood, GameState.resources.stone]
	defence_label.text = "Defence: %d" % GameState.total_defence()

	_set_button(hire_button, "Hire Peasant (%d)" % GameState.peasants, GameState.peasant_cost(), "")
	_set_button(plant_button, "Plant Tree (%d/%d)" % [GameState.trees, GameState.MAX_TREES],
			GameState.tree_cost(), "Grove full")
	_set_button(builder_button, "Hire Builder (%d)" % GameState.builders, GameState.builder_cost(), "")

	var piece := GameState.next_piece()
	if GameState.building:
		build_button.text = "Building %s\n%d%%" % [piece.name, GameState.build_fraction() * 100]
		build_button.disabled = true
	else:
		_set_button(build_button, "Build %s" % piece.get("name", ""), piece.get("cost", {}), "Castle complete")

	for id: String in _upgrade_buttons:
		var cost := GameState.upgrade_cost(id)
		var button: Button = _upgrade_buttons[id]
		button.text = "%s (Lv %d): %s" % [GameState.UPGRADES[id].name, GameState.upgrades[id], _cost_text(cost)]
		button.disabled = not GameState.can_afford(cost)


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
