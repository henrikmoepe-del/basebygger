extends "res://scripts/worker.gd"
## A peasant who guards the castle. In peace, soldiers keep watch from the
## wall walk, the tower tops and the roofs, day and night, pacing to a new
## spot now and then.
##
## When raiders come, each soldier goes to a battle post (see
## Workers.battle_post): archers up on the watchtower, the towers and the
## wall, spearmen on the ground behind the palisade. raiders.gd runs the
## fight; a soldier only walks to the post and keeps track of their own
## strength. A spearman who is beaten down falls back to the garrison and is
## out of the fight until the raid is over.

const MAX_HP := 30.0
const HURT := Color(0.85, 0.75, 0.30)

## True for a spearman (fights on the ground), false for an archer.
var melee := false

## Which post this soldier keeps in peace, from 0 to 1 (see Workers.guard_post).
var _beat := randf()
var _post := Vector2.INF
var _wait := 0.0
var _seen_version := -1
## How much of their strength has been knocked out of them in this raid.
var _hurt := 0.0
## True once beaten down in this raid.
var _out := false
var _at_post := false
var _shot_wait := 0.0
## Seconds left of the jab or the loosing of an arrow, for the animation.
var _action := 0.0


func _ready() -> void:
	add_to_group("soldiers")
	GameState.raid_resolved.connect(func(_won: bool) -> void:
		_out = false
		_hurt = 0.0)


func _sleeps() -> bool:
	return false


func _work(delta: float) -> void:
	_action = maxf(_action - delta, 0.0)
	_at_post = false
	if GameState.raid_incoming:
		if _out:
			# Beaten: back to the garrison to be patched up.
			if _walk_to(CastleData.GARRISON_LEFT + CastleData.GARRISON_WIDTH / 2.0, delta):
				_inside = true
			return
		var post: Dictionary = world.battle_post(self)
		melee = post.melee
		_at_post = _go_to(post.pos, delta)
		return
	if _seen_version != world.castle.version:
		# The castle changed: the old post may have moved.
		_seen_version = world.castle.version
		_post = world.guard_post(_beat, home_x)
	if _go_to(_post, delta):
		_wait -= delta
		if _wait <= 0.0:
			_wait = randf_range(5.0, 14.0)
			_post = world.guard_post(_beat, home_x)


# --- The fight (called by raiders.gd) ---

## True if this soldier is in the fight.
func can_fight() -> bool:
	return GameState.raid_incoming and not _out


## True once the soldier stands at their battle post.
func at_post() -> bool:
	return _at_post and not _out


## How hard this soldier hits: trained soldiers and skills count for more.
func might() -> float:
	return _skill() * GameState.soldier_defence() / float(GameState.SOLDIER_DEFENCE)


## Counts down to the next arrow. Returns true when one is loosed.
func ready_to_shoot(delta: float, gap: float) -> bool:
	_shot_wait -= delta
	if _shot_wait > 0.0:
		return false
	_shot_wait = gap / _skill()
	_action = 0.25
	return true


## Jabbing with the spear (for the animation).
func strike() -> void:
	if _action <= 0.0:
		_action = 0.3


## A raider's blow lands.
func hurt(damage: float) -> void:
	_hurt += damage
	if _hurt >= _full_hp() and not _out:
		_out = true
		GameState.announced.emit("A soldier is beaten back to the garrison")


func _full_hp() -> float:
	return MAX_HP * _skill()


func _draw_extra(bob_y: float) -> void:
	# Helmet.
	draw_rect(Rect2(-2, bob_y - 15, 4, 2), Color(0.62, 0.62, 0.66))
	if GameState.raid_incoming and not melee:
		# A bow, held out towards the west; drawn back as an arrow is loosed.
		var pull := 2.0 if _action > 0.0 else 0.0
		draw_rect(Rect2(-6 + pull, bob_y - 13, 1, 9), Color(0.48, 0.32, 0.20))
		draw_rect(Rect2(-5 + pull, bob_y - 13, 1, 1), Color(0.48, 0.32, 0.20))
		draw_rect(Rect2(-5 + pull, bob_y - 5, 1, 1), Color(0.48, 0.32, 0.20))
	elif GameState.raid_incoming:
		# The spear levelled at the raiders, jabbing.
		var jab := 5.0 if _action > 0.15 else 0.0
		draw_rect(Rect2(-14 - jab, bob_y - 8, 16, 1), Color(0.48, 0.32, 0.20))
		draw_rect(Rect2(-17 - jab, bob_y - 9, 3, 3), Color(0.75, 0.76, 0.80))
	else:
		# The spear at rest.
		draw_rect(Rect2(4, bob_y - 18, 1, 18), Color(0.48, 0.32, 0.20))
		draw_rect(Rect2(3, bob_y - 20, 3, 3), Color(0.75, 0.76, 0.80))
	if _hurt > 0.0 and not _out:
		draw_rect(Rect2(-4, bob_y - 21, 8, 2), Color(0.20, 0.13, 0.08))
		draw_rect(Rect2(-4, bob_y - 21, 8.0 * (1.0 - _hurt / _full_hp()), 2), HURT)
