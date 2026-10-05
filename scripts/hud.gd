extends CanvasLayer
## Everything drawn over the world: the top bar, the goal line, the peasants
## panel, the build card, messages and the bottom buttons. It only reads
## GameState and reacts to its signals.
##
## The layout follows three levels of importance:
##   always visible   resources, the day, defence, the current goal, the next raid
##   when relevant    the build card (pointing at the world), the room picker,
##                    messages, hunger
##   on demand        the peasants panel (can be folded away), skills, the menu

const CastleData = preload("res://scripts/castle_data.gd")
const JobData = preload("res://scripts/job_data.gd")
const PolicyData = preload("res://scripts/policy_data.gd")
const BoostData = preload("res://scripts/boost_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const OFFLINE_MESSAGE_TIME := 10.0
const TOAST_TIME := 7.0
## How long the reset button waits for the confirming second press.
const RESET_CONFIRM_TIME := 3.0
## The round picture of a part on the build card.
const PREVIEW_RADIUS := 34.0
const PREVIEW_INSIDE := 44.0
const PREVIEW_SKY := Color(0.62, 0.78, 0.86)
const PREVIEW_GROUND := Color(0.45, 0.68, 0.38)

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
@onready var build_button: Button = %BuildButton
@onready var hire_button: Button = %HireButton
@onready var inside_button: Button = %InsideButton
@onready var cow_button: Button = %CowButton
@onready var defend_button: Button = %DefendButton
@onready var skills_button: Button = %SkillsButton
@onready var policies_button: Button = %PoliciesButton
@onready var log_button: Button = %LogButton
@onready var boosts_button: Button = %BoostsButton
@onready var menu_button: Button = %MenuButton
@onready var menu_panel: Panel = %MenuPanel
@onready var night_button: Button = %NightButton
@onready var crown_button: Button = %CrownButton
@onready var reset_button: Button = %ResetButton
@onready var skill_tree: Control = %SkillTree

## Resource id -> the Label on its chip in the top bar.
var _chips := {}
var _mood_label := Label.new()
## Resource id -> the small Label with how much its store holds.
var _caps := {}
## Job id -> {"row", "label", "minus", "plus", "train"}.
var _job_rows := {}
var _toast_tween: Tween
var _reset_armed := false
var _crown_armed := false
var _preview := Control.new()
## Asks which rooms a new storey of the keep should have: [west, east].
var _room_picker := Panel.new()
var _room_choice: Array = CastleData.KEEP_DEFAULT_ROOMS.duplicate()
var _room_info := Label.new()
var _room_build: Button
## Says what the keep's rooms add up to while the mouse is over the keep.
var _keep_card := Panel.new()
var _keep_info := Label.new()
var _castle: Node2D
## The policies: one row each, with a button to turn it on or off.
var _policy_panel := Panel.new()
## Policy id -> its on/off Button.
var _policy_buttons := {}
## The boosts: per boost a button to buy it and what it does.
var _boost_panel := Panel.new()
## Boost id -> {"button": Button, "info": Label}.
var _boost_rows := {}
var _boost_tick := 0.0
## The message log: the last messages, newest first.
var _log_panel := Panel.new()
var _log_text := Label.new()


func _ready() -> void:
	_make_room_picker()
	_make_keep_card()
	_make_policy_panel()
	_make_log_panel()
	_make_boost_panel()
	var theme := UiTheme.build()
	for child in get_children():
		if child is Control:
			child.theme = theme

	for changed: Signal in [
		GameState.resources_changed, GameState.castle_changed, GameState.job_progress_changed,
		GameState.peasants_changed, GameState.trees_changed, GameState.skills_changed,
		GameState.daytime_changed, GameState.raid_started, GameState.raid_progress,
		GameState.policies_changed, GameState.mood_changed, GameState.season_changed,
		GameState.boosts_changed,
	]:
		changed.connect(_refresh)
	_preview.position = Vector2(8, 8)
	_preview.size = Vector2(PREVIEW_RADIUS, PREVIEW_RADIUS) * 2.0
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.draw.connect(_draw_preview)
	build_card.add_child(_preview)
	build_button.toggled.connect(build_hover.set_active)
	build_hover.mode_changed.connect(func() -> void:
		build_button.set_pressed_no_signal(build_hover.active)
		if not build_hover.active:
			_room_picker.hide()
		_refresh_keep_card()
		build_button.text = "Building...\nB to stop" if build_hover.active else "Build (B)")
	hire_button.pressed.connect(GameState.hire_peasant)
	inside_button.pressed.connect(func() -> void: get_tree().call_group("castle", "toggle_all_open"))
	cow_button.pressed.connect(GameState.buy_cow)
	defend_button.pressed.connect(GameState.start_siege)
	skills_button.pressed.connect(skill_tree.show)
	policies_button.toggled.connect(func(on: bool) -> void:
		_policy_panel.visible = on
		_refresh())
	boosts_button.toggled.connect(func(on: bool) -> void:
		_boost_panel.visible = on
		_refresh())
	log_button.toggled.connect(func(on: bool) -> void:
		_log_panel.visible = on
		_refresh_log())
	GameState.announced.connect(func(_text: String) -> void: _refresh_log())
	jobs_toggle.pressed.connect(func() -> void:
		jobs_panel.visible = not jobs_panel.visible
		_refresh())
	menu_button.pressed.connect(func() -> void: menu_panel.visible = not menu_panel.visible)
	night_button.toggled.connect(GameState.set_no_nights)
	reset_button.pressed.connect(_on_reset_pressed)
	crown_button.pressed.connect(_on_crown_pressed)
	build_hover.hovered_changed.connect(func(_part: String) -> void: _refresh_build_card())
	build_hover.rooms_wanted.connect(func(_part: String) -> void: show_room_picker())
	_castle = get_tree().get_first_node_in_group("castle")
	if _castle != null:
		_castle.pointed_changed.connect(func(_part: String) -> void: _refresh_keep_card())
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
		_show_toast("Your three peasants do the work. Hire more and give them jobs with +. To build, press B and click a circle.")


# --- Building the interface ---

## One chip per resource in the top bar: a square in the resource's colour
## and its amount. Hovering a chip says what it is and what it earns.
func _make_chips() -> void:
	for type: String in ["wood", "planks", "stone", "food", "iron", "renown", "legacy"]:
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
		if type in GameState.resources:
			# How much the store holds, small and dim beside the amount.
			var cap := Label.new()
			cap.add_theme_font_size_override("font_size", 8)
			cap.add_theme_color_override("font_color", UiTheme.PARCHMENT_DIM)
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(cap)
			_caps[type] = cap
		resource_bar.add_child(chip)
		_chips[type] = label
	# How happy the peasants are; the tooltip says why. It stands with the
	# defence and the day on the right (see _place_right_labels).
	_mood_label.add_theme_font_size_override("font_size", 12)
	_mood_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_mood_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	defence_label.get_parent().add_child(_mood_label)


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
		label.mouse_filter = Control.MOUSE_FILTER_PASS
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


## The room picker: a row of room kinds for the west room and one for the
## east room of the keep's new storey, what the chosen rooms give, and Build.
func _make_room_picker() -> void:
	_room_picker.position = Vector2(100, 90)
	_room_picker.size = Vector2(440, 170)
	_room_picker.hide()
	add_child(_room_picker)
	var box := VBoxContainer.new()
	box.position = Vector2(8, 5)
	box.size = _room_picker.size - Vector2(16, 10)
	_room_picker.add_child(box)
	var title := Label.new()
	title.text = "A NEW STOREY FOR THE KEEP: choose its rooms"
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(title)
	for side in 2:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "West room" if side == 0 else "East room"
		label.custom_minimum_size.x = 60
		row.add_child(label)
		var group := ButtonGroup.new()
		for kind: String in CastleData.ROOM_PICKS:
			var button := _picker_button(CastleData.ROOMS[kind].name)
			button.toggle_mode = true
			button.button_group = group
			button.button_pressed = kind == _room_choice[side]
			button.tooltip_text = "+ %s\n-  %s" % [CastleData.ROOMS[kind].benefit, CastleData.ROOMS[kind].drawback]
			button.pressed.connect(func() -> void:
				_room_choice[side] = kind
				_refresh_room_picker())
			row.add_child(button)
		box.add_child(row)
	_room_info.add_theme_font_size_override("font_size", 10)
	_room_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_room_info)
	var buttons := HBoxContainer.new()
	_room_build = _picker_button("Build")
	_room_build.pressed.connect(func() -> void:
		GameState.order_part("keep", _room_choice)
		_room_picker.hide()
		_refresh())
	var cancel := _picker_button("Cancel")
	cancel.pressed.connect(func() -> void:
		_room_picker.hide()
		_refresh())
	buttons.add_child(_room_build)
	buttons.add_child(cancel)
	box.add_child(buttons)


