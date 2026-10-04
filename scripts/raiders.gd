extends Node2D
## Shows a raid: red figures march in from the west towards the castle
## while GameState counts down, then run off again once it is decided.
## This is only the picture; GameState decides who wins.

const BODY := Color(0.70, 0.16, 0.16)
const SKIN := Color(0.93, 0.76, 0.62)
const START_X := -500.0
const SPACING := -9.0
const FLEE_SPEED := 90.0

## Where the raiders stop: just outside the castle's west tower.
@export var stop_x := -140.0

## The x position of each raider on screen.
var _raiders: Array[float] = []
var _fleeing := false


func _ready() -> void:
	GameState.raid_started.connect(_on_raid_started)
	GameState.raid_resolved.connect(_on_raid_resolved)
	if GameState.raid_incoming:
		_on_raid_started()


func _process(delta: float) -> void:
	if _raiders.is_empty():
		return
	# March so the front raider arrives as the countdown ends.
	var march_speed := (stop_x - START_X) / GameState.RAID_MARCH_TIME
	for i in _raiders.size():
		if _fleeing:
			_raiders[i] -= FLEE_SPEED * delta
		else:
			_raiders[i] = minf(_raiders[i] + march_speed * delta, stop_x - i * 4.0)
	if _fleeing and _raiders[0] < START_X - 10.0:
		_raiders.clear()
	queue_redraw()


func _draw() -> void:
	for x in _raiders:
		draw_rect(Rect2(x - 3, -10, 6, 10), BODY)
		draw_rect(Rect2(x - 2, -14, 4, 4), SKIN)
		draw_rect(Rect2(x + 4, -16, 1, 14), Color(0.30, 0.30, 0.34))


func _on_raid_started() -> void:
	_fleeing = false
	_raiders.clear()
	for i in 3 + GameState.raids_faced:
		_raiders.append(START_X + i * SPACING)


func _on_raid_resolved(_won: bool) -> void:
	_fleeing = true
