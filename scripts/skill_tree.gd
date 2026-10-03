extends Control
## The skill tree screen: a tab per branch in SkillData.BRANCHES and one
## button per skill, laid out by each skill's "cell", with lines from every
## skill to the one it requires. It covers the whole screen while open.

const SkillData = preload("res://scripts/skill_data.gd")
const ORIGIN := Vector2(30, 66)
const CELL := Vector2(98, 44)
const NODE_SIZE := Vector2(90, 34)
const BACKGROUND := Color(0.13, 0.14, 0.20, 0.96)
const LINE_LOCKED := Color(0.40, 0.42, 0.50)
const LINE_OWNED := Color(0.55, 0.80, 0.45)
const OWNED_TEXT := Color(0.60, 1.0, 0.55)
const BIG_TEXT := Color(1.0, 0.85, 0.40)

@onready var renown_label: Label = %SkillRenownLabel
@onready var info_label: Label = %SkillInfoLabel
@onready var close_button: Button = %SkillCloseButton
@onready var tabs_box: HBoxContainer = %SkillTabs

var _branch := "peasant"
## Skill id -> its button, and branch id -> its tab button.
var _buttons := {}
var _tabs := {}


func _ready() -> void:
	hide()
	for branch: String in SkillData.BRANCHES:
		var tab := Button.new()
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(110, 0)
		tab.add_theme_font_size_override("font_size", 12)
		tab.pressed.connect(_show_branch.bind(branch))
		tabs_box.add_child(tab)
		_tabs[branch] = tab
	for id: String in SkillData.SKILLS:
		var skill: Dictionary = SkillData.SKILLS[id]
		var button := Button.new()
		button.position = _cell_position(skill.cell)
		button.size = NODE_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 10)
		if skill.get("big", false):
			button.add_theme_color_override("font_color", BIG_TEXT)
			button.add_theme_color_override("font_disabled_color", Color(BIG_TEXT, 0.6))
		button.pressed.connect(GameState.buy_skill.bind(id))
		button.mouse_entered.connect(_show_info.bind(id))
		add_child(button)
		_buttons[id] = button
	close_button.pressed.connect(hide)
	GameState.skills_changed.connect(_refresh)
	_show_branch(_branch)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	for id: String in SkillData.SKILLS:
		var skill: Dictionary = SkillData.SKILLS[id]
		if skill.branch != _branch or skill.requires == "":
			continue
		var from := _cell_position(SkillData.SKILLS[skill.requires].cell) + NODE_SIZE / 2
		var to := _cell_position(skill.cell) + NODE_SIZE / 2
		draw_line(from, to, LINE_OWNED if skill.requires in GameState.skills else LINE_LOCKED, 2.0)


func _cell_position(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL


func _show_branch(branch: String) -> void:
	_branch = branch
	_refresh()


func _refresh() -> void:
	renown_label.text = "Renown: %d" % GameState.renown
	for branch: String in _tabs:
		var owned := 0
		var total := 0
		for id: String in SkillData.SKILLS:
			if SkillData.SKILLS[id].branch == branch:
				total += 1
				owned += int(id in GameState.skills)
		_tabs[branch].text = "%s %d/%d" % [SkillData.BRANCHES[branch], owned, total]
		_tabs[branch].button_pressed = branch == _branch
	for id: String in _buttons:
		var skill: Dictionary = SkillData.SKILLS[id]
		var button: Button = _buttons[id]
		var owned := id in GameState.skills
		button.visible = skill.branch == _branch
		button.text = "%s\n%s" % [skill.name, "Owned" if owned else "%d renown" % skill.cost]
		button.disabled = GameState.skill_block_reason(id) != ""
		if owned:
			# Owned skills can't be clicked, but should still read clearly.
			button.add_theme_color_override("font_disabled_color", OWNED_TEXT)
	queue_redraw()


func _show_info(id: String) -> void:
	var skill: Dictionary = SkillData.SKILLS[id]
	var reason := GameState.skill_block_reason(id)
	info_label.text = "%s (%d renown): %s" % [skill.name, skill.cost, skill.text]
	if reason != "":
		info_label.text += "  [%s]" % reason
