extends CanvasLayer
## On-screen text and buttons. Only reads GameState and reacts to its signals.

const CastleData = preload("res://scripts/castle_data.gd")
const JobData = preload("res://scripts/job_data.gd")
const OFFLINE_MESSAGE_TIME := 10.0
const TOAST_TIME := 7.0
## How long the reset button waits for the confirming second press.
const RESET_CONFIRM_TIME := 3.0
const TEXT_COLOR := Color(0.2, 0.2, 0.25)
const HUNGRY_COLOR := Color(0.75, 0.15, 0.15)
const OUTLINE_COLOR := Color(0.96, 0.95, 0.85)

@onready var resources_label: Label = %ResourcesLabel
@onready var defence_label: Label = %DefenceLabel
@onready var rank_label: Label = %RankLabel
@onready var day_label: Label = %DayLabel
@onready var raid_label: Label = %RaidLabel
@onready var toast_label: Label = %ToastLabel
@onready var reset_button: Button = %ResetButton
@onready var crown_button: Button = %CrownButton
@onready var peasants_label: Label = %PeasantsLabel
@onready var jobs_box: VBoxContainer = %Jobs
@onready var hire_button: Button = %HireButton
@onready var build_hover: Node2D = %BuildHover
@onready var build_card: ColorRect = %BuildCard
@onready var build_card_label: Label = %BuildCardLabel
@onready var skills_button: Button = %SkillsButton
@onready var skill_tree: Control = %SkillTree
@onready var offline_label: Label = %OfflineLabel

## Job id -> {"label": Label, "minus": Button, "plus": Button}.
var _job_rows := {}
var _toast_tween: Tween
var _reset_armed := false
var _crown_armed := false


func _ready() -> void:
	for changed: Signal in [
		GameState.resources_changed, GameState.castle_changed, GameState.job_progress_changed,
		GameState.peasants_changed, GameState.trees_changed, GameState.skills_changed,
		GameState.daytime_changed,
	]:
		changed.connect(_refresh)
	hire_button.pressed.connect(GameState.hire_peasant)
	skills_button.pressed.connect(skill_tree.show)
	reset_button.pressed.connect(_on_reset_pressed)
	crown_button.pressed.connect(_on_crown_pressed)
	build_hover.hovered_changed.connect(func(_part: String) -> void: _refresh_build_card())
	GameState.announced.connect(_show_toast)
	GameState.raid_resolved.connect(func(_won: bool) -> void: _refresh())
	_make_job_rows()
	# A pale outline keeps the dark text readable against the night sky.
	for label: Label in find_children("*", "Label", true, false):
		if not skill_tree.is_ancestor_of(label) and label != build_card_label:
			label.add_theme_constant_override("outline_size", 4)
			label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_refresh()
	_show_offline_report()
	if GameState.day == 1 and GameState.total_levels() == 0:
		_show_toast("Your three peasants do the work. Hire more and give them jobs with +. To build, point at a signpost by the castle and click.")


## One row per job in JobData.JOBS: its name and count, and - / + buttons
## that move a peasant out of or into the job.
func _make_job_rows() -> void:
	for id: String in JobData.JOBS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", TEXT_COLOR)
		var minus := _new_button(10)
		minus.text = "-"
		minus.custom_minimum_size = Vector2(22, 0)
		minus.pressed.connect(GameState.assign.bind(id, -1))
		var plus := _new_button(10)
		plus.text = "+"
		plus.custom_minimum_size = Vector2(22, 0)
		plus.pressed.connect(GameState.assign.bind(id, 1))
		var train := _new_button(9)
		train.text = "Train"
		train.custom_minimum_size = Vector2(34, 0)
		train.pressed.connect(GameState.train.bind(id))
		row.add_child(label)
		row.add_child(minus)
		row.add_child(plus)
		row.add_child(train)
		jobs_box.add_child(row)
		_job_rows[id] = {"row": row, "label": label, "minus": minus, "plus": plus, "train": train}


func _new_button(font_size: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button


## Shows a message in the middle of the screen for a few seconds.
func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	toast_label.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 1.0)


## Starting over wipes everything, so it takes two presses in a row.
func _on_reset_pressed() -> void:
	if _reset_armed:
		GameState.reset_game()
		return
	_reset_armed = true
	reset_button.text = "Sure?\nPress again"
	await get_tree().create_timer(RESET_CONFIRM_TIME).timeout
	_reset_armed = false
	reset_button.text = "New game"


