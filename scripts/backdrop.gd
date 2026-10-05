extends Node2D
## Scenery behind the world: two rows of hills that slide more slowly than
## the foreground as the camera moves (which gives a feeling of depth), and
## tufts of grass and flowers along the ground line. Placeholder shapes.
## The colours follow the season (see season_data.gd): flowers in spring and
## summer, brown in autumn, snow on the hills in winter.

const GROUND_Y := 270.0
const COLUMN := 6.0
const WORLD_LEFT := -1400.0
const WORLD_RIGHT := 2000.0
## How much of the camera's movement each row follows (1 = fixed to the sky).
const FAR_FOLLOW := 0.75
const NEAR_FOLLOW := 0.5
const SNOW := Color(0.96, 0.97, 1.0)
const FLOWER_COLORS := [Color(0.95, 0.90, 0.45), Color(0.92, 0.55, 0.60), Color(0.96, 0.96, 0.96)]

var _camera_x := INF
var _season: Dictionary


func _ready() -> void:
	GameState.season_changed.connect(_on_season_changed)
	_on_season_changed()


func _on_season_changed() -> void:
	_season = GameState.season()
	var ground: ColorRect = get_parent().get_node_or_null("Ground")
	if ground != null:
		ground.color = _season.ground
	queue_redraw()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.position.x != _camera_x:
		_camera_x = camera.position.x
		queue_redraw()


func _draw() -> void:
	var camera_x := 0.0 if _camera_x == INF else _camera_x
	_draw_hills(camera_x * FAR_FOLLOW, 70.0, 0.004, 1.7, _season.far)
	_draw_hills(camera_x * NEAR_FOLLOW, 38.0, 0.007, 4.1, _season.near)
	_draw_tufts()


## A row of hills made of narrow columns, their heights from a few waves added together.
func _draw_hills(shift: float, height: float, stretch: float, phase: float, color: Color) -> void:
	var x := WORLD_LEFT
	while x < WORLD_RIGHT:
		var wave := sin(x * stretch + phase) + 0.5 * sin(x * stretch * 2.7 + phase * 2.0) + 0.25 * sin(x * stretch * 6.1)
		var top := height * (0.55 + 0.25 * wave)
		# Whole pixels, so the hills keep the chunky look.
		draw_rect(Rect2(x + shift, GROUND_Y - floorf(top), COLUMN, floorf(top)), color)
		if _season.get("snow", false):
			draw_rect(Rect2(x + shift, GROUND_Y - floorf(top), COLUMN, 3), SNOW)
		x += COLUMN


func _draw_tufts() -> void:
	# The same scattering every time: positions come from a fixed seed.
	var random := RandomNumberGenerator.new()
	random.seed = 11
	for i in 260:
		var x := floorf(random.randf_range(WORLD_LEFT, WORLD_RIGHT))
		var tall := random.randi_range(2, 4)
		draw_rect(Rect2(x, GROUND_Y - tall, 1, tall), _season.tuft)
		draw_rect(Rect2(x + 2, GROUND_Y - tall + 1, 1, tall - 1), _season.tuft)
		if _season.get("snow", false) and i % 3 == 0:
			draw_rect(Rect2(x - 2, GROUND_Y - 1, 6, 1), SNOW)
		elif i % 6 == 0 and _season.get("flowers", false):
			draw_rect(Rect2(x + 1, GROUND_Y - tall - 2, 2, 2), FLOWER_COLORS[i % FLOWER_COLORS.size()])
