extends Node3D
## The 3D siege: the castle the player built in 2D, rebuilt from simple boxes,
## holding off waves of raiders. Everything here is made in code from
## GameState, so the castle's part levels and soldiers decide how it looks
## and how well it fights. When it is over, GameState.finish_siege gives the
## reward or takes the loss, and the player goes back to the 2D game.
##
## Layout: the wall runs along the z axis at x = 0 with the gate in the
## middle. Raiders come from +x (the right of the screen). The keep and the
## rest of the castle are behind the wall, at negative x.

const WAVES := 5
const WAVE_GAP := 4.0
const SPAWN_GAP := 0.8
const SPAWN_X := 40.0
const ENEMY_SPEED := 3.4
const ENEMY_BASE_HP := 18.0
## Each raid the castle has faced makes the raiders this much tougher.
const ENEMY_HP_GROWTH := 1.15
const ENEMY_DPS := 5.0
const ARCHER_RANGE := 20.0
const ARCHER_COOLDOWN := 1.2
const ARROW_TIME := 0.25
const GATE_X := 1.2
const PALISADE_X := 9.0

const GRASS := Color(0.42, 0.62, 0.32)
const DIRT := Color(0.55, 0.45, 0.30)
const STONE := Color(0.66, 0.66, 0.70)
const STONE_DARK := Color(0.50, 0.50, 0.55)
const WOOD := Color(0.48, 0.32, 0.20)
const ROOF := Color(0.62, 0.30, 0.24)
const ARCHER := Color(0.25, 0.35, 0.70)
const RAIDER := Color(0.75, 0.15, 0.15)
const ARROW := Color(0.95, 0.90, 0.70)

var _gate_hp := 0.0
var _gate_max := 0.0
var _palisade_hp := 0.0
## Each raider: {"node": Node3D, "hp": float}
var _enemies: Array[Dictionary] = []
## Each archer: {"pos": Vector3, "cooldown": float}
var _archers: Array[Dictionary] = []
## Each arrow in flight: {"node": Node3D, "from": Vector3, "to": Vector3, "t": float}
var _arrows: Array[Dictionary] = []
var _wave := 0
var _to_spawn := 0
var _spawn_timer := 0.0
var _gap_timer := 0.0
var _done := false
var _arrow_damage := 0.0
var _enemy_hp := 0.0
var _status := Label.new()
var _result := Label.new()
var _back := Button.new()


func _ready() -> void:
	_build_world()
	_build_castle()
	_build_ui()
	_enemy_hp = ENEMY_BASE_HP * pow(ENEMY_HP_GROWTH, GameState.raids_faced)
	# Soldiers' training and skills make every arrow count for more.
	_arrow_damage = 2.0 + GameState.soldier_defence() * 0.75
	_start_wave()


func _process(delta: float) -> void:
	_update_arrows(delta)
	if _done:
		return
	_spawn(delta)
	_move_enemies(delta)
	_shoot(delta)
	_check_waves(delta)
	_status.text = "Wave %d / %d     Raiders left: %d     Gate: %d / %d%s" % [
		_wave, WAVES, _enemies.size() + _to_spawn, ceili(_gate_hp), _gate_max,
		"     Palisade: %d" % ceili(_palisade_hp) if _palisade_hp > 0.0 else ""]


# --- Building the scene ---

func _build_world() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(16, 30, 21)
	add_child(camera)
	camera.look_at(Vector3(16, 0, -2))
	camera.fov = 50

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.93, 0.92, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.70)
	environment.ambient_light_energy = 0.6
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	_box(Vector3(120, 0.2, 60), Vector3(10, -0.1, 0), GRASS)
	# The road the raiders come along.
	_box(Vector3(SPAWN_X, 0.05, 5), Vector3(SPAWN_X / 2 + 1, 0.02, 0), DIRT)


func _build_castle() -> void:
	var levels: Dictionary = GameState.part_levels
	var wall_height: float = 1.2 + 0.4 * levels.walls
	_box(Vector3(1.4, wall_height, 22), Vector3(0, wall_height / 2, 0), STONE if levels.walls > 0 else WOOD)
	_box(Vector3(1.7, 2.4, 3), Vector3(0.1, 1.2, 0), WOOD)
	_gate_max = 60 + 40 * levels.gate + 15 * levels.walls
	_gate_hp = _gate_max

	var tower_height: float = wall_height + 2.0 + 0.5 * levels.towers
	if levels.towers > 0:
		for z in [-11.5, 11.5]:
			_box(Vector3(3.2, tower_height, 3.2), Vector3(0, tower_height / 2, z), STONE)
			for i in 1 + levels.towers / 2:
				_add_archer(Vector3(0, tower_height + 0.5, z + (i - 0.5) * 0.8))
	if levels.keep > 0:
		var keep_height: float = 4.0 + 0.7 * levels.keep
		_box(Vector3(6, keep_height, 6), Vector3(-7, keep_height / 2, 0), STONE_DARK)
	if levels.garrison > 0:
		_box(Vector3(4, 2.5, 3), Vector3(-4, 1.25, 6.5), STONE_DARK)
		_box(Vector3(4.4, 0.6, 3.4), Vector3(-4, 2.8, 6.5), ROOF)
	if levels.court > 0:
		_box(Vector3(4, 2.5, 3), Vector3(-4, 1.25, -6.5), Color(0.86, 0.82, 0.70))
	if levels.palisade > 0:
		var stake_height: float = 1.2 + 0.15 * levels.palisade
		for i in 24:
			_box(Vector3(0.4, stake_height, 0.4), Vector3(PALISADE_X, stake_height / 2, -9.2 + i * 0.8), WOOD)
		_palisade_hp = 25.0 * levels.palisade
	if levels.watchtower > 0:
		var watch_height: float = 3.0 + 0.4 * levels.watchtower
		_box(Vector3(1.2, watch_height, 1.2), Vector3(7, watch_height / 2, -9), WOOD)
		_box(Vector3(2.4, 0.4, 2.4), Vector3(7, watch_height, -9), WOOD)
		for i in levels.watchtower:
			_add_archer(Vector3(7, watch_height + 0.6, -9.6 + i * 0.6))

	# Soldiers line the wall top; a trained one counts as two.
	var soldiers: int = GameState.jobs.soldier + GameState.trained.soldier
	for i in soldiers:
		var z := -9.0 + 18.0 * (i + 0.5) / soldiers
		_add_archer(Vector3(0, wall_height + 0.5, z))
	# The lord always shoots from above the gate, so the castle is never helpless.
	_add_archer(Vector3(0, wall_height + 0.5, 0))


