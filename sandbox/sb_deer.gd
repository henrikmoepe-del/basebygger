extends "res://sandbox/sb_thing.gd"
## A deer in the wood to the east: grazes, wanders, and runs from anyone who
## comes near. A hunter shoots it from range; it leaves meat to haul home.

const SPEED := 22.0
const RUN_SPEED := 46.0
const SHY := 34.0
const MEAT := 2

var hp := 1
var _to := Vector2.INF
var _graze := 0.0
var _running := 0.0
var _walking := false


func setup() -> void:
	kind = "deer"


func capacity() -> int:
	return 1


func is_open() -> bool:
	return hp > 0


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-8, -12), Vector2(16, 14)).has_point(p)


func label() -> String:
	return "a deer"


func work_spot(peasant: Node2D) -> Vector2:
	return position


## An arrow missed: off it runs, away from the hunter.
func scare(from: Vector2) -> void:
	_running = 3.0
	var away := (position - from).normalized()
	_to = position + Vector2(absf(away.x) + 0.4, away.y).normalized() * 70.0


## Hit by an arrow.
func shot() -> void:
	hp -= 1
	if hp <= 0:
		world.deer_shot += 1
		for other in world.deer:
			if other != self and other.position.distance_to(position) < 90.0:
				other.scare(position)
		for i in MEAT:
			world.spawn_item("food", position + Vector2(-4 + i * 8, 2))
		world.announce("A deer is shot: meat to bring home.")
		world.remove_thing(self)


func _process(delta: float) -> void:
	_walking = false
	var near: Node2D = world.nearest_peasant(position, SHY)
	if near != null:
		# Run away, deeper into the wood.
		_running = 1.5
		var away := (position - near.position).normalized()
		if away.x < 0.3:
			away.x = 0.6
		_to = position + away.normalized() * 40.0
	if _running > 0.0:
		_running -= delta
	if _graze > 0.0:
		_graze -= delta
	elif _to == Vector2.INF or position.distance_to(_to) < 1.0:
		_graze = randf_range(2.0, 6.0)
		_to = Vector2(randf_range(world.WOOD_FROM, SbData.EAST_EDGE - 10), randf_range(SbData.WALK_TOP + 4, SbData.WALK_BOTTOM))
	else:
		_walking = true
		var speed := RUN_SPEED if _running > 0.0 else SPEED
		_to.x = clampf(_to.x, world.WOOD_FROM - 40.0, SbData.EAST_EDGE - 6.0)
		_to.y = clampf(_to.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
		var before := position.x
		position = position.move_toward(_to, speed * delta)
		if absf(position.x - before) > 0.01:
			scale.x = 1.0 if position.x > before else -1.0
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 110.0 + position.x
	var step := int(t) % 2 if _walking else -1
	var brown := SbData.WOOD2
	# Legs, body, neck and head (grazing: head down), antlers.
	for i in 4:
		var lx := -5.0 + i * 3.0
		var long := (i + (step if step >= 0 else 0)) % 2 == 0
		draw_rect(Rect2(lx, -4, 1, 4 if long or step < 0 else 3), SbData.WOOD1)
	draw_rect(Rect2(-6, -8, 11, 4), brown)
	draw_rect(Rect2(-6, -8, 11, 1), SbData.WOOD3)
	draw_rect(Rect2(-7, -8, 1, 2), SbData.DAUB)
	var down := _graze > 0.0 and not _walking
	var head := Vector2(5, -6) if down else Vector2(5, -12)
	draw_rect(Rect2(4, head.y + 2, 2, -head.y - 6 if not down else 2), brown)
	draw_rect(Rect2(head.x, head.y, 4, 3), brown)
	draw_rect(Rect2(head.x + 3, head.y + 1, 1, 1), SbData.INK)
	if not down:
		draw_rect(Rect2(head.x, head.y - 3, 1, 3), SbData.WOOD3)
		draw_rect(Rect2(head.x + 2, head.y - 3, 1, 3), SbData.WOOD3)
		draw_rect(Rect2(head.x - 1, head.y - 3, 1, 1), SbData.WOOD3)