## The keep card: a title and one line per kind of room (GameState.keep_summary).
func _make_keep_card() -> void:
	_keep_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep_card.hide()
	add_child(_keep_card)
	_keep_info.position = Vector2(7, 4)
	_keep_info.add_theme_font_size_override("font_size", 10)
	_keep_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep_card.add_child(_keep_info)


## The policy panel, above the bottom bar: per policy a button with its name
## (pressed while it is on) and what it gives and takes.
func _make_policy_panel() -> void:
	_policy_panel.hide()
	add_child(_policy_panel)
	var box := VBoxContainer.new()
	box.position = Vector2(8, 5)
	box.add_theme_constant_override("separation", 4)
	_policy_panel.add_child(box)
	var title := Label.new()
	title.text = "POLICIES: the rules of your castle"
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(title)
	for id: String in PolicyData.POLICIES:
		var info: Dictionary = PolicyData.POLICIES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var button := _picker_button(info.name)
		button.toggle_mode = true
		button.custom_minimum_size.x = 96
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.toggled.connect(func(_on: bool) -> void: GameState.toggle_policy(id))
		row.add_child(button)
		var text := Label.new()
		text.text = "+ %s\n-  %s" % [info.benefit, info.drawback]
		text.add_theme_font_size_override("font_size", 9)
		row.add_child(text)
		box.add_child(row)
		_policy_buttons[id] = button
	_policy_panel.size = box.get_combined_minimum_size() + Vector2(16, 10)
	_policy_panel.position = Vector2(320 - _policy_panel.size.x / 2.0, 318 - _policy_panel.size.y)


