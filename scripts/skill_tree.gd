extends Control
## The skill tree screen: a map of square nodes joined by lines, growing out
## from the centre. Drag to look around, hover a node to read it, click to
## buy a level. Everything is drawn in _draw from SkillData.SKILLS, so new
## skills only need an entry there. It covers the whole screen while open.

const SkillData = preload("res://scripts/skill_data.gd")
## Pixels between neighbouring cells, and the size of a node.
const CELL := 62.0
const NODE := 34.0
const BACKGROUND := Color(0.11, 0.12, 0.16)
const STAR := Color(0.30, 0.42, 0.40)
const LINE_DIM := Color(0.27, 0.31, 0.38)
const LINE_LIT := Color(0.92, 0.94, 0.96)
const NODE_FILL := Color(0.18, 0.21, 0.28)
const HIDDEN_FILL := Color(0.15, 0.17, 0.22)
## Border colours: can buy now, bought some, bought all, a big unlock.
const BORDER_LOCKED := Color(0.36, 0.42, 0.52)
const BORDER_READY := Color(0.95, 0.96, 1.0)
const BORDER_OWNED := Color(0.62, 0.85, 0.45)
const BORDER_BIG := Color(1.0, 0.78, 0.30)
const TEXT := Color(0.92, 0.93, 0.96)
const TEXT_DIM := Color(0.55, 0.58, 0.66)
const CARD_FILL := Color(0.08, 0.10, 0.15, 0.97)
const CARD_SIZE := Vector2(200, 104)

@onready var renown_label: Label = %SkillRenownLabel
@onready var close_button: Button = %SkillCloseButton

## Where the centre of the map is on screen. Dragging changes it.
var _origin := Vector2(320, 190)
var _hovered := ""
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	hide()
	close_button.pressed.connect(hide)
	GameState.skills_changed.connect(_refresh)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask != 0:
			_origin += event.relative
		_hovered = _skill_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _skill_at(event.position)
		if id != "" and _is_revealed(id):
			GameState.buy_skill(id)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	_draw_stars()
	# Lines first, so the nodes sit on top of them.
	for id: String in SkillData.SKILLS:
		if _is_shown(id):
			var parent: String = SkillData.SKILLS[id].requires
			var from := _origin if parent == "" else _center(parent)
			var lit := GameState.skill_level(id) > 0
			draw_line(from, _center(id), LINE_LIT if lit else LINE_DIM, 3.0 if lit else 2.0)
	# The centre: your settlement, where every arm starts.
	draw_rect(Rect2(_origin - Vector2(NODE, NODE) / 2, Vector2(NODE, NODE)), BORDER_OWNED)
	draw_rect(Rect2(_origin - Vector2(NODE - 6, NODE - 6) / 2, Vector2(NODE - 6, NODE - 6)), NODE_FILL)
	_draw_centered("Home", _origin + Vector2(0, 4), 10, TEXT)
	for id: String in SkillData.SKILLS:
		if _is_shown(id):
			_draw_node(id)
	if _hovered != "" and _is_shown(_hovered):
		_draw_card(_hovered)


## A skill is shown once the skill it requires is shown and revealed, and it
## is revealed (not a "?") once the skill it requires has been bought.
func _is_shown(id: String) -> bool:
	var parent: String = SkillData.SKILLS[id].requires
	return parent == "" or _is_revealed(parent)


func _is_revealed(id: String) -> bool:
	var parent: String = SkillData.SKILLS[id].requires
	return parent == "" or GameState.skill_level(parent) > 0


func _center(id: String) -> Vector2:
	return _origin + Vector2(SkillData.SKILLS[id].cell) * CELL


func _skill_at(point: Vector2) -> String:
	for id: String in SkillData.SKILLS:
		if _is_shown(id) and Rect2(_center(id) - Vector2(NODE, NODE) / 2, Vector2(NODE, NODE)).has_point(point):
			return id
	return ""


func _draw_stars() -> void:
	# The same scattering every time: positions come from a fixed seed.
	var random := RandomNumberGenerator.new()
	random.seed = 7
	for i in 90:
		var star := Vector2(random.randf_range(-700, 700), random.randf_range(-500, 500)) + _origin * 0.5
		draw_rect(Rect2(star, Vector2(2, 2)), STAR)


