extends CanvasLayer
## Everything drawn over the world: the top bar, the goal line, the peasants
## panel, the build card, messages and the bottom buttons. It only reads
## GameState and reacts to its signals.
##
## The layout follows three levels of importance:
##   always visible   resources, the day, defence, the current goal, the next raid
##   when relevant    the build card (pointing at the world), messages, hunger
##   on demand        the peasants panel (can be folded away), skills, the menu

const CastleData = preload("res://scripts/castle_data.gd")
const JobData = preload("res://scripts/job_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const OFFLINE_MESSAGE_TIME := 10.0
const TOAST_TIME := 7.0
## How long the reset button waits for the confirming second press.
const RESET_CONFIRM_TIME := 3.0

@onready var resource_bar: HBoxContainer = %ResourceBar
@onready var defence_label: Label = %DefenceLabel
@onready var day_label: Label = %DayLabel
@onready var goal_label: Label = %GoalLabel
@onready var raid_label: Label = %RaidLabel
@onready var rank_label: Label = %RankLabel
@onready var toast_panel: Panel = %ToastPanel
@onready var toast_label: Label = %ToastLabel
@onready var offline_label: Label = %OfflineLabel
@onready var jobs_toggle: Button = %JobsToggle
@onready var jobs_panel: Panel = %JobsPanel
@onready var jobs_box: VBoxContainer = %Jobs
@onready var build_hover: Node2D = %BuildHover
@onready var build_card: Panel = %BuildCard
@onready var build_card_label: Label = %BuildCardLabel
@onready var hire_button: Button = %HireButton
@onready var cow_button: Button = %CowButton
@onready var defend_button: Button = %DefendButton
@onready var skills_button: Button = %SkillsButton
@onready var menu_button: Button = %MenuButton
@onready var menu_panel: Panel = %MenuPanel
@onready var crown_button: Button = %CrownButton
@onready var reset_button: Button = %ResetButton
@onready var skill_tree: Control = %SkillTree

## Resource id -> the Label on its chip in the top bar.
var _chips := {}
## Job id -> {"row", "label", "minus", "plus", "train"}.
var _job_rows := {}
var _toast_tween: Tween
var _reset_armed := false
var _crown_armed := false


func _ready() -> void:
	var theme := UiTheme.build()
	for child in get_children():
		if child is Control:
			child.theme = theme

	for changed: Signal in [
		GameState.resources_changed, GameState.castle_changed, GameState.job_progress_changed,
		GameState.peasants_changed, GameState.trees_changed, GameState.skills_changed,
		GameState.daytime_changed, GameState.raid_started,
	]:
		changed.connect(_refresh)
	hire_button.pressed.connect(GameState.hire_peasant)
	cow_button.pressed.connect(GameState.buy_cow)
	defend_button.pressed.connect(GameState.start_siege)
	skills_button.pressed.connect(skill_tree.show)
	jobs_toggle.pressed.connect(func() -> void:
		jobs_panel.visible = not jobs_panel.visible
		_refresh())
	menu_button.pressed.connect(func() -> void: menu_panel.visible = not menu_panel.visible)
	reset_button.pressed.connect(_on_reset_pressed)
	crown_button.pressed.connect(_on_crown_pressed)
	build_hover.hovered_changed.connect(func(_part: String) -> void: _refresh_build_card())
	GameState.announced.connect(_show_toast)
	# A click sound whenever something is bought, and a shake when a raid is lost.
	GameState.peasants_changed.connect(func() -> void: get_tree().call_group("sfx", "play", "buy"))
	GameState.raid_resolved.connect(func(won: bool) -> void:
		_refresh()
		if not won:
			get_tree().call_group("camera", "shake", 6.0))

	_make_chips()
	_make_job_rows()
	_refresh()
	_show_offline_report()
	if GameState.day == 1 and GameState.total_levels() == 0:
		_show_toast("Your three peasants do the work. Hire more and give them jobs with +. To build, point at a signpost by the castle and click.")


# --- Building the interface ---

## One chip per resource in the top bar: a square in the resource's colour
## and its amount. Hovering a chip says what it is and what it earns.
func _make_chips() -> void:
	for type: String in ["wood", "stone", "food", "iron", "renown", "legacy"]:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		var swatch := ColorRect.new()
		swatch.color = UiTheme.RESOURCE_COLORS[type]
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(swatch)
		chip.add_child(label)
		resource_bar.add_child(chip)
		_chips[type] = label


## One row per job in JobData.JOBS: a square in the job's tunic colour, its
## name and count, - / + to move a peasant out of or into the job, and Train.
func _make_job_rows() -> void:
	for id: String in JobData.JOBS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var swatch := ColorRect.new()
		swatch.color = JobData.JOBS[id].color
		swatch.custom_minimum_size = Vector2(6, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 10)
		var minus := _small_button("-", 16)
		minus.pressed.connect(GameState.assign.bind(id, -1))
		var plus := _small_button("+", 16)
		plus.pressed.connect(GameState.assign.bind(id, 1))
		var train := _small_button("Train", 30)
		train.pressed.connect(GameState.train.bind(id))
		for part: Control in [swatch, label, minus, plus, train]:
			row.add_child(part)
		jobs_box.add_child(row)
		_job_rows[id] = {"row": row, "label": label, "minus": minus, "plus": plus, "train": train}


func _small_button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(width, 13)
	button.add_theme_font_size_override("font_size", 9)
	UiTheme.make_compact(button)
	return button


# --- Messages ---

## Shows a message in a banner for a few seconds. Good news is gold, and
## everything pops in a little too big and settles.
func _show_toast(text: String) -> void:
	toast_label.text = text
	var good := text.begins_with("Goal") or text.begins_with("Raid repelled") or text.begins_with("Castle rank")
	toast_label.add_theme_color_override("font_color", UiTheme.GOLD if good else UiTheme.PARCHMENT)
	toast_panel.modulate.a = 1.0
	toast_panel.show()
	toast_panel.pivot_offset = toast_panel.size / 2
	toast_panel.scale = Vector2(1.12, 1.12)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 1.0)
	_toast_tween.tween_callback(toast_panel.hide)


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