## The boost panel, above the bottom bar on the left: per boost a button
## with its name, building and cost, and what it does and for how long.
func _make_boost_panel() -> void:
	_boost_panel.hide()
	add_child(_boost_panel)
	var box := VBoxContainer.new()
	box.position = Vector2(8, 5)
	box.add_theme_constant_override("separation", 3)
	_boost_panel.add_child(box)
	var title := Label.new()
	title.text = "BOOSTS: help bought at your buildings, for a while"
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(title)
	for id: String in BoostData.BOOSTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var button := _picker_button("")
		button.custom_minimum_size.x = 200
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.pressed.connect(func() -> void: GameState.buy_boost(id))
		row.add_child(button)
		var info := Label.new()
		info.add_theme_font_size_override("font_size", 9)
		info.custom_minimum_size.x = 170
		row.add_child(info)
		box.add_child(row)
		_boost_rows[id] = {"button": button, "info": info}
	_refresh_boosts()
	_boost_panel.size = box.get_combined_minimum_size() + Vector2(16, 10)
	_boost_panel.position = Vector2(4, 318 - _boost_panel.size.y)


func _refresh_boosts() -> void:
	for id: String in _boost_rows:
		var boost: Dictionary = BoostData.BOOSTS[id]
		var row: Dictionary = _boost_rows[id]
		var reason := GameState.boost_block_reason(id)
		row.button.text = "%s (%s): %s" % [boost.name, CastleData.PARTS[boost.building].name, _cost_text(boost.cost)]
		row.button.disabled = reason != "" or not GameState.can_afford(boost.cost)
		row.info.text = "%s, for %d min%s" % [boost.text, roundi(boost.lasts / 60.0), "\n" + reason if reason != "" else ""]
		row.info.add_theme_color_override("font_color", UiTheme.GOLD if GameState.boosts.has(id) else UiTheme.PARCHMENT)


