extends Node2D
## A cow with a cart. It waits at one gathering site; peasants working there
## load the cart instead of walking home, and when the cart is full (or has
## waited long enough) the cow hauls it to the stockhouse and comes back.
## Placeholder shapes until we have real art.

enum State { TO_SITE, WAITING, TO_HOME }

const CAPACITY := 16
const SPEED := 34.0
## A part-full cart leaves after waiting this long.
const MAX_WAIT := 25.0
const CART_COLORS := {
	"wood": Color(0.48, 0.32, 0.20), "stone": Color(0.62, 0.62, 0.66),
	"food": Color(0.70, 0.25, 0.30), "iron": Color(0.36, 0.38, 0.46),
}

## The resource this cow hauls, and the Workers node that knows where things are.
var resource := "food"
var world: Node2D

var _state := State.TO_SITE
var _load := 0
var _wait := 0.0


func _process(delta: float) -> void:
	if GameState.is_night():
		# Back to the stockhouse for the night, bringing whatever is in the cart.
		if _walk_to(world.stock_x - 30.0, delta):
			_unload()
		_state = State.TO_SITE
		queue_redraw()
		return
	match _state:
		State.TO_SITE:
			if _walk_to(world.cow_site_x(resource), delta):
				_state = State.WAITING
				_wait = 0.0
		State.WAITING:
			_wait += delta
			if _load >= CAPACITY or (_load > 0 and _wait >= MAX_WAIT):
				_state = State.TO_HOME
		State.TO_HOME:
			if _walk_to(world.stock_x, delta):
				_unload()
				_state = State.TO_SITE
	queue_redraw()


## True if the cart is at its site with room left.
func has_room() -> bool:
	return _state == State.WAITING and _load < CAPACITY


## Takes as much of the load as fits and returns how much that was.
func give(amount: int) -> int:
	var taken := mini(amount, CAPACITY - _load)
	_load += taken
	return taken


func _unload() -> void:
	if _load > 0:
		GameState.add_income(resource, _load)
		_load = 0


func _draw() -> void:
	# The cart, with its load showing above the sides.
	draw_rect(Rect2(-18, -9, 12, 6), Color(0.48, 0.32, 0.20))
	draw_rect(Rect2(-15, -3, 3, 3), Color(0.25, 0.17, 0.10))
	if _load > 0:
		var height := 1.0 + 5.0 * _load / CAPACITY
		draw_rect(Rect2(-17, -9 - height, 10, height), CART_COLORS[resource])
	# The cow.
	draw_rect(Rect2(-5, -10, 13, 7), Color(0.90, 0.88, 0.82))
	draw_rect(Rect2(-1, -10, 4, 4), Color(0.30, 0.22, 0.16))
	draw_rect(Rect2(8, -12, 5, 5), Color(0.90, 0.88, 0.82))
	draw_rect(Rect2(-4, -3, 2, 3), Color(0.30, 0.22, 0.16))
	draw_rect(Rect2(5, -3, 2, 3), Color(0.30, 0.22, 0.16))


func _walk_to(x: float, delta: float) -> bool:
	position.x = move_toward(position.x, x, SPEED * GameState.work_mult() * delta)
	return is_equal_approx(position.x, x)
