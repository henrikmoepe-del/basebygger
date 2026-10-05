extends Node2D
## A raid, fought out in the world. Raiders walk in from the west towards
## the castle. On the way they meet the outer defences:
##   the palisade  they must hack it down to pass, while the spearmen behind
##                 it jab at them through the stakes
##   archers       soldiers on the watchtower, the towers and the wall walk
##                 shoot at any raider in range
## Raiders who get past fight any spearmen in their way. If every raider
## falls, the raid is beaten. If one reaches the foot of the castle, the
## fight for the gate begins in 3D (GameState.raiders_reached) with however
## many are left.
##
## This node runs the fight: it moves the raiders, and makes the soldiers
## (soldier.gd, who walk to their posts by themselves) shoot and strike.

const BODY := Color(0.70, 0.16, 0.16)
const SKIN := Color(0.93, 0.76, 0.62)
const BLADE := Color(0.30, 0.30, 0.34)
const ARROW := Color(0.25, 0.20, 0.15)
const BAR_BACK := Color(0.20, 0.13, 0.08)
const BAR := Color(0.85, 0.75, 0.30)
const GRASS := Color(0.45, 0.68, 0.38)
const START_X := -1040.0
const SPACING := 12.0
const SPEED := 14.0
const FLEE_SPEED := 90.0
## Where the castle begins: a raider who gets this far has reached it.
const CASTLE_X := -576.0
## How close a raider and a spearman must be to strike each other, and how
## far a spear reaches through the palisade.
const MELEE_REACH := 12.0
const SPEAR_REACH := 84.0
## Raiders stop this far short of the palisade to hack at it.
const PALISADE_STAND := 32.0
const RAIDER_DAMAGE := 3.0
const PALISADE_HP_PER_LEVEL := 30.0
## An archer can shoot this far, and a little further for every bit of height.
const ARROW_RANGE := 200.0
const HEIGHT_RANGE := 0.6
const ARROW_TIME := 0.3
const ARROW_DAMAGE := 4.0
const SPEAR_DAMAGE := 5.0
const SHOT_GAP := 1.6
const FALL_TIME := 0.6

const CastleData = preload("res://scripts/castle_data.gd")

## Each raider: {"x": float, "hp": float, "max": float, "fallen": float}.
## "fallen" counts up from 0 once a raider is down, then they are removed.
var _raiders: Array[Dictionary] = []
## Each arrow in flight: {"from": Vector2, "to": Vector2, "age": float, "target": Dictionary}.
var _arrows: Array[Dictionary] = []
var _palisade_hp := 0.0
var _palisade_max := 0.0
var _fleeing := false
## The kind of the raid being fought (see EventData.RAID_KINDS).
var _kind: Dictionary = {}


func _ready() -> void:
	add_to_group("raid")
	GameState.raid_started.connect(_on_raid_started)
	GameState.raid_resolved.connect(_on_raid_resolved)
	if GameState.raid_incoming:
		_on_raid_started()


## True while the palisade stands in the raiders' way.
func palisade_holds() -> bool:
	return _palisade_hp > 0.0


func _on_raid_started() -> void:
	_fleeing = false
	_kind = GameState.raid_kind()
	_raiders.clear()
	_arrows.clear()
	for i in GameState.raid_size():
		var hp := GameState.raider_hp()
		_raiders.append({"x": START_X - i * SPACING, "hp": hp, "max": hp, "fallen": -1.0})
	_palisade_max = PALISADE_HP_PER_LEVEL * GameState.part_levels.palisade
	_palisade_hp = _palisade_max
	_report()


func _on_raid_resolved(_won: bool) -> void:
	_fleeing = true


func _process(delta: float) -> void:
	if _raiders.is_empty() and _arrows.is_empty():
		return
	if _fleeing:
		for raider in _raiders:
			raider.x -= FLEE_SPEED * delta
		_raiders = _raiders.filter(func(raider: Dictionary) -> bool: return raider.x > START_X - 40.0 and raider.fallen < 0.0)
		_arrows.clear()
	elif GameState.raid_incoming:
		var soldiers := get_tree().get_nodes_in_group("soldiers").filter(func(soldier: Node) -> bool: return soldier.can_fight())
		_move_raiders(delta, soldiers)
		_soldiers_fight(delta, soldiers)
		_fly_arrows(delta)
		_clear_fallen(delta)
	queue_redraw()


## Raiders walk east until something stops them: the palisade, a spearman,
## or the castle itself.
func _move_raiders(delta: float, soldiers: Array) -> void:
	var front := INF
	for raider in _raiders:
		if raider.fallen >= 0.0:
			continue
		var stop := CASTLE_X
		if palisade_holds():
			stop = minf(stop, CastleData.PALISADE_X - PALISADE_STAND)
		# A spearman standing in the way must be fought first.
		var foe: Node2D = null
		for soldier: Node2D in soldiers:
			if soldier.melee and soldier.at_post() and soldier.position.y > -0.5 and soldier.position.x > raider.x \
					and (foe == null or soldier.position.x < foe.position.x):
				foe = soldier
		if foe != null and not palisade_holds():
			stop = minf(stop, foe.position.x - MELEE_REACH)
		# Don't walk through the raider in front.
		stop = minf(stop, front - 5.0)
		raider.x = minf(raider.x + SPEED * _kind.get("speed", 1.0) * delta, stop)
		front = raider.x
		if palisade_holds() and raider.x >= CastleData.PALISADE_X - PALISADE_STAND - 24.0:
			_palisade_hp -= RAIDER_DAMAGE * delta
			if _palisade_hp <= 0.0:
				get_tree().call_group("camera", "shake", 3.0)
				get_tree().call_group("effects", "burst", to_global(Vector2(CastleData.PALISADE_X, -12)), CastleData.WOOD, 10)
				GameState.announced.emit("The palisade is broken!")
		elif foe != null and foe.position.x - raider.x <= MELEE_REACH + 1.0:
			foe.hurt(RAIDER_DAMAGE * delta)
		elif raider.x >= CASTLE_X - 0.5:
			# The castle is reached. (The fight for the gate in 3D is switched
			# off for now: the raiders are simply gone.)
			var standing := _standing()
			_raiders.clear()
			_arrows.clear()
			GameState.raiders_reached(standing)
			queue_redraw()
			return


