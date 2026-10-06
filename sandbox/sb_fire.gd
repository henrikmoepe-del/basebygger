extends "res://sandbox/sb_thing.gd"
## A fire on a building site or in the stockyard. It grows by itself and
## does damage to what it burns on (blocks fall off a site, the stockyard
## loses stock) until peasants put it out with buckets from the well.

const GROW := 0.02
const DOUSE := 0.3
## How fast a fire with nothing left to burn dies down.
const STARVE := 0.08

const Light := preload("res://sandbox/sb_light.gd")

var host: Node2D
var strength := 0.4
var _burn_timer := 0.0
var _light: PointLight2D


func setup(host_: Node2D) -> void:
	kind = "fire"
	host = host_
	_light = Light.add(self, Vector2(0, -10), 90.0)


func is_open() -> bool:
	return strength > 0.0


func douse() -> void:
	strength -= DOUSE
	if strength <= 0.0:
		strength = 0.0
		world.announce("The fire at %s is out." % host.label())
		world.remove_thing(self)


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-14, -26), Vector2(28, 30)).has_point(p)


func work_spot(peasant: Node2D) -> Vector2:
	var i := workers.find(peasant)
	if i < 0:
		i = workers.size()
	var side := -1.0 if i % 2 == 0 else 1.0
	return position + Vector2(side * (16.0 + 4.0 * float(i / 2)), 6.0 + 4.0 * float(i / 2))


func label() -> String:
	return "the fire at " + host.label()


func _process(delta: float) -> void:
	if strength <= 0.0:
		return
	if host.has_method("has_fuel") and not host.has_fuel():
		strength -= STARVE * delta
		if strength <= 0.0:
			strength = 0.0
			world.announce("The fire at %s has burned out." % host.label())
			world.remove_thing(self)
			return
	else:
		strength = minf(strength + GROW * delta, 1.0)
	if _light != null:
		_light.energy = (0.6 + strength) * (0.9 + 0.1 * sin(Time.get_ticks_msec() / 70.0))
	_burn_timer += delta * strength
	if _burn_timer >= 2.0:
		_burn_timer = 0.0
		if host.has_method("burn"):
			host.burn()
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var n := 3 + int(strength * 5.0)
	for i in n:
		var x := (float(i) - n / 2.0) * 4.0
		var h := (8.0 + 14.0 * strength) * (0.7 + 0.3 * sin(t * 9.0 + i * 1.7))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 0), Vector2(x + 1, -h), Vector2(x + 4, 0)]), SbData.FIRE)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1, 0), Vector2(x + 1, -h * 0.55), Vector2(x + 2, 0)]), SbData.LIGHT)
	# Smoke, dithered: every other pixel.
	for i in 6:
		var p := Vector2(sin(t + i) * 4.0, -20.0 - strength * 10.0 - i * 4.0 - fmod(t * 6.0, 4.0))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(SbData.STONE1, 0.5))


func describe() -> String:
	return "Fire at %s (%d%%)" % [host.label(), roundi(strength * 100.0)]