func _add_archer(pos: Vector3) -> void:
	_box(Vector3(0.5, 0.9, 0.5), pos, ARCHER)
	_archers.append({"pos": pos, "cooldown": randf() * ARCHER_COOLDOWN})


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	add_child(node)
	return node


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status.position = Vector2(10, 8)
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
	layer.add_child(_status)
	_result.position = Vector2(0, 130)
	_result.size = Vector2(640, 40)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 22)
	_result.add_theme_constant_override("outline_size", 6)
	_result.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	_result.hide()
	layer.add_child(_result)
	_back.text = "Back to the castle"
	_back.position = Vector2(250, 190)
	_back.size = Vector2(140, 30)
	_back.hide()
	_back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	layer.add_child(_back)


# --- The fight ---

func _start_wave() -> void:
	_wave += 1
	_to_spawn = 4 + 2 * _wave + GameState.raids_faced
	_spawn_timer = 0.0


func _spawn(delta: float) -> void:
	if _to_spawn <= 0 or _gap_timer > 0.0:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_GAP
	_to_spawn -= 1
	var node := _box(Vector3(0.6, 1.1, 0.6), Vector3(SPAWN_X, 0.55, randf_range(-5.0, 5.0)), RAIDER)
	_enemies.append({"node": node, "hp": _enemy_hp})


func _move_enemies(delta: float) -> void:
	for enemy in _enemies:
		var node: Node3D = enemy.node
		# The palisade is in the way until it is broken; then the gate.
		var target_x := PALISADE_X + 0.6 if _palisade_hp > 0.0 else GATE_X + 0.6
		if node.position.x <= target_x + 0.05:
			if _palisade_hp > 0.0:
				_palisade_hp -= ENEMY_DPS * delta
			else:
				_gate_hp -= ENEMY_DPS * delta
			# A little shove to show they are hacking at it.
			node.position.y = 0.55 + absf(sin(Time.get_ticks_msec() / 90.0 + node.position.z)) * 0.15
			continue
		node.position.x = maxf(node.position.x - ENEMY_SPEED * delta, target_x)
		# Close to the gate, they bunch up in front of it.
		if _palisade_hp <= 0.0 and node.position.x < 10.0:
			node.position.z = move_toward(node.position.z, clampf(node.position.z, -1.2, 1.2), ENEMY_SPEED * delta)


func _shoot(delta: float) -> void:
	for archer in _archers:
		archer.cooldown -= delta
		if archer.cooldown > 0.0:
			continue
		var target := _nearest_enemy(archer.pos)
		if target.is_empty():
			continue
		archer.cooldown = ARCHER_COOLDOWN
		target.hp -= _arrow_damage
		_fire_arrow(archer.pos, target.node.position)
	# Clear away the fallen.
	for enemy in _enemies.duplicate():
		if enemy.hp <= 0.0:
			enemy.node.queue_free()
			_enemies.erase(enemy)


func _nearest_enemy(from: Vector3) -> Dictionary:
	var best := {}
	var best_distance := ARCHER_RANGE
	for enemy in _enemies:
		var distance := from.distance_to(enemy.node.position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


func _fire_arrow(from: Vector3, to: Vector3) -> void:
	var node := _box(Vector3(0.15, 0.15, 0.15), from, ARROW)
	_arrows.append({"node": node, "from": from, "to": to, "t": 0.0})


func _update_arrows(delta: float) -> void:
	for arrow in _arrows.duplicate():
		arrow.t += delta / ARROW_TIME
		if arrow.t >= 1.0:
			arrow.node.queue_free()
			_arrows.erase(arrow)
		else:
			# A short arc on the way.
			arrow.node.position = arrow.from.lerp(arrow.to, arrow.t) + Vector3.UP * sin(arrow.t * PI) * 1.5


func _check_waves(delta: float) -> void:
	if _gate_hp <= 0.0:
		_end(false)
		return
	if _to_spawn > 0 or not _enemies.is_empty():
		return
	if _wave >= WAVES:
		_end(true)
		return
	if _gap_timer <= 0.0:
		_gap_timer = WAVE_GAP
	_gap_timer -= delta
	if _gap_timer <= 0.0:
		_gap_timer = 0.0
		_start_wave()


func _end(won: bool) -> void:
	_done = true
	GameState.finish_siege(won)
	_result.text = "The castle holds!" if won else "The gate has fallen..."
	_result.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6) if won else Color(1.0, 0.5, 0.45))
	_result.show()
	_back.show()