## Archers shoot the nearest raider in range; spearmen strike any raider
## they can reach (through the palisade while it stands).
func _soldiers_fight(delta: float, soldiers: Array) -> void:
	for soldier: Node2D in soldiers:
		if not soldier.at_post():
			continue
		var target := {}
		var reach: float = ARROW_RANGE - soldier.position.y * HEIGHT_RANGE
		if soldier.melee:
			reach = SPEAR_REACH if palisade_holds() else MELEE_REACH + 2.0
		for raider in _raiders:
			if raider.fallen < 0.0 and absf(raider.x - soldier.position.x) <= reach \
					and (target.is_empty() or absf(raider.x - soldier.position.x) < absf(target.x - soldier.position.x)):
				target = raider
		if target.is_empty():
			continue
		if soldier.melee:
			soldier.strike()
			_hit(target, SPEAR_DAMAGE * soldier.might() * delta)
		elif soldier.ready_to_shoot(delta, SHOT_GAP):
			_arrows.append({"from": soldier.position + Vector2(0, -12), "to": Vector2(target.x, -8), "age": 0.0, "target": target, "damage": ARROW_DAMAGE * soldier.might()})
			get_tree().call_group("sfx", "play", "arrow")


func _fly_arrows(delta: float) -> void:
	for arrow in _arrows:
		arrow.age += delta
		if arrow.age >= ARROW_TIME:
			_hit(arrow.target, arrow.damage)
	_arrows = _arrows.filter(func(arrow: Dictionary) -> bool: return arrow.age < ARROW_TIME)


func _hit(raider: Dictionary, damage: float) -> void:
	if raider.fallen >= 0.0:
		return
	raider.hp -= damage
	if raider.hp <= 0.0:
		raider.fallen = 0.0
		get_tree().call_group("effects", "burst", to_global(Vector2(raider.x, -8)), _kind.get("body", BODY), 4)
		_report()


## Fallen raiders lie for a moment, then are gone. When none are left
## standing, the raid is beaten.
func _clear_fallen(delta: float) -> void:
	for raider in _raiders:
		if raider.fallen >= 0.0:
			raider.fallen += delta
	_raiders = _raiders.filter(func(raider: Dictionary) -> bool: return raider.fallen < FALL_TIME)
	if _standing() == 0 and GameState.raid_incoming:
		GameState.raid_beaten()


func _standing() -> int:
	return _raiders.filter(func(raider: Dictionary) -> bool: return raider.fallen < 0.0).size()


func _report() -> void:
	GameState.raiders_left = _standing()
	GameState.raid_progress.emit()


func _draw() -> void:
	if GameState.raid_incoming and _palisade_max > 0.0:
		var x := CastleData.PALISADE_X
		if palisade_holds():
			if _palisade_hp < _palisade_max:
				# How much more the palisade can take.
				draw_rect(Rect2(x - 16, -52, 32, 3), BAR_BACK)
				draw_rect(Rect2(x - 15, -51, 30.0 * _palisade_hp / _palisade_max, 1), BAR)
		else:
			# A gap hacked through the middle, and the stakes lying about.
			draw_rect(Rect2(x - 9, -60, 18, 60), GRASS)
			draw_rect(Rect2(x - 14, -3, 12, 2), CastleData.WOOD)
			draw_rect(Rect2(x + 1, -2, 13, 2), CastleData.WOOD_DARK)
	for raider in _raiders:
		var x: float = raider.x
		if raider.fallen >= 0.0:
			# Lying on the ground.
			draw_rect(Rect2(x - 6, -4, 12, 4), Color(_kind.get("body", BODY), 1.0 - raider.fallen / FALL_TIME))
			continue
		var body: Color = _kind.get("body", BODY)
		draw_rect(Rect2(x - 3, -10, 6, 10), body)
		draw_rect(Rect2(x - 2, -14, 4, 4), SKIN)
		draw_rect(Rect2(x + 4, -16, 1, 14), BLADE)
		if _kind.get("armour", "") is Color:
			# A helmet and a mail shirt.
			draw_rect(Rect2(x - 3, -15, 6, 2), _kind.armour)
			draw_rect(Rect2(x - 3, -10, 6, 4), _kind.armour)
		if _kind.get("shield", false):
			draw_rect(Rect2(x + 2, -11, 4, 7), CastleData.WOOD)
			draw_rect(Rect2(x + 3, -9, 2, 3), body)
		if raider.hp < raider.max:
			draw_rect(Rect2(x - 4, -19, 8, 2), BAR_BACK)
			draw_rect(Rect2(x - 4, -19, 8.0 * raider.hp / raider.max, 2), BAR)
	for arrow in _arrows:
		var along: float = arrow.age / ARROW_TIME
		var at: Vector2 = arrow.from.lerp(arrow.to, along) + Vector2(0, -sin(along * PI) * 10.0)
		var ahead: Vector2 = arrow.from.lerp(arrow.to, minf(along + 0.12, 1.0)) + Vector2(0, -sin(minf(along + 0.12, 1.0) * PI) * 10.0)
		draw_line(at, ahead, ARROW, 1.0)
