extends Node2D
## Draws the castle from GameState's part levels. The part being built shows
## a faint outline of its next level, which fills in upwards as builders work,
## with scaffolding around it and stones hoisted up by rope as they arrive.

const CastleData = preload("res://scripts/castle_data.gd")
const PREVIEW_ALPHA := 0.25
const SCAFFOLD_COLOR := Color(0.48, 0.32, 0.20)
const ROPE_COLOR := Color(0.75, 0.68, 0.50)
const PLANK_SPACING := 18.0
## Seconds for a hoisted stone to reach the top.
const HOIST_TIME := 1.2
## The most stones shown waiting in the pile at the site.
const MAX_PILE := 6

## One entry per stone on its way up: seconds since it left the ground.
var _hoists: Array[float] = []


func _ready() -> void:
	GameState.castle_changed.connect(queue_redraw)
	GameState.job_progress_changed.connect(queue_redraw)
	GameState.job_delivered.connect(_on_job_delivered)


func _process(delta: float) -> void:
	if _hoists.is_empty():
		return
	for i in _hoists.size():
		_hoists[i] += delta
	_hoists = _hoists.filter(func(age: float) -> bool: return age < HOIST_TIME)
	queue_redraw()


func _draw() -> void:
	for part: String in CastleData.DRAW_ORDER:
		var level: int = GameState.part_levels[part]
		_draw_shapes(CastleData.shapes(part, level), 1.0, -INF)
		if part == GameState.job_part:
			var next := CastleData.shapes(part, level + 1)
			_draw_shapes(next, PREVIEW_ALPHA, -INF)
			_draw_shapes(next, 1.0, built_top_y())
	if GameState.job_part != "":
		_draw_scaffold()
		_draw_pile()
		_draw_hoists()


## How high the part under construction has been built so far.
func built_top_y() -> float:
	var part := GameState.job_part
	var level: int = GameState.part_levels[part]
	return lerpf(CastleData.top_y(part, level), CastleData.top_y(part, level + 1), GameState.job_fraction())


func _on_job_delivered() -> void:
	_hoists.append(0.0)
	queue_redraw()


## Draws shapes, but only the part of each below top_y (-INF for everything).
func _draw_shapes(shapes: Array, alpha: float, top_y: float) -> void:
	for shape: Array in shapes:
		var r: Rect2 = shape[0]
		var top := maxf(r.position.y, top_y)
		if top < r.end.y:
			draw_rect(Rect2(r.position.x, top, r.size.x, r.end.y - top), Color(shape[1], alpha))


## Poles and planks around each section of the part being built. The scaffold
## stands a little above the stonework, so it climbs as the part does.
func _draw_scaffold() -> void:
	var top := built_top_y() - 10.0
	for section: Array in CastleData.PARTS[GameState.job_part].scaffold:
		var left: float = section[0] - 3.0
		var right: float = section[1] + 1.0
		draw_rect(Rect2(left, top, 2, -top), SCAFFOLD_COLOR)
		draw_rect(Rect2(right, top, 2, -top), SCAFFOLD_COLOR)
		var y := -PLANK_SPACING
		while y > top:
			draw_rect(Rect2(left, y, right - left + 2, 1), SCAFFOLD_COLOR)
			y -= PLANK_SPACING
		draw_rect(Rect2(left, top, right - left + 2, 2), SCAFFOLD_COLOR)


## Stones that have been delivered but not hammered in yet, stacked at the site.
func _draw_pile() -> void:
	var waiting := float(GameState.job_hauled) / GameState.job_units - GameState.job_fraction()
	var x: float = _hoist_x() + 8.0
	for i in clampi(ceili(waiting * MAX_PILE * 2.0), 0, MAX_PILE):
		draw_rect(Rect2(x + (i % 3) * 6 + (i / 3) * 3, -4 - (i / 3) * 4, 5, 4), CastleData.STONE_LIGHT)


## A beam sticking out from the top of the scaffold, with stones rising on a rope.
func _draw_hoists() -> void:
	var x := _hoist_x()
	var top := built_top_y() - 10.0
	draw_rect(Rect2(x - 2, top, 8, 2), SCAFFOLD_COLOR)
	for age in _hoists:
		var y := lerpf(-4.0, top + 8.0, age / HOIST_TIME)
		draw_rect(Rect2(x, top + 2, 1, y - top - 2), ROPE_COLOR)
		draw_rect(Rect2(x - 3, y, 7, 5), CastleData.STONE_LIGHT)


## Stones go up just left of the first scaffold section.
func _hoist_x() -> float:
	var part: Dictionary = CastleData.PARTS[GameState.job_part]
	if part.scaffold.is_empty():
		return part.site_x - 16.0
	return part.scaffold[0][0] - 8.0
