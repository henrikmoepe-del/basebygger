extends "res://sandbox/sb_thing.gd"
## A rock outcrop: mined a stone at a time; the stone falls beside it for
## someone to haul. Used up, it slowly fills again (fresh stone is exposed),
## like the quarry in the main game.

const MINE_TIME := 4.0
const REFILL_TIME := 150.0

var stone := 6
var _full := 6
var _progress := 0.0
var _shake := 0.0
var _refill := 0.0
## A cave-in: the miner trapped under the rubble here, and how far the
## digging to free them has got.
var trapped: Node2D = null
var dug := 0.0
var _trapped_for := 0.0


func setup(stones: int) -> void:
	kind = "rock"
	stone = stones
	_full = stones


## Open while there is stone to mine, or someone to dig out.
func is_open() -> bool:
	return stone > 0 or trapped != null


## Work on the rock for `amount` seconds. Returns true when a stone comes loose.
func mine(amount: float) -> bool:
	if stone <= 0:
		return false
	_progress += amount
	_shake = 0.2
	queue_redraw()
	if _progress < MINE_TIME:
		return false
	_progress = 0.0
	world.sound("mine", position)
	stone -= 1
	if trapped == null and not world.calm and randf() < SbData.CAVE_IN_CHANCE:
		_cave_in()
		return true
	world.spawn_item("stone", position + Vector2(randf_range(-12, 12), randf_range(3, 8)))
	if stone == 0:
		_refill = REFILL_TIME
		world.announce("A rock is used up for now.")
	return true


## The miner working here is buried under falling rock.
func _cave_in() -> void:
	var miner: Node2D = null
	for w in workers:
		miner = w
		break
	if miner == null:
		return
	trapped = miner
	dug = 0.0
	_trapped_for = 0.0
	miner.trap(self)
	world.sound("lost")
	world.announce("Cave-in! %s is trapped at a rock. Dig them out!" % miner.person_name)
	for p in world.peasants:
		p.rethink()


## Rescuers dig; returns true when the trapped one is free.
func dig(amount: float) -> bool:
	if trapped == null:
		return true
	dug += amount
	queue_redraw()
	if dug < SbData.DIG_TIME:
		return false
	var freed := trapped
	trapped = null
	freed.untrap()
	world.announce("%s is dug out of the rubble." % freed.person_name)
	return true


func hit(p: Vector2) -> bool:
	if trapped != null:
		return Rect2(position + Vector2(-16, -18), Vector2(32, 22)).has_point(p)
	return stone > 0 and Rect2(position + Vector2(-14, -16), Vector2(28, 19)).has_point(p)


func label() -> String:
	return "a rock"


func _process(delta: float) -> void:
	if trapped != null:
		if not is_instance_valid(trapped):
			trapped = null
		else:
			_trapped_for += delta
			if _trapped_for >= SbData.TRAPPED_HURT_EVERY:
				_trapped_for = 0.0
				trapped.hp = maxf(trapped.hp - SbData.TRAPPED_HURT, 1.0)
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		queue_redraw()
	if stone == 0:
		_refill -= delta
		if _refill <= 0.0:
			stone = _full
			queue_redraw()


func _draw() -> void:
	if stone <= 0:
		draw_rect(Rect2(-6, -2, 12, 2), SbData.STONE1)
		_draw_rubble()
		return
	var f := 0.5 + 0.5 * float(stone) / float(_full)
	var jig := 1.0 if _shake > 0.0 and int(Time.get_ticks_msec() / 50) % 2 == 0 else 0.0
	var pts := PackedVector2Array([Vector2(-13, 0), Vector2(-10, -10 * f), Vector2(-3, -15 * f),
			Vector2(6, -13 * f), Vector2(12, -6 * f), Vector2(13, 0)])
	for i in pts.size():
		pts[i].x += jig
	draw_colored_polygon(pts, SbData.STONE2)
	draw_colored_polygon(PackedVector2Array([Vector2(-10 + jig, -10 * f), Vector2(-3 + jig, -15 * f), Vector2(1 + jig, -9 * f), Vector2(-6 + jig, -6 * f)]), SbData.STONE3)
	draw_line(Vector2(2 + jig, -12 * f), Vector2(5 + jig, -4 * f), SbData.STONE1, 1.0)
	_draw_rubble()


## A cave-in: rubble heaped in front of the rock with a hand showing, and a
## bar for how far the digging has got.
func _draw_rubble() -> void:
	if trapped == null:
		return
	for i in 7:
		draw_rect(Rect2(-12 + i * 3.5, -2 - (i % 3) * 2, 5, 4 + (i % 3) * 2), SbData.STONE2 if i % 2 else SbData.STONE4)
	draw_rect(Rect2(-14, 1, 28, 2), SbData.STONE1)
	draw_rect(Rect2(3, -7, 2, 2), SbData.SKIN1)
	draw_rect(Rect2(-12, 5, 24, 2), SbData.INK)
	draw_rect(Rect2(-12, 5, 24.0 * dug / SbData.DIG_TIME, 2), SbData.GOLD)


func describe() -> String:
	if trapped != null:
		return "Cave-in: %s is trapped here (%d%% dug out)" % [trapped.person_name, roundi(100.0 * dug / SbData.DIG_TIME)]
	if stone <= 0:
		return "A rock, used up for now"
	return "A rock: %d stone left%s" % [stone, " (forbidden)" if forbidden else ""]