func _process(delta: float) -> void:
	if _keep_card.visible:
		_place_keep_card()
	# The time left on boosts going on counts down.
	_boost_tick -= delta
	if _boost_panel.visible and _boost_tick <= 0.0:
		_boost_tick = 0.5
		_refresh_boosts()


## The log panel, above the bottom bar on the right.
func _make_log_panel() -> void:
	_log_panel.hide()
	_log_panel.size = Vector2(320, 190)
	_log_panel.position = Vector2(636 - _log_panel.size.x, 318 - _log_panel.size.y)
	add_child(_log_panel)
	var title := Label.new()
	title.text = "MESSAGES, newest first"
	title.position = Vector2(8, 4)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	_log_panel.add_child(title)
	_log_text.position = Vector2(8, 20)
	_log_text.size = Vector2(_log_panel.size.x - 16, _log_panel.size.y - 24)
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_text.clip_text = true
	_log_text.add_theme_font_size_override("font_size", 9)
	_log_panel.add_child(_log_text)


func _refresh_log() -> void:
	if not _log_panel.visible:
		return
	var lines: PackedStringArray = []
	for i in range(GameState.messages.size() - 1, -1, -1):
		var message: Dictionary = GameState.messages[i]
		lines.append("Day %d   %s" % [message.day, message.text])
	_log_text.text = "\n".join(lines) if not lines.is_empty() else "Nothing has happened yet."


func _picker_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 10)
	UiTheme.make_compact(button)
	return button


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

	night_button.set_pressed_no_signal(GameState.no_nights)
	night_button.text = "Nights: off (testing)" if GameState.no_nights else "Nights: on"
	var gain := GameState.legacy_gain()
	crown_button.disabled = gain <= 0
	if _crown_armed:
		crown_button.text = "Start over? Press again"
	elif gain > 0:
		crown_button.text = "Pass the crown (+%d legacy)" % gain
	else:
		crown_button.text = "Pass the crown (needs rank %d)" % GameState.LEGACY_MIN_RANK
	_refresh_room_picker()
	_refresh_build_card()
	_refresh_keep_card()
	var on_count := 0
	for id: String in _policy_buttons:
		var on: bool = id in GameState.policies
		_policy_buttons[id].set_pressed_no_signal(on)
		_policy_buttons[id].text = "%s: %s" % [PolicyData.POLICIES[id].name, "on" if on else "off"]
		on_count += 1 if on else 0
	policies_button.text = "Policies\n%d on" % on_count if on_count > 0 else "Policies"
	boosts_button.text = "Boosts\n%d on" % GameState.boosts.size() if not GameState.boosts.is_empty() else "Boosts"
	if _boost_panel.visible:
		_refresh_boosts()


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
				# Iron only matters once there is a mine, planks once there is a sawmill.
				chip.visible = (type != "iron" or GameState.part_levels.mine > 0) and (type != "planks" or GameState.part_levels.sawmill > 0)
				var full: bool = GameState.store_full(type)
				label.text = str(GameState.resources[type])
				_caps[type].text = "/%d" % GameState.store_capacity()
				label.add_theme_color_override("font_color", UiTheme.BAD if full else UiTheme.PARCHMENT)
				chip.tooltip_text = "%s: +%.1f a second (averaged over a day)\nThe store holds %d%s. A bigger stockhouse holds more." % [
					type.capitalize(), GameState.income_rate[type], GameState.store_capacity(), ": FULL, the rest is lost" if full else ""]

	var mood := roundi(GameState.happiness)
	_mood_label.text = "Mood %d" % mood
	var mood_color := UiTheme.PARCHMENT
	if GameState.happiness > GameState.MOOD_HAPPY:
		mood_color = UiTheme.GOLD
	elif GameState.happiness < GameState.MOOD_UNHAPPY:
		mood_color = UiTheme.BAD
	_mood_label.add_theme_color_override("font_color", mood_color)
	var why: PackedStringArray = ["Happiness %d of 100, heading for %d. Everyone works %+d%% for it." % [
		mood, roundi(GameState.happiness_target()), roundi(GameState.morale_bonus() * 100)]]
	for part: Array in GameState.happiness_parts():
		why.append("  %s: %+d" % [part[0], roundi(part[1])])
	why.append("Happy peasants (over %d) may sing at work; unhappy ones (under %d) may strike." % [
		roundi(GameState.MOOD_HAPPY), roundi(GameState.MOOD_UNHAPPY)])
	_mood_label.tooltip_text = "\n".join(why)

	defence_label.text = "Defence %d" % GameState.total_defence()
	day_label.text = "%s, day %d%s%s" % [
		GameState.season().name, GameState.day, ", night" if GameState.is_night() else "",
		"" if GameState.fed else "  HUNGRY"]
	day_label.add_theme_color_override("font_color", UiTheme.PARCHMENT if GameState.fed else UiTheme.BAD)
	day_label.tooltip_text = "%s (%d more day%s): %s.\nPeasants eat %d food at dawn. Without enough they work at %d%% for the day, and are unhappy." % [
		GameState.season().name, GameState.season_days_left(), "" if GameState.season_days_left() == 1 else "s",
		GameState.season().text.to_lower(), GameState.food_needed(), roundi(GameState.HUNGRY_WORK_MULT * 100)]

	_place_right_labels()

	var quest := GameState.current_quest()
	goal_label.text = "Goal: %s  (+%d renown)" % [quest.text, quest.renown] if not quest.is_empty() else "All goals reached"

	if GameState.raid_incoming:
		raid_label.text = "Raid! %d raiders left" % GameState.raiders_left
	else:
		raid_label.text = "Raid on day %d: %d raiders" % [GameState.next_raid_day(), GameState.raid_size()]
	raid_label.add_theme_color_override("font_color", UiTheme.BAD if GameState.raid_incoming else UiTheme.PARCHMENT)
	rank_label.text = "Castle rank %d  (%d of %d levels to the next)" % [
		GameState.castle_rank(), GameState.total_levels(), GameState.levels_for_next_rank()]


