extends Control
## The skill tree screen: one button per skill in SkillData.SKILLS, laid out
## by each skill's "cell", with lines from every skill to the one it requires.
## It covers the whole screen while open, so clicks don't reach the game.

const SkillData = preload("res://scripts/skill_data.gd")
const ORIGIN := Vector2(16, 66)
const CELL := Vector2(96, 46)
## Extra space between the peasant columns (0-2) and the builder columns (3-5).
const BRANCH_GAP := 30.0
const NODE_SIZE := Vector2(90, 34)
const BACKGROUND := Color(0.13, 0.14, 0.20, 0.96)
const LINE_LOCKED := Color(0.40, 0.42, 0.50)
const LINE_OWNED := Color(0.55, 0.80, 0.45)
const OWNED_TEXT := Color(0.60, 1.0, 0.55)
const BIG_TEXT := Color(1.0, 0.85, 0.40)

@onready var renown_label: Label = %SkillRenownLabel
@onready var info_label: Label = %SkillInfoLabel
@onready var close_button: Button = %SkillCloseButton

## Skill id -> its button.
var _buttons := {}


func _ready() -> void:
	hide()
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
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	for id: String in SkillData.SKILLS:
		var skill: Dictionary = SkillData.SKILLS[id]
		if skill.requires == "":
			continue
		var from := _cell_position(SkillData.SKILLS[skill.requires].cell) + NODE_SIZE / 2
		var to := _cell_position(skill.cell) + NODE_SIZE / 2
		draw_line(from, to, LINE_OWNED if skill.requires in GameState.skills else LINE_LOCKED, 2.0)


func _cell_position(cell: Vector2i) -> Vector2:
	var gap := BRANCH_GAP if cell.x >= 3 else 0.0
	return ORIGIN + Vector2(cell.x * CELL.x + gap, cell.y * CELL.y)


func _refresh() -> void:
	renown_label.text = "Renown: %d" % GameState.renown
	for id: String in _buttons:
		var skill: Dictionary = SkillData.SKILLS[id]
		var button: Button = _buttons[id]
		var reason := GameState.skill_block_reason(id)
		var owned := id in GameState.skills
		button.text = "%s\n%s" % [skill.name, "Owned" if owned else "%d renown" % skill.cost]
		button.disabled = reason != ""
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
