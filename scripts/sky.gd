extends ColorRect
## The sky: changes colour through the day, moves the sun and moon across,
## and darkens the whole world at night through a CanvasModulate node.

const DAY_COLOR := Color(0.93, 0.92, 0.66)
const DUSK_COLOR := Color(0.96, 0.66, 0.46)
const NIGHT_COLOR := Color(0.15, 0.17, 0.32)
const NIGHT_TINT := Color(0.50, 0.55, 0.80)
const SUN_COLOR := Color(1.0, 0.97, 0.80)
const MOON_COLOR := Color(0.88, 0.90, 0.98)
## How much of the day the fade into night takes.
const DUSK_LENGTH := 0.06
const DAWN_LENGTH := 0.03

@export var world_tint: CanvasModulate


func _process(_delta: float) -> void:
	var dark := _darkness()
	color = DAY_COLOR.lerp(NIGHT_COLOR, dark).lerp(DUSK_COLOR, sin(dark * PI) * 0.5)
	world_tint.color = Color.WHITE.lerp(NIGHT_TINT, dark)
	queue_redraw()


func _draw() -> void:
	var now := GameState.day_fraction()
	var night_start := GameState.night_start()
	if now < night_start:
		_draw_disc(now / night_start, SUN_COLOR, 9.0)
	else:
		_draw_disc((now - night_start) / (1.0 - night_start), MOON_COLOR, 6.0)


## 0 in daylight, 1 in the middle of the night, fading in between.
func _darkness() -> float:
	var now := GameState.day_fraction()
	var night_start := GameState.night_start()
	return smoothstep(night_start - DUSK_LENGTH, night_start, now) * (1.0 - smoothstep(1.0 - DAWN_LENGTH, 1.0, now))


## The sun or moon on its arc across the sky; progress runs 0 (rising) to 1 (setting).
func _draw_disc(progress: float, disc_color: Color, radius: float) -> void:
	var x := lerpf(30.0, size.x - 30.0, progress)
	var y := 230.0 - sin(progress * PI) * 190.0
	draw_rect(Rect2(x - radius, y - radius, radius * 2, radius * 2), disc_color)
