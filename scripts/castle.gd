extends Node2D
## Draws the castle from GameState: every finished piece, a faint preview of
## the next piece (which fills in from the ground up while it is being built),
## and the builders standing in front.

const CastleData = preload("res://scripts/castle_data.gd")
const PREVIEW_ALPHA := 0.25
const MAX_BUILDERS_SHOWN := 16


func _ready() -> void:
	GameState.castle_changed.connect(queue_redraw)
	GameState.builders_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	# Redraw every frame while building, for the rising piece and hammering.
	if GameState.building:
		queue_redraw()


func _draw() -> void:
	var built: Array = CastleData.PIECES.slice(0, GameState.built_count)
	var next: Dictionary = GameState.next_piece()
	for layer in [-1, 0, 1]:
		for piece: Dictionary in built:
			if piece.layer == layer:
				_draw_piece(piece, 1.0, -INF)
		if not next.is_empty() and next.layer == layer:
			_draw_piece(next, PREVIEW_ALPHA, -INF)
			if GameState.building:
				_draw_piece(next, 1.0, _cut_y(next, GameState.build_fraction()))
	_draw_builders()


## Draws a piece, but only the part below top_y (use -INF for the whole piece).
func _draw_piece(piece: Dictionary, alpha: float, top_y: float) -> void:
	for r: Rect2 in piece.rects:
		_draw_clipped(r, Color(piece.color, alpha), top_y)
	for r: Rect2 in piece.get("details", []):
		_draw_clipped(r, Color(piece.detail_color, alpha), top_y)


func _draw_clipped(r: Rect2, color: Color, top_y: float) -> void:
	var top := maxf(r.position.y, top_y)
	if top < r.end.y:
		draw_rect(Rect2(r.position.x, top, r.size.x, r.end.y - top), color)


## The height a piece has been built up to, for a fraction from 0 to 1.
func _cut_y(piece: Dictionary, fraction: float) -> float:
	var top := INF
	var bottom := -INF
	for r: Rect2 in piece.rects + piece.get("details", []):
		top = minf(top, r.position.y)
		bottom = maxf(bottom, r.end.y)
	return lerpf(bottom, top, fraction)


func _draw_builders() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for i in mini(GameState.builders, MAX_BUILDERS_SHOWN):
		var x := -116.0 + i * 15.0
		# Builders bob up and down while they hammer.
		var y := -absf(sin(time * 9.0 + i * 1.7)) * 2.0 if GameState.building else 0.0
		draw_rect(Rect2(x - 3, y - 10, 6, 10), Color(0.80, 0.52, 0.20))
		draw_rect(Rect2(x - 2, y - 14, 4, 4), Color(0.93, 0.76, 0.62))
