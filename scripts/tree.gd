extends "res://scripts/gather_spot.gd"
## A tree: holds a limited amount of wood, and regrows after it is used up.
## More trees means more wood per minute, which is why planting matters.

const BASE_WOOD := 8
const GROW_TIME := 12.0

var wood_left := BASE_WOOD
## 0 = just planted (or chopped down), 1 = fully grown.
var growth := 1.0


func _init() -> void:
	resource_type = "wood"
	size = Vector2(22, 50)


func start_as_sapling() -> void:
	growth = 0.0
	wood_left = 0


func max_wood() -> int:
	return BASE_WOOD + GameState.tree_bonus_wood()


func can_gather() -> bool:
	return growth >= 1.0 and wood_left > 0


func take() -> bool:
	if not can_gather():
		return false
	wood_left -= 1
	if wood_left == 0:
		growth = 0.0
	queue_redraw()
	return true


func _process(delta: float) -> void:
	if growth < 1.0:
		growth = minf(growth + delta * GameState.tree_grow_mult() / GROW_TIME, 1.0)
		if growth >= 1.0:
			wood_left = max_wood()
		queue_redraw()


func _draw() -> void:
	# The tree is drawn smaller while it grows; the canopy thins as wood is taken.
	var s := lerpf(0.25, 1.0, growth)
	var w := size.x * s
	var h := size.y * s
	var fullness := 1.0 if growth < 1.0 else lerpf(0.55, 1.0, float(wood_left) / max_wood())
	var canopy := Color(0.45, 0.70, 0.40) if growth < 1.0 else Color(0.20, 0.50, 0.30)
	draw_rect(Rect2(-maxf(1.0, 2.0 * s), -h * 0.45, maxf(2.0, 4.0 * s), h * 0.45), Color(0.45, 0.30, 0.18))
	draw_rect(Rect2(-w * fullness / 2, -h, w * fullness, h * 0.7), canopy)
