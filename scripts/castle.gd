extends Node2D
## Draws the castle from GameState: every built piece, plus a faint
## preview of the next piece so the player sees what they are saving for.

const CastleData = preload("res://scripts/castle_data.gd")


func _ready() -> void:
	GameState.castle_changed.connect(queue_redraw)


func _draw() -> void:
	var built: Array = CastleData.PIECES.slice(0, GameState.built_count)
	for layer in [-1, 0, 1]:
		for piece: Dictionary in built:
			if piece.layer == layer:
				_draw_piece(piece, 1.0)
	var next: Dictionary = GameState.next_piece()
	if not next.is_empty():
		_draw_piece(next, 0.25)


func _draw_piece(piece: Dictionary, alpha: float) -> void:
	for r: Rect2 in piece.rects:
		draw_rect(r, Color(piece.color, alpha))
	for r: Rect2 in piece.get("details", []):
		draw_rect(r, Color(piece.detail_color, alpha))
