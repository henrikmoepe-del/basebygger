extends "res://sandbox/sb_thing.gd"
## A raider: walks in from the west, fights any peasant who comes near, and
## otherwise heads for the stockyard, grabs something and runs off west with
## it. Beaten, it drops what it carried, for someone to haul back.

const SPEED := 24.0
const REACH := 9.0
const HIT_EVERY := 1.1
const DAMAGE := 2.0
const NOTICE := 60.0
const Sprites := preload("res://sandbox/sb_sprites.gd")
## Each raider may set one building alight as they pass it.
const TORCH_CHANCE := 0.4
const TORCH_REACH := 20.0

var hp := 8.0
var max_hp := 8.0
var loot := ""
## A werewolf instead of a raider: no loot, no torch, gone at dawn.
var wolf := false
var _cool := 0.0
var _hurt := 0.0
var _walking := false
var _torch := true
var _tried: Array = []


var _light: PointLight2D


func setup(as_wolf := false) -> void:
	kind = "raider"
	wolf = as_wolf
	if wolf:
		hp = SbData.WOLF_HP
		max_hp = hp
		_torch = false
		# Deep shadow and red (art direction): a faint red glow around it.
		_light = preload("res://sandbox/sb_light.gd").add(self, Vector2(2, -14), 46.0, 0.9)
		_light.color = SbData.RED1
		return
	_light = preload("res://sandbox/sb_light.gd").add(self, Vector2(-5, -16), 40.0, 0.8)


func is_open() -> bool:
	return hp > 0.0


func capacity() -> int:
	return 99


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-5, -18), Vector2(10, 20)).has_point(p)


func label() -> String:
	return "the werewolf" if wolf else "a raider"


func damage(n: float) -> void:
	hp -= n
	_hurt = 0.2
	if hp <= 0.0:
		if loot != "" and loot != "none":
			world.spawn_item(loot, position + Vector2(0, 2))
		world.announce("The werewolf is slain!" if wolf else "A raider is beaten.")
		world.remove_thing(self)


func work_spot(peasant: Node2D) -> Vector2:
	var side := -1.0 if peasant.position.x < position.x else 1.0
	return position + Vector2(side * 8.0, 0.0)


func _process(delta: float) -> void:
	if hp <= 0.0:
		return
	_cool = maxf(_cool - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	if _light != null:
		# Light only shows in the dark.
		_light.energy = (0.9 if wolf else 0.8) * world.darkness()
	_walking = false
	if wolf and not world.is_night():
		# Dawn: back into the wood.
		if _step(Vector2(SbData.EAST_EDGE + 30.0, position.y), delta, 1.0):
			world.announce("The werewolf slinks back into the wood.")
			world.remove_thing(self)
		queue_redraw()
		return
	var foe: Node2D = world.nearest_peasant(position, (NOTICE * 2.0 if wolf else NOTICE) if loot == "" else 14.0)
	if foe != null:
		if position.distance_to(foe.position) > REACH:
			_step(foe.position, delta)
		elif _cool <= 0.0:
			_cool = HIT_EVERY
			foe.damage(SbData.WOLF_DAMAGE if wolf else DAMAGE)
	elif wolf:
		# Prowling: towards the village, to find someone.
		_step(Vector2(world.stockyard.position.x, 40.0), delta)
	elif loot == "":
		_try_torch()
		var yard: Node2D = world.stockyard
		var spot := yard.position + Vector2(0, 8)
		if _step(spot, delta):
			for res in ["food", "wood", "stone"]:
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


## Passing a building with something built, maybe set it alight (once).
func _try_torch() -> void:
	if not _torch:
		return
	for s in world.sites:
		if s.placed == 0 or _tried.has(s) or absf(s.position.x - position.x) > TORCH_REACH:
			continue
		_tried.append(s)
		if world.fires.any(func(f): return f.host == s):
			continue
		if randf() < TORCH_CHANCE:
			_torch = false
			if _light != null:
				_light.queue_free()
				_light = null
			world.start_fire(s, "A raider sets fire to %s!" % s.label())
		return


func _step(to: Vector2, delta: float, pace := 1.0) -> bool:
	_walking = true
	var speed := SbData.WOLF_SPEED if wolf else SPEED
	var before := position.x
	position = position.move_toward(to, speed * pace * delta)
	if absf(position.x - before) > 0.01:
		scale.x = 1.0 if position.x > before else -1.0
	position.y = clampf(position.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
	return position.distance_to(to) < 1.0


func _draw() -> void:
	var step := int(Time.get_ticks_msec() / 130.0 + position.x) % 2 if _walking else -1
	if wolf:
		_draw_wolf(step)
		return
	# The raider from the art direction's people sheet (helmet and axe).
	var tint := Color(1.0, 0.55, 0.5) if _hurt > 0.0 else Color.WHITE
	draw_texture(Sprites.texture("raider", step + 1 if step >= 0 else 0), Sprites.offset("raider"), tint)
	if _torch:
		draw_rect(Rect2(-5, -14, 1, 6), SbData.WOOD1)
		var flick := 1.0 if int(Time.get_ticks_msec() / 90) % 2 == 0 else 0.0
		draw_rect(Rect2(-6, -17 - flick, 3, 3), SbData.FIRE)
		draw_rect(Rect2(-5, -16 - flick, 1, 1), SbData.LIGHT)
	if loot != "" and loot != "none":
		draw_rect(Rect2(-6, -15, 5, 6), SbData.DIRT)
	_draw_health(-21.0)


func _draw_health(y: float) -> void:
	if hp < max_hp:
		draw_rect(Rect2(-5, y, 10, 1), SbData.RED0)
		draw_rect(Rect2(-5, y, 10.0 * hp / max_hp, 1), SbData.GOLD)


## A hunched, shaggy beast on two legs, with glowing eyes.
func _draw_wolf(step: int) -> void:
	var fur := SbData.WHITE if _hurt > 0.0 else SbData.STONE0
	draw_rect(Rect2(-3, -4, 2, 4 if step != 0 else 3), fur)
	draw_rect(Rect2(1, -4, 2, 4 if step != 1 else 3), fur)
	draw_rect(Rect2(-5, -15, 10, 11), fur)
	draw_rect(Rect2(-6, -12, 2, 6), fur)
	draw_rect(Rect2(1, -21, 7, 6), fur)
	draw_rect(Rect2(7, -18, 3, 2), fur)
	draw_rect(Rect2(2, -23, 2, 2), fur)
	draw_rect(Rect2(5, -23, 2, 2), fur)
	draw_rect(Rect2(4, -19, 2, 1), Color(1.0, 0.25, 0.2))
	draw_rect(Rect2(4, -9, 4, 1), SbData.STONE3)
	_draw_health(-27.0)


func describe() -> String:
	if wolf:
		return "The werewolf: %d / %d health" % [ceili(hp), int(max_hp)]
	return "A raider: %d / 8 health%s" % [ceili(hp), ", carrying %s" % loot if loot != "" and loot != "none" else ""]
