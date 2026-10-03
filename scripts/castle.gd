extends Node2D
## Draws the castle from GameState's part levels. The part being built shows
## a faint outline of its next level, which fills in upwards as builders work.

const CastleData = preload("res://scripts/castle_data.gd")
const PREVIEW_ALPHA := 0.25


func _ready() -> void:
	GameState.castle_changed.connect(queue_redraw)
	GameState.job_progress_changed.connect(queue_redraw)


func _draw() -> void:
	for part: String in CastleData.DRAW_ORDER:
		var level: int = GameState.part_levels[part]
		_draw_shapes(CastleData.shapes(part, level), 1.0, -INF)
		if part == GameState.job_part:
			var next := CastleData.shapes(part, level + 1)
			_draw_shapes(next, PREVIEW_ALPHA, -INF)
			_draw_shapes(next, 1.0, built_top_y())


## How high the part under construction has been built so far.
func built_top_y() -> float:
	var part := GameState.job_part
	var level: int = GameState.part_levels[part]
	return lerpf(CastleData.top_y(part, level), CastleData.top_y(part, level + 1), GameState.job_fraction())


## Draws shapes, but only the part of each below top_y (-INF for everything).
func _draw_shapes(shapes: Array, alpha: float, top_y: float) -> void:
	for shape: Array in shapes:
		var r: Rect2 = shape[0]
		var top := maxf(r.position.y, top_y)
		if top < r.end.y:
			draw_rect(Rect2(r.position.x, top, r.size.x, r.end.y - top), Color(shape[1], alpha))
