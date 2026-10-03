extends CanvasLayer
## On-screen text and buttons. Only reads GameState and reacts to its signals.

const CastleData = preload("res://scripts/castle_data.gd")
const JobData = preload("res://scripts/job_data.gd")
const OFFLINE_MESSAGE_TIME := 10.0
const TEXT_COLOR := Color(0.2, 0.2, 0.25)

@onready var resources_label: Label = %ResourcesLabel
@onready var defence_label: Label = %DefenceLabel
@onready var rank_label: Label = %RankLabel
@onready var peasants_label: Label = %PeasantsLabel
@onready var jobs_box: VBoxContainer = %Jobs
@onready var hire_button: Button = %HireButton
@onready var plant_button: Button = %PlantButton
@onready var parts_box: HBoxContainer = %Parts
@onready var skills_button: Button = %SkillsButton
@onready var skill_tree: Control = %SkillTree
@onready var offline_label: Label = %OfflineLabel

## Castle part id -> its button.
var _part_buttons := {}
## Job id -> {"label": Label, "minus": Button, "plus": Button}.
var _job_rows := {}


func _ready() -> void:
	for changed: Signal in [
		GameState.resources_changed, GameState.castle_changed, GameState.job_progress_changed,
		GameState.peasants_changed, GameState.trees_changed, GameState.skills_changed,
	]:
		changed.connect(_refresh)
	hire_button.pressed.connect(GameState.hire_peasant)
	plant_button.pressed.connect(GameState.plant_tree)
	skills_button.pressed.connect(skill_tree.show)
	_make_part_buttons()
	_make_job_rows()
	_refresh()
	_show_offline_report()


## One button per castle part, made from the data in CastleData.PARTS,
## so adding a part there is all it takes to get it on screen.
func _make_part_buttons() -> void:
	for id: String in CastleData.PARTS:
		var button := _new_button(10)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(GameState.order_part.bind(id))
		parts_box.add_child(button)
		_part_buttons[id] = button


## One row per job in JobData.JOBS: its name and count, and - / + buttons
## that move a peasant out of or into the job.
func _make_job_rows() -> void:
	for id: String in JobData.JOBS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", TEXT_COLOR)
		var minus := _new_button(11)
		minus.text = "-"
		minus.custom_minimum_size = Vector2(22, 0)
		minus.pressed.connect(GameState.assign.bind(id, -1))
		var plus := _new_button(11)
		plus.text = "+"
		plus.custom_minimum_size = Vector2(22, 0)
		plus.pressed.connect(GameState.assign.bind(id, 1))
		row.add_child(label)
		row.add_child(minus)
		row.add_child(plus)
		jobs_box.add_child(row)
		_job_rows[id] = {"row": row, "label": label, "minus": minus, "plus": plus}


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
	var gains: PackedStringArray = []
	for type: String in report:
		if type != "seconds" and report[type] > 0:
			gains.append("+%d %s" % [report[type], type])
	offline_label.text = "While you were away (%dh %dm): %s" % [minutes / 60, minutes % 60, ", ".join(gains)]
	offline_label.show()
	var tween := create_tween()
	tween.tween_interval(OFFLINE_MESSAGE_TIME)
	tween.tween_property(offline_label, "modulate:a", 0.0, 1.0)


func _refresh() -> void:
	var stock: PackedStringArray = []
	for type: String in GameState.resources:
		stock.append("%s: %d" % [type.capitalize(), GameState.resources[type]])
	stock.append("Renown: %d" % GameState.renown)
	resources_label.text = "   ".join(stock)
	defence_label.text = "Defence: %d" % GameState.total_defence()
	rank_label.text = "Castle rank %d  (%d/%d levels to next)" % [
		GameState.castle_rank(), GameState.total_levels(), GameState.levels_for_next_rank()]

	var idle := GameState.idle_peasants()
	peasants_label.text = "Peasants: %d  (%d idle)" % [GameState.peasants, idle]
	for id: String in _job_rows:
		var row: Dictionary = _job_rows[id]
		row.row.visible = GameState.job_unlocked(id)
		row.label.text = "%s: %d" % [JobData.JOBS[id].name, GameState.jobs[id]]
		row.minus.disabled = GameState.jobs[id] <= 0
		row.plus.disabled = idle <= 0

	_set_button(hire_button, "Hire Peasant", GameState.peasant_cost(), "")
	_set_button(plant_button, "Plant Tree (%d/%d)" % [GameState.trees, GameState.MAX_TREES],
			GameState.tree_cost(), "Grove full")
	skills_button.text = "Skills\n%d renown" % GameState.renown

	for id: String in _part_buttons:
		_refresh_part_button(id, _part_buttons[id])


func _refresh_part_button(id: String, button: Button) -> void:
	var part_name: String = CastleData.PARTS[id].name
	var level: int = GameState.part_levels[id]
	if id == GameState.job_part:
		button.text = "Building %s %d\n%d%%" % [part_name, level + 1, GameState.job_fraction() * 100]
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
