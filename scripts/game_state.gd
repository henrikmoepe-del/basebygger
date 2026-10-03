extends Node
## Global game data (autoload). Scenes read and change the game through this,
## so the 2D builder and the later 3D mode can share the same state.

signal resources_changed
signal castle_changed
signal build_progress_changed
signal peasants_changed
signal trees_changed
signal builders_changed
signal upgrades_changed

const CastleData = preload("res://scripts/castle_data.gd")
const PEASANT_BASE_COST := 10
const PEASANT_COST_GROWTH := 1.5
const START_TREES := 2
const MAX_TREES := 8
const TREE_BASE_COST := 8
const TREE_COST_GROWTH := 1.6
const START_BUILDERS := 1
const BUILDER_BASE_COST := 20
const BUILDER_COST_GROWTH := 1.7
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL := 10.0
const MAX_OFFLINE_SECONDS := 8 * 3600
## Offline progress is only granted (and reported) after this long away.
const MIN_OFFLINE_SECONDS := 60
## Peasant income is averaged over this many seconds.
const INCOME_WINDOW := 30.0

## Upgrades can be bought again and again; each level costs "growth" times more.
const UPGRADES := {
	"peasant_speed": {"name": "Faster Peasants", "cost": {"wood": 20}, "growth": 1.8},
	"carry": {"name": "Bigger Baskets", "cost": {"wood": 25, "stone": 25}, "growth": 2.0},
	"builder_speed": {"name": "Better Hammers", "cost": {"stone": 30}, "growth": 1.8},
}

var resources := {"wood": 0, "stone": 0}
## How many castle pieces are finished, in CastleData.PIECES order.
var built_count := 0
## True while the next piece is paid for and under construction.
var building := false
## Seconds of builder work done on the piece under construction.
var build_progress := 0.0
var peasants := 0
var trees := START_TREES
var builders := START_BUILDERS
var upgrades := {"peasant_speed": 0, "carry": 0, "builder_speed": 0}

## Measured resources per second brought in by peasants. Used for offline progress.
var income_rate := {"wood": 0.0, "stone": 0.0}
## Filled in by load_game() when time away earned something:
## {"seconds": int, "wood": int, "stone": int}. Empty otherwise.
var offline_report := {}
var save_path := "user://save.json"

var _window_income := {"wood": 0, "stone": 0}
var _window_time := 0.0
var _autosave_time := 0.0


func _ready() -> void:
	# Tests pass "-- --save=<path>" so they never touch the real save file.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			save_path = arg.trim_prefix("--save=")
	load_game()


func _process(delta: float) -> void:
	if building:
		_advance_build(build_rate() * delta)

	_window_time += delta
	if _window_time >= INCOME_WINDOW:
		for type: String in _window_income:
			income_rate[type] = _window_income[type] / _window_time
			_window_income[type] = 0
		_window_time = 0.0

	_autosave_time += delta
	if _autosave_time >= AUTOSAVE_INTERVAL:
		_autosave_time = 0.0
		save_game()


func _notification(what: int) -> void:
	# Save when the player closes the window.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func add_resource(type: String, amount: int) -> void:
	resources[type] += amount
	resources_changed.emit()


## Like add_resource, but also counted towards the measured peasant income.
func add_peasant_income(type: String, amount: int) -> void:
	_window_income[type] += amount
	add_resource(type, amount)


func can_afford(cost: Dictionary) -> bool:
	for type: String in cost:
		if resources[type] < cost[type]:
			return false
	return true


## Pays the cost if affordable. Returns false (and takes nothing) if not.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for type: String in cost:
		resources[type] -= cost[type]
	resources_changed.emit()
	return true


# --- Castle ---

## The next piece to build (or being built), or an empty Dictionary when the castle is done.
func next_piece() -> Dictionary:
	if built_count >= CastleData.PIECES.size():
		return {}
	return CastleData.PIECES[built_count]


## Pays for the next piece and puts the builders to work on it.
func start_build() -> bool:
	var piece := next_piece()
	if building or piece.is_empty() or not spend(piece.cost):
		return false
	building = true
	build_progress = 0.0
	castle_changed.emit()
	return true


## Work done per second by all builders together.
func build_rate() -> float:
	return builders * (1.0 + 0.25 * upgrades.builder_speed)


## How far along the current piece is, from 0 to 1.
func build_fraction() -> float:
	if not building:
		return 0.0
	return clampf(build_progress / next_piece().work, 0.0, 1.0)


## Sum of the defence of every finished piece. The 3D mode will use this.
func total_defence() -> int:
	var total := 0
	for i in built_count:
		total += CastleData.PIECES[i].defence
	return total