func _draw_node(id: String) -> void:
	var skill: Dictionary = SkillData.SKILLS[id]
	var level := GameState.skill_level(id)
	var center := _center(id)
	var rect := Rect2(center - Vector2(NODE, NODE) / 2, Vector2(NODE, NODE))
	if not _is_revealed(id):
		draw_rect(rect, BORDER_LOCKED.darkened(0.3))
		draw_rect(rect.grow(-2), HIDDEN_FILL)
		_draw_centered("?", center + Vector2(0, 6), 16, TEXT_DIM)
		return

	var border := BORDER_LOCKED
	if level >= skill.max_level:
		border = BORDER_OWNED
	elif GameState.skill_block_reason(id) == "":
		border = BORDER_BIG if skill.get("big", false) else BORDER_READY
	elif level > 0:
		border = BORDER_OWNED.darkened(0.25)
	elif skill.get("big", false):
		border = BORDER_BIG.darkened(0.45)
	if id == _hovered:
		draw_rect(rect.grow(3), Color(border, 0.35))
	draw_rect(rect, border)
	draw_rect(rect.grow(-3 if skill.get("big", false) else -2), NODE_FILL)
	_draw_centered(skill.icon, center + Vector2(0, 3), 12, TEXT if level > 0 else TEXT_DIM)
	# One pip per level, filled for the levels owned.
	var pips: int = skill.max_level
	for i in pips:
		var x := center.x - pips * 2.5 + i * 5.0
		draw_rect(Rect2(x, center.y + 9, 4, 3), BORDER_OWNED if i < level else LINE_DIM)


## The card that pops out next to the node under the mouse.
func _draw_card(id: String) -> void:
	var skill: Dictionary = SkillData.SKILLS[id]
	var level := GameState.skill_level(id)
	var revealed := _is_revealed(id)
	var corner := _center(id) + Vector2(NODE / 2 + 8, -CARD_SIZE.y / 2)
	if corner.x + CARD_SIZE.x > size.x:
		corner.x = _center(id).x - NODE / 2 - 8 - CARD_SIZE.x
	corner.y = clampf(corner.y, 4.0, size.y - CARD_SIZE.y - 4.0)
	draw_rect(Rect2(corner, CARD_SIZE), CARD_FILL)
	draw_rect(Rect2(corner, CARD_SIZE), LINE_DIM, false, 1.0)

	var title: String = skill.name.to_upper() if revealed else "???"
	_draw_centered(title, corner + Vector2(CARD_SIZE.x / 2, 16), 11, TEXT)
	draw_line(corner + Vector2(8, 22), corner + Vector2(CARD_SIZE.x - 8, 22), LINE_DIM)
	var body: String = skill.text if revealed else "Buy %s to find out what this is." % SkillData.SKILLS[skill.requires].name
	draw_multiline_string(_font, corner + Vector2(8, 36), body, HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x - 16, 10, 3, TEXT)
	_draw_centered("LVL: %d / %d" % [level, skill.max_level], corner + Vector2(CARD_SIZE.x / 2, 80), 10, TEXT_DIM)

	# The cost bar: green if there is enough renown, like a filled meter.
	var bar := Rect2(corner + Vector2(8, 86), Vector2(CARD_SIZE.x - 16, 13))
	if level >= skill.max_level:
		draw_rect(bar, BORDER_OWNED.darkened(0.5))
		_draw_centered("Fully learned", bar.get_center() + Vector2(0, 4), 10, TEXT)
	else:
		var cost := GameState.skill_cost(id)
		draw_rect(bar, Color(0.20, 0.36, 0.22) if GameState.renown >= cost else Color(0.36, 0.20, 0.20))
		_draw_centered("Renown  %d / %d" % [GameState.renown, cost], bar.get_center() + Vector2(0, 4), 10, TEXT)


func _draw_centered(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _refresh() -> void:
	renown_label.text = "Renown: %d" % GameState.renown
	queue_redraw()
