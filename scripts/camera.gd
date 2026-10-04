extends Camera2D
## Lets the player look around the world, which is wider than the screen:
## drag with the mouse, or hold A/D or the arrow keys.

const KEY_SPEED := 300.0
const SCREEN_SIZE := Vector2(640, 360)

## The left and right edges of the world.
@export var world_left := -400.0
@export var world_right := 640.0


func _ready() -> void:
	# Start on the castle side, showing what the screen showed before the world grew.
	position = Vector2(world_right - SCREEN_SIZE.x / 2, SCREEN_SIZE.y / 2)


func _process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	if direction != 0.0:
		_move(direction * KEY_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	# Dragging anywhere that isn't a button slides the view.
	if event is InputEventMouseMotion and event.button_mask != 0:
		_move(-event.relative.x)


func _move(amount: float) -> void:
	var half := SCREEN_SIZE.x / 2
	position.x = clampf(position.x + amount, world_left + half, world_right - half)