## Passing the crown also starts the castle over, so it takes two presses too.
func _on_crown_pressed() -> void:
	if _crown_armed:
		GameState.pass_the_crown()
		return
	_crown_armed = true
	_refresh()
	await get_tree().create_timer(RESET_CONFIRM_TIME).timeout
	_crown_armed = false
	_refresh()


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
		var entry := "%s: %d" % [type.capitalize(), GameState.resources[type]]
		if GameState.income_rate[type] > 0.0:
			entry += " (+%.1f/s)" % GameState.income_rate[type]
		stock.append(entry)
	stock.append("Renown: %d" % GameState.renown)
	if GameState.legacy > 0:
		stock.append("Legacy: %d" % GameState.legacy)
	resources_label.text = "  ".join(stock)
	defence_label.text = "Defence: %d" % GameState.total_defence()
	rank_label.text = "Castle rank %d  (%d/%d levels to next)" % [
		GameState.castle_rank(), GameState.total_levels(), GameState.levels_for_next_rank()]

	day_label.text = "Day %d, %s.  %s" % [
		GameState.day, "night" if GameState.is_night() else "daytime",
		"Fed (eat %d at dawn)" % GameState.food_needed() if GameState.fed else "HUNGRY: working slowly"]
	day_label.text += "  Morale +%d%%" % roundi(GameState.morale_bonus() * 100)
	day_label.add_theme_color_override("font_color", TEXT_COLOR if GameState.fed else HUNGRY_COLOR)

	var safe := GameState.total_defence() >= GameState.raid_strength()
	raid_label.text = "%s: strength %d" % [
		"Raiders at the walls" if GameState.raid_incoming else "Raid on day %d" % GameState.next_raid_day(),
		GameState.raid_strength()]
	raid_label.add_theme_color_override("font_color", TEXT_COLOR if safe else HUNGRY_COLOR)

	var gain := GameState.legacy_gain()
	crown_button.disabled = gain <= 0
	if _crown_armed:
		crown_button.text = "Start over?\nPress again"
	elif gain > 0:
		crown_button.text = "Pass the crown\n+%d legacy" % gain
	else:
		crown_button.text = "Pass the crown\nneeds rank %d" % GameState.LEGACY_MIN_RANK

	var idle := GameState.idle_peasants()
	peasants_label.text = "Peasants: %d  (%d idle)" % [GameState.peasants, idle]
	for id: String in _job_rows:
		var row: Dictionary = _job_rows[id]
		row.row.visible = GameState.job_unlocked(id)
		var limit := GameState.job_limit(id)
		row.label.text = "%s: %d" % [JobData.JOBS[id].name, GameState.jobs[id]]
		if limit >= 0:
			row.label.text += "/%d" % limit
		if GameState.trained[id] > 0:
			row.label.text += " (%d trained)" % GameState.trained[id]
		# The Train button appears once the trade is unlocked in the skill tree.
		var train_reason := GameState.train_block_reason(id)
		row.train.visible = GameState.trade_unlocked(id) and id != "forester"
		row.train.disabled = train_reason != "" or not GameState.can_afford(GameState.train_cost())
		row.train.tooltip_text = "Train one as a %s: %s" % [JobData.JOBS[id].trade, _cost_text(GameState.train_cost())]
		row.minus.disabled = GameState.jobs[id] <= 0
		row.plus.disabled = idle <= 0 or (limit >= 0 and GameState.jobs[id] >= limit)

	var hire_title := "Hire Peasant (%d/%d)" % [GameState.peasants, GameState.max_peasants()]
	if GameState.peasants >= GameState.max_peasants():
		hire_button.text = "%s\nBuild more houses" % hire_title
		hire_button.disabled = true
	else:
		_set_button(hire_button, hire_title, GameState.peasant_cost(), "")
	skills_button.text = "Skills\n%d renown" % GameState.renown

	_refresh_build_card()


## The card for the castle part or village building under the mouse: what
## its next level costs, what it gives, what it takes, and whether a click
## would build it.
func _refresh_build_card() -> void:
	var id: String = build_hover.hovered
	build_card.visible = id != "" and not skill_tree.visible
	if id == "":
		return
	var part: Dictionary = CastleData.PARTS[id]
	var level: int = GameState.part_levels[id]
	var lines: PackedStringArray = ["%s   Lv %d > %d" % [part.name.to_upper(), level, level + 1]]
	lines.append("Cost: %s" % _cost_text(GameState.part_cost(id)))
	lines.append("+ %s" % part.benefit)
	if part.drawback != "":
		lines.append("-  %s" % part.drawback)
	var reason := GameState.part_block_reason(id)
	if id == GameState.job_part:
		lines.append("Being built: %d%%" % (GameState.job_fraction() * 100))
	elif reason != "":
		lines.append(reason)
	elif not GameState.can_afford(GameState.part_cost(id)):
		lines.append("Not enough materials yet")
	else:
		lines.append("Click to build")
	build_card_label.text = "\n".join(lines)
	# Keep the card beside the mouse, and on screen.
	var mouse := build_card.get_viewport().get_mouse_position()
	build_card.size.y = build_card_label.get_minimum_size().y + 12
	build_card.position = Vector2(
		clampf(mouse.x + 14, 4, 640 - build_card.size.x - 4),
		clampf(mouse.y - build_card.size.y - 8, 4, 300 - build_card.size.y))


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