## The day, the defence and the mood stand at the right of the top bar,
## each as wide as its text, so they never run into each other.
func _place_right_labels() -> void:
	var right := 634.0
	for label: Label in [day_label, defence_label, _mood_label]:
		var width := label.get_minimum_size().x
		label.size = Vector2(width, 18)
		label.position = Vector2(right - width, 1)
		right -= width + 12.0


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
		# Who is doing the job, by name.
		var names: PackedStringArray = []
		for someone: Dictionary in GameState.people:
			if someone.job == id:
				names.append(GameState.person_title(someone) + (" (trained)" if someone.trained else ""))
		row.label.tooltip_text = "Nobody yet" if names.is_empty() else "\n".join(names)
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


## Opens the room picker for the keep's next storey.
func show_room_picker() -> void:
	_room_picker.show()
	_refresh()


## What the chosen rooms give and what the storey costs. The picker closes
## by itself if the storey can no longer be ordered.
func _refresh_room_picker() -> void:
	if not _room_picker.visible:
		return
	if not GameState.needs_room_choice("keep") or GameState.part_block_reason("keep") != "":
		_room_picker.hide()
		return
	var cost := GameState.part_cost("keep")
	var said: PackedStringArray = []
	for side in 2:
		var room: Dictionary = CastleData.ROOMS[_room_choice[side]]
		said.append("%s: + %s%s" % ["West" if side == 0 else "East", room.benefit,
			"\n        -  " + room.drawback if room.drawback != "" else ""])
	said.append("Cost: %s" % _cost_text(cost))
	_room_info.text = "\n".join(said)
	_room_build.disabled = not GameState.can_afford(cost)