func _advance_build(work: float) -> void:
	build_progress += work
	if build_progress >= next_piece().work:
		building = false
		build_progress = 0.0
		built_count += 1
		castle_changed.emit()
	build_progress_changed.emit()


# --- Things to buy ---

## Each peasant costs more than the last (the classic incremental curve).
func peasant_cost() -> Dictionary:
	return {"wood": ceili(PEASANT_BASE_COST * pow(PEASANT_COST_GROWTH, peasants))}


func hire_peasant() -> bool:
	if not spend(peasant_cost()):
		return false
	peasants += 1
	peasants_changed.emit()
	return true


## Cost of the next tree, or an empty Dictionary when the grove is full.
func tree_cost() -> Dictionary:
	if trees >= MAX_TREES:
		return {}
	return {"wood": ceili(TREE_BASE_COST * pow(TREE_COST_GROWTH, trees - START_TREES))}


func plant_tree() -> bool:
	if trees >= MAX_TREES or not spend(tree_cost()):
		return false
	trees += 1
	trees_changed.emit()
	return true


func builder_cost() -> Dictionary:
	return {"stone": ceili(BUILDER_BASE_COST * pow(BUILDER_COST_GROWTH, builders - START_BUILDERS))}


func hire_builder() -> bool:
	if not spend(builder_cost()):
		return false
	builders += 1
	builders_changed.emit()
	return true


func upgrade_cost(id: String) -> Dictionary:
	var upgrade: Dictionary = UPGRADES[id]
	var cost := {}
	for type: String in upgrade.cost:
		cost[type] = ceili(upgrade.cost[type] * pow(upgrade.growth, upgrades[id]))
	return cost


func buy_upgrade(id: String) -> bool:
	if not spend(upgrade_cost(id)):
		return false
	upgrades[id] += 1
	upgrades_changed.emit()
	return true


# --- What the upgrades do ---

func peasant_speed_mult() -> float:
	return 1.0 + 0.2 * upgrades.peasant_speed


## How many resources a peasant carries per trip.
func carry_amount() -> int:
	return 1 + upgrades.carry


# --- Save and load ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"resources": resources,
		"built_count": built_count,
		"building": building,
		"build_progress": build_progress,
		"peasants": peasants,
		"trees": trees,
		"builders": builders,
		"upgrades": upgrades,
		"income_rate": income_rate,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save to %s" % save_path)
		return
	file.store_string(JSON.stringify(data, "	"))


## Loads the save file if there is one, then grants offline progress.
func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		push_warning("Save file %s is damaged; starting fresh" % save_path)
		return

	# JSON has no integers, so numbers come back as floats and are converted.
	# Missing or out-of-range values fall back to something safe.
	_load_numbers(resources, data.get("resources"), true)
	_load_numbers(upgrades, data.get("upgrades"), true)
	_load_numbers(income_rate, data.get("income_rate"), false)
	built_count = clampi(int(data.get("built_count", 0)), 0, CastleData.PIECES.size())
	peasants = maxi(int(data.get("peasants", 0)), 0)
	trees = clampi(int(data.get("trees", START_TREES)), START_TREES, MAX_TREES)
	builders = maxi(int(data.get("builders", START_BUILDERS)), START_BUILDERS)
	building = bool(data.get("building", false)) and not next_piece().is_empty()
	build_progress = maxf(float(data.get("build_progress", 0.0)), 0.0) if building else 0.0

	var now := Time.get_unix_time_from_system()
	_grant_offline_progress(now - float(data.get("saved_at", now)))


## Copies saved numbers into target, only for keys target already has.
func _load_numbers(target: Dictionary, saved: Variant, as_int: bool) -> void:
	if not saved is Dictionary:
		return
	for key: String in target:
		var value := maxf(float(saved.get(key, target[key])), 0.0)
		target[key] = int(value) if as_int else value


func _grant_offline_progress(seconds_away: float) -> void:
	offline_report = {}
	var seconds := minf(seconds_away, MAX_OFFLINE_SECONDS)
	if seconds < MIN_OFFLINE_SECONDS:
		return
	var report := {"seconds": int(seconds)}
	var earned_any := false
	for type: String in income_rate:
		var gained := int(income_rate[type] * seconds)
		resources[type] += gained
		report[type] = gained
		earned_any = earned_any or gained > 0
	if building:
		# Builders kept working, but only on the piece that was already paid for.
		_advance_build(build_rate() * seconds)
	if earned_any:
		offline_report = report
