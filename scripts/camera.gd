extends Camera2D
## Lets the player look around the world, which is wider than the screen:
## drag with the mouse, or hold A/D or the arrow keys. The mouse wheel zooms.

const KEY_SPEED := 300.0
const SCREEN_SIZE := Vector2(640, 360)
## The ground line's height on screen stays put while zooming.
const GROUND_Y := 270.0
## Zoom steps, from closest to furthest out.
const ZOOM_LEVELS := [1.0, 0.75, 0.5]

## The left and right edges of the world.
@export var world_left := -480.0
@export var world_right := 1090.0
## Where the view is centred when the game starts: the castle and the stockhouse.
@export var start_x := 150.0

var _zoom_index := 0


func _ready() -> void:
	position.x = start_x
	_apply_zoom()


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
		_move(-event.relative.x / zoom.x)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_index = mini(_zoom_index + 1, ZOOM_LEVELS.size() - 1)
			_apply_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_index = maxi(_zoom_index - 1, 0)
			_apply_zoom()


func _apply_zoom() -> void:
	var level: float = ZOOM_LEVELS[_zoom_index]
	zoom = Vector2(level, level)
	# Keep the ground three quarters of the way down the screen at every zoom.
	position.y = GROUND_Y - SCREEN_SIZE.y / level / 4.0
	_move(0.0)


func _move(amount: float) -> void:
	var half := SCREEN_SIZE.x / zoom.x / 2
	if half * 2 >= world_right - world_left:
		# Zoomed out past the whole world: keep it centred.
		position.x = (world_left + world_right) / 2
	else:
		position.x = clampf(position.x + amount, world_left + half, world_right - half)