# --- The menu: starting over ---

## Starting over wipes everything, so it takes two presses in a row.
func _on_reset_pressed() -> void:
	if _reset_armed:
		GameState.reset_game()
		return
	_reset_armed = true
	reset_button.text = "Sure? Press again"
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


# --- Keeping it up to date ---

func _refresh() -> void:
	_refresh_top_bar()
	_refresh_jobs()

	var hire_title := "Hire peasant"
	if GameState.peasants >= GameState.max_peasants():
		hire_button.text = "%s\nBuild more houses" % hire_title
		hire_button.disabled = true
	else:
		_set_button(hire_button, hire_title, GameState.peasant_cost(), "")
	cow_button.visible = GameState.skill_level("cattle") > 0
	_set_button(cow_button, "Buy cow (%d/%d)" % [GameState.cows, GameState.MAX_COWS],
			GameState.cow_cost() if GameState.cow_block_reason() == "" else {}, "Pasture full")
	skills_button.text = "Skills\n%d renown to spend" % GameState.renown
	# The 3D siege is parked for now; the dev key F7 still opens it.
	defend_button.visible = false

	var gain := GameState.legacy_gain()
	crown_button.disabled = gain <= 0
	if _crown_armed:
		crown_button.text = "Start over? Press again"
	elif gain > 0:
		crown_button.text = "Pass the crown (+%d legacy)" % gain
	else:
		crown_button.text = "Pass the crown (needs rank %d)" % GameState.LEGACY_MIN_RANK
	_refresh_build_card()


