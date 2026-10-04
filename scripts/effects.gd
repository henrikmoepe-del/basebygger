extends Node2D
## Small flying bits: wood chips, stone chips, dust. Anything in the world can
## ask for a burst with
##     get_tree().call_group("effects", "burst", where, color, how_many)
## Each bit is a tiny square that flies up, falls, and fades.

const GRAVITY := 260.0
const LIFE := 0.5

## Each bit: {"pos": Vector2, "vel": Vector2, "color": Color, "age": float}
var _bits: Array[Dictionary] = []


func _ready() -> void:
	# In front of the castle and everyone on it.
	z_index = 5
	add_to_group("effects")


func _process(delta: float) -> void:
	if _bits.is_empty():
		return
	for bit in _bits:
		bit.age += delta
		bit.vel.y += GRAVITY * delta
		bit.pos += bit.vel * delta
	_bits = _bits.filter(func(bit: Dictionary) -> bool: return bit.age < LIFE)
	queue_redraw()


func _draw() -> void:
	for bit in _bits:
		var fade: float = 1.0 - bit.age / LIFE
		draw_rect(Rect2(to_local(bit.pos), Vector2(2, 2)), Color(bit.color, fade))


## where is a position in the world (global coordinates).
func burst(where: Vector2, color: Color, count: int) -> void:
	for i in count:
		_bits.append({
			"pos": where + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0)),
			"vel": Vector2(randf_range(-40.0, 40.0), randf_range(-90.0, -40.0)),
			"color": color, "age": 0.0,
		})
	queue_redraw()
