extends CanvasLayer
## On-screen text and buttons. Only reads GameState and reacts to its signals.

const CastleData = preload("res://scripts/castle_data.gd")
const OFFLINE_MESSAGE_TIME := 10.0

@onready var resources_label: Label = %ResourcesLabel
@onready var defence_label: Label = %DefenceLabel
@onready var rank_label: Label = %RankLabel
@onready var hire_button: Button = %HireButton
@onready var plant_button: Button = %PlantButton
@onready var builder_button: Button = %BuilderButton
@onready var parts_box: HBoxContainer = %Parts
@onready var skills_button: Button = %SkillsButton
@onready var skill_tree: Control = %SkillTree
@onready var offline_label: Label = %OfflineLabel

## Castle part id -> its button.
var _part_buttons := {}


func _ready() -> void:
	for changed: Signal in [
		GameState.resources_changed, GameState.castle_changed, GameState.job_progress_changed,
		GameState.peasants_changed, GameState.trees_changed, GameState.builders_changed,
		GameState.skills_changed,
	]:
		changed.connect(_refresh)
	hire_button.pressed.connect(GameState.hire_peasant)
	plant_button.pressed.connect(GameState.plant_tree)
	builder_button.pressed.connect(GameState.hire_builder)
	skills_button.pressed.connect(skill_tree.show)
	_make_buttons()
	_refresh()
	_show_offline_report()


## One button per castle part, made from the data in CastleData.PARTS,
## so adding a part there is all it takes to get it on screen.
func _make_buttons() -> void:
	for id: String in CastleData.PARTS:
		var button := _new_button(11)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(GameState.order_part.bind(id))
		parts_box.add_child(button)
		_part_buttons[id] = button


func _new_button(font_size: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button


## Tells the player what they earned while the game was closed, then fades out.
func _show_offline_report() -> void:
	var report: Dictionary = GameState.offline_report
	if report.is_empty():
		return
	var minutes: int = report.seconds / 60
	offline_label.text = "While you were away (%dh %dm): +%d wood, +%d stone" % [
		minutes / 60, minutes % 60, report.wood, report.stone]
	offline_label.show()
	var tween := create_tween()
	tween.tween_interval(OFFLINE_MESSAGE_TIME)
	tween.tween_property(offline_label, "modulate:a", 0.0, 1.0)


func _refresh() -> void:
	resources_label.text = "Wood: %d   Stone: %d   Renown: %d" % [
		GameState.resources.wood, GameState.resources.stone, GameState.renown]
	defence_label.text = "Defence: %d" % GameState.total_defence()
	rank_label.text = "Castle rank %d  (%d/%d levels to next)" % [
		GameState.castle_rank(), GameState.total_levels(), GameState.levels_for_next_rank()]

	_set_button(hire_button, "Hire Peasant (%d)" % GameState.peasants, GameState.peasant_cost(), "")
	_set_button(plant_button, "Plant Tree (%d/%d)" % [GameState.trees, GameState.MAX_TREES],
			GameState.tree_cost(), "Grove full")
	_set_button(builder_button, "Hire Builder (%d)" % GameState.builders, GameState.builder_cost(), "")

	for id: String in _part_buttons:
		_refresh_part_button(id, _part_buttons[id])

	skills_button.text = "Skills
%d renown" % GameState.renown


func _refresh_part_button(id: String, button: Button) -> void:
	var part_name: String = CastleData.PARTS[id].name
	var level: int = GameState.part_levels[id]
	if id == GameState.job_part:
		button.text = "Building %s Lv %d\n%d%%" % [part_name, level + 1, GameState.job_fraction() * 100]
		button.disabled = true
		return
	var reason := GameState.part_block_reason(id)
	var cost := GameState.part_cost(id)
	button.text = "%s Lv %d\n%s" % [part_name, level, reason if reason != "" else _cost_text(cost)]
	button.disabled = reason != "" or not GameState.can_afford(cost)


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