## The card for the castle part or village building under the mouse: what
## its next level costs, what it gives, what it takes, and whether a click
## would build it.
func _refresh_build_card() -> void:
	var id: String = build_hover.hovered
	build_card.visible = id != "" and not skill_tree.visible and not _room_picker.visible
	if id == "":
		return
	var part: Dictionary = CastleData.PARTS[id]
	var level: int = GameState.part_levels[id]
	var lines: PackedStringArray = ["%s   Lv %d > %d" % [part.name.to_upper(), level, level + 1]]
	lines.append("Cost: %s" % _cost_text(GameState.part_cost(id)))
	lines.append("+ %s" % part.benefit)
	if part.drawback != "":
		lines.append("-  %s" % part.drawback)
	if id == "keep" and level > 0:
		lines.append("Rooms now:")
		for line in GameState.keep_summary():
			lines.append("  " + line)
	var reason := GameState.part_block_reason(id)
	if id == GameState.job_part:
		lines.append("Being built: %d%%" % (GameState.job_fraction() * 100))
	elif reason != "":
		lines.append(reason)
	elif not GameState.can_afford(GameState.part_cost(id)):
		lines.append("Not enough materials yet")
	elif GameState.needs_room_choice(id):
		lines.append("Click to choose its rooms")
	else:
		lines.append("Click to build")
	build_card_label.text = "\n".join(lines)
	_preview.queue_redraw()
	# Keep the card beside the mouse, and on screen.
	var mouse := build_card.get_viewport().get_mouse_position()
	build_card_label.size.y = build_card_label.get_minimum_size().y
	build_card.size.y = maxf(build_card_label.size.y + 12, PREVIEW_RADIUS * 2.0 + 16)
	build_card.position = Vector2(
		clampf(mouse.x + 18, 4, 640 - build_card.size.x - 4),
		clampf(mouse.y - build_card.size.y - 8, 40, 316 - build_card.size.y))


## Shows what the keep's rooms add up to while the mouse is over the keep
## (outside build mode: there the build card says it).
func _refresh_keep_card() -> void:
	var show_it: bool = _castle != null and _castle.pointed == "keep" and not build_hover.active \
			and not skill_tree.visible and not _room_picker.visible and GameState.part_levels.keep > 0
	_keep_card.visible = show_it
	if not show_it:
		return
	var lines: PackedStringArray = ["THE KEEP'S ROOMS"]
	lines.append_array(GameState.keep_summary())
	_keep_info.text = "\n".join(lines)
	_keep_card.size = _keep_info.get_minimum_size() + Vector2(14, 8)
	_place_keep_card()


## Beside the mouse, and on screen.
func _place_keep_card() -> void:
	var mouse := _keep_card.get_viewport().get_mouse_position()
	_keep_card.position = Vector2(
		clampf(mouse.x + 14, 4, 640 - _keep_card.size.x - 4),
		clampf(mouse.y - _keep_card.size.y - 8, 40, 316 - _keep_card.size.y))


## The round picture on the build card: the part as it will look at its next
## level, shrunk to fit. Very wide parts show only a piece of themselves.
func _draw_preview() -> void:
	var id: String = build_hover.hovered
	if id == "":
		return
	var centre := Vector2(PREVIEW_RADIUS, PREVIEW_RADIUS)
	_preview.draw_circle(centre, PREVIEW_RADIUS, PREVIEW_SKY)
	var shapes := CastleData.shapes(id, GameState.part_levels[id] + 1)
	# Look at the first main body, so parts in several pieces show one of them.
	var focus: Rect2 = shapes[0][0]
	for shape: Array in shapes:
		if CastleData.is_body(shape[0]):
			focus = shape[0]
			break
	var tall := maxf(-CastleData.top_y(id, GameState.part_levels[id] + 1), 8.0)
	var fit := minf(PREVIEW_INSIDE / maxf(tall, minf(focus.size.x, tall * 1.2)), 2.0)
	var window := Rect2(centre - Vector2(PREVIEW_INSIDE, PREVIEW_INSIDE) / 2.0, Vector2(PREVIEW_INSIDE, PREVIEW_INSIDE))
	var ground := window.end.y
	_preview.draw_rect(Rect2(window.position.x, ground, window.size.x, 3), PREVIEW_GROUND)
	for shape: Array in shapes:
		var area: Rect2 = shape[0]
		var drawn := Rect2(
			centre.x + (area.position.x - focus.get_center().x) * fit, ground + area.position.y * fit,
			maxf(area.size.x * fit, 1.0), maxf(area.size.y * fit, 1.0)).intersection(window)
		if drawn.has_area():
			_preview.draw_rect(drawn, shape[1])
	_preview.draw_arc(centre, PREVIEW_RADIUS, 0.0, TAU, 40, UiTheme.GOLD, 2.0)


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
