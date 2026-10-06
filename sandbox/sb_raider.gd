extends "res://sandbox/sb_thing.gd"
## A raider: walks in from the west, fights any peasant who comes near, and
## otherwise heads for the stockyard, grabs something and runs off west with
## it. Beaten, it drops what it carried, for someone to haul back.

const SPEED := 24.0
const REACH := 9.0
const HIT_EVERY := 1.1
const DAMAGE := 2.0
const NOTICE := 60.0

var hp := 8.0
var loot := ""
var _cool := 0.0
var _hurt := 0.0
var _walking := false


func setup() -> void:
	kind = "raider"


func is_open() -> bool:
	return hp > 0.0


func capacity() -> int:
	return 99


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-5, -18), Vector2(10, 20)).has_point(p)


func label() -> String:
	return "a raider"


func damage(n: float) -> void:
	hp -= n
	_hurt = 0.2
	if hp <= 0.0:
		if loot != "":
			world.spawn_item(loot, position + Vector2(0, 2))
		world.announce("A raider is beaten.")
		world.remove_thing(self)


func work_spot(peasant: Node2D) -> Vector2:
	var side := -1.0 if peasant.position.x < position.x else 1.0
	return position + Vector2(side * 8.0, 0.0)


func _process(delta: float) -> void:
	if hp <= 0.0:
		return
	_cool = maxf(_cool - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	_walking = false
	var foe: Node2D = world.nearest_peasant(position, NOTICE if loot == "" else 14.0)
	if foe != null:
		if position.distance_to(foe.position) > REACH:
			_step(foe.position, delta)
		elif _cool <= 0.0:
			_cool = HIT_EVERY
			foe.damage(DAMAGE)
	elif loot == "":
		var yard: Node2D = world.stockyard
		var spot := yard.position + Vector2(0, 8)
		if _step(spot, delta):
			for res in ["wood", "stone"]:
				if yard.take(res):
					loot = res
					break
			if loot == "":
				loot = "none"
	else:
		if _step(Vector2(SbData.WEST_EDGE - 30.0, position.y), delta):
			if loot != "none":
				world.announce("A raider got away with some %s." % loot)
			world.remove_thing(self)
	queue_redraw()


func _step(to: Vector2, delta: float) -> bool:
	_walking = true
	position = position.move_toward(to, SPEED * delta)
	position.y = clampf(position.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
	return position.distance_to(to) < 1.0


func _draw() -> void:
	var step := int(Time.get_ticks_msec() / 130.0 + position.x) % 2 if _walking else -1
	draw_rect(Rect2(-2, -3, 2, 2 if step == 0 else 3), SbData.INK)
	draw_rect(Rect2(1, -3, 2, 2 if step == 1 else 3), SbData.INK)
	var body := SbData.WHITE if _hurt > 0.0 else SbData.RED1
	draw_rect(Rect2(-3, -13, 6, 10), body)
	draw_rect(Rect2(-2, -17, 4, 4), SbData.SKIN0)
	draw_rect(Rect2(-3, -18, 6, 2), SbData.STONE1)
	# An axe.
	draw_rect(Rect2(3, -14, 1, 9), SbData.WOOD1)
	draw_rect(Rect2(4, -14, 2, 3), SbData.STONE3)
	if loot != "" and loot != "none":
		draw_rect(Rect2(-6, -16, 5, 6), SbData.DIRT)
	# Health bar while hurt.
	if hp < 8.0:
		draw_rect(Rect2(-5, -22, 10, 1), SbData.RED0)
		draw_rect(Rect2(-5, -22, 10.0 * hp / 8.0, 1), SbData.GOLD)