func _refresh_top_bar() -> void:
	for type: String in _chips:
		var label: Label = _chips[type]
		var chip: Control = label.get_parent()
		match type:
			"renown":
				label.text = str(GameState.renown)
				chip.tooltip_text = "Renown: spend it on skills. Earned from castle levels, goals and raids."
			"legacy":
				chip.visible = GameState.legacy > 0
				label.text = str(GameState.legacy)
				chip.tooltip_text = "Legacy: everyone works %d%% faster, for good." % roundi(GameState.legacy * GameState.LEGACY_WORK_BONUS * 100)
			_:
				# Iron only matters once there is a mine.
				chip.visible = type != "iron" or GameState.part_levels.mine > 0
				label.text = str(GameState.resources[type])
				chip.tooltip_text = "%s: +%.1f a second (averaged over a day)" % [type.capitalize(), GameState.income_rate[type]]

	defence_label.text = "Defence %d" % GameState.total_defence()
	day_label.text = "Day %d, %s  -  %s" % [
		GameState.day, "night" if GameState.is_night() else "day",
		"fed" if GameState.fed else "HUNGRY"]
	day_label.add_theme_color_override("font_color", UiTheme.PARCHMENT if GameState.fed else UiTheme.BAD)
	day_label.tooltip_text = "Peasants eat %d food at dawn. Without enough they work at %d%% for the day.\nMorale from the well, tavern and quarry: %+d%% work speed." % [
		GameState.food_needed(), roundi(GameState.HUNGRY_WORK_MULT * 100), roundi(GameState.morale_bonus() * 100)]

	var quest := GameState.current_quest()
	goal_label.text = "Goal: %s  (+%d renown)" % [quest.text, quest.renown] if not quest.is_empty() else "All goals reached"

	var safe := GameState.total_defence() >= GameState.raid_strength()
	raid_label.text = "%s: strength %d" % [
		"Raiders at the walls" if GameState.raid_incoming else "Raid on day %d" % GameState.next_raid_day(),
		GameState.raid_strength()]
	raid_label.add_theme_color_override("font_color", UiTheme.PARCHMENT if safe else UiTheme.BAD)
	rank_label.text = "Castle rank %d  (%d of %d levels to the next)" % [
		GameState.castle_rank(), GameState.total_levels(), GameState.levels_for_next_rank()]


func _refresh_jobs() -> void:
	var idle := GameState.idle_peasants()
	jobs_toggle.text = "%s Peasants %d/%d%s" % [
		"v" if jobs_panel.visible else ">", GameState.peasants, GameState.max_peasants(),
		"  (%d idle)" % idle if idle > 0 else ""]
	jobs_toggle.add_theme_color_override("font_color", UiTheme.GOLD if idle > 0 else UiTheme.PARCHMENT)
	for id: String in _job_rows:
		var row: Dictionary = _job_rows[id]
		row.row.visible = GameState.job_unlocked(id)
		var limit := GameState.job_limit(id)
		row.label.text = "%s %d" % [JobData.JOBS[id].name, GameState.jobs[id]]
		if limit >= 0:
			row.label.text += "/%d" % limit
		if GameState.trained[id] > 0:
			row.label.text += " (%d trained)" % GameState.trained[id]
		row.minus.disabled = GameState.jobs[id] <= 0
		row.plus.disabled = idle <= 0 or (limit >= 0 and GameState.jobs[id] >= limit)
		# The Train button appears once the trade is unlocked in the skill tree.
		var train_reason := GameState.train_block_reason(id)
		row.train.visible = GameState.trade_unlocked(id) and id != "forester"
		row.train.disabled = train_reason != "" or not GameState.can_afford(GameState.train_cost())
		row.train.tooltip_text = "Train one as a %s: %s" % [JobData.JOBS[id].trade, _cost_text(GameState.train_cost())]
	# The panel is just tall enough for the jobs that exist so far.
	jobs_panel.size.y = jobs_box.get_combined_minimum_size().y + 8.0


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
		clampf(mouse.y - build_card.size.y - 8, 40, 316 - build_card.size.y))


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
