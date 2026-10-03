extends Node
## Global game data (autoload). Scenes read and change the game through this,
## so the 2D builder and the later 3D mode can share the same state.

signal resources_changed
## A castle part was ordered or finished.
signal castle_changed
signal job_progress_changed
## Builders dropped materials at the building site.
signal job_delivered
signal peasants_changed
signal trees_changed
signal builders_changed
signal upgrades_changed

const CastleData = preload("res://scripts/castle_data.gd")
const PEASANT_BASE_COST := 10
const PEASANT_COST_GROWTH := 1.4
const PEASANT_BASE_CARRY := 2
const START_TREES := 2
const MAX_TREES := 8
const TREE_BASE_COST := 8
const TREE_COST_GROWTH := 1.6
const START_BUILDERS := 1
const BUILDER_BASE_COST := 20
const BUILDER_COST_GROWTH := 1.7
## How many units of material a builder carries per trip.
const BUILDER_LOAD := 4

## No part can go above LEVELS_PER_RANK x castle rank. The rank rises with the
## total of all part levels, so the player must spread out before going higher.
const LEVELS_PER_RANK := 5
const FIRST_RANK_UP := 12
const RANK_UP_STEP := 16

const SAVE_VERSION := 2
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

## What is in the stockhouse.
var resources := {"wood": 0, "stone": 0}
var part_levels := {"walls": 0, "towers": 0, "gate": 0, "keep": 0}
var peasants := 0
var trees := START_TREES
var builders := START_BUILDERS
var upgrades := {"peasant_speed": 0, "carry": 0, "builder_speed": 0}

## The building job: the one part being raised a level right now ("" = none).
## Its materials are paid for when ordered, then builders haul them from the
## stockhouse to the site, and can only hammer in what has arrived.
var job_part := ""
var job_units := 0        ## Material units the job needs in total.
var job_claimed := 0      ## Units builders have picked up so far.
var job_hauled := 0       ## Units that have arrived at the site.
var job_work := 0.0       ## Seconds of hammering done.
var job_work_total := 0.0

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


# --- Castle parts and rank ---

func total_levels() -> int:
	var total := 0
	for id: String in part_levels:
		total += part_levels[id]
	return total


func castle_rank() -> int:
	var total := total_levels()
	if total < FIRST_RANK_UP:
		return 1
	return 2 + (total - FIRST_RANK_UP) / RANK_UP_STEP


## The highest level any part may reach at the current rank.
func level_cap() -> int:
	return LEVELS_PER_RANK * castle_rank()


## Total part levels needed to reach the next rank.
func levels_for_next_rank() -> int:
	return FIRST_RANK_UP + RANK_UP_STEP * (castle_rank() - 1)


## Materials for the part's next level.
func part_cost(id: String) -> Dictionary:
	return _scaled_cost(CastleData.PARTS[id].cost, CastleData.COST_GROWTH, part_levels[id])


## Seconds of hammering for the part's next level.
func part_work(id: String) -> float:
	return CastleData.PARTS[id].work * pow(CastleData.WORK_GROWTH, part_levels[id])


## Why the part can't be ordered right now (apart from cost), or "" if it can.
func part_block_reason(id: String) -> String:
	if job_part != "":
		return "Builders are busy"
	if id != "walls" and part_levels.walls == 0:
		return "Needs Walls first"
	if part_levels[id] >= level_cap():
		return "Raise castle rank"
	return ""


## Sum of every part's defence. The 3D mode will use this and the part levels.
func total_defence() -> int:
	var total := 0
	for id: String in part_levels:
		total += part_levels[id] * CastleData.PARTS[id].defence
	return total


# --- The building job ---

## Pays for the part's next level and gives the builders the job.
func order_part(id: String) -> bool:
	if part_block_reason(id) != "":
		return false
	var cost := part_cost(id)
	if not spend(cost):
		return false
	job_part = id
	job_units = 0
	for type: String in cost:
		job_units += cost[type]
	job_claimed = 0
	job_hauled = 0
	job_work = 0.0
	job_work_total = part_work(id)
	castle_changed.emit()
	return true


## A builder at the stockhouse picks up to max_units for the job.
## Returns how many they got (0 = nothing left to carry).
func job_take_load(max_units: int) -> int:
	var units := mini(max_units, job_units - job_claimed)
	job_claimed += units
	return units


func job_deliver(units: int) -> void:
	job_hauled += units
	job_delivered.emit()
	job_progress_changed.emit()


## True if there is delivered material that hasn't been hammered in yet.
func job_can_hammer() -> bool:
	return job_part != "" and job_work < _job_work_allowed()


func job_add_work(seconds: float) -> void:
	job_work = minf(job_work + seconds, _job_work_allowed())
	if job_hauled >= job_units and job_work >= job_work_total:
		part_levels[job_part] += 1
		job_part = ""
		castle_changed.emit()
	job_progress_changed.emit()


## How far along the job is, from 0 to 1.
func job_fraction() -> float:
	if job_part == "":
		return 0.0
	return clampf(job_work / job_work_total, 0.0, 1.0)


## Seconds of hammering one builder does per second.
func hammer_rate() -> float:
	return 1.0 + 0.25 * upgrades.builder_speed


func _job_work_allowed() -> float:
	if job_hauled >= job_units:
		return job_work_total
	return job_work_total * job_hauled / job_units


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
	return _scaled_cost(UPGRADES[id].cost, UPGRADES[id].growth, upgrades[id])


func buy_upgrade(id: String) -> bool:
	if not spend(upgrade_cost(id)):
		return false
	upgrades[id] += 1
	upgrades_changed.emit()
	return true


func _scaled_cost(base: Dictionary, growth: float, level: int) -> Dictionary:
	var cost := {}
	for type: String in base:
		cost[type] = ceili(base[type] * pow(growth, level))
	return cost


# --- What the upgrades do ---

func peasant_speed_mult() -> float:
	return 1.0 + 0.2 * upgrades.peasant_speed


## How many resources a peasant carries per trip.
func carry_amount() -> int:
	return PEASANT_BASE_CARRY + upgrades.carry


# --- Save and load ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"resources": resources,
		"part_levels": part_levels,
		"peasants": peasants,
		"trees": trees,
		"builders": builders,
		"upgrades": upgrades,
		"income_rate": income_rate,
		"job": {
			"part": job_part, "units": job_units, "hauled": job_hauled,
			"work": job_work, "work_total": job_work_total,
		},
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save to %s" % save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))


## Loads the save file if there is one, then grants offline progress.
func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Save file %s is damaged or from an older version; starting fresh" % save_path)
		return

	# JSON has no integers, so numbers come back as floats and are converted.
	# Missing or out-of-range values fall back to something safe.
	_load_numbers(resources, data.get("resources"), true)
	_load_numbers(part_levels, data.get("part_levels"), true)
	_load_numbers(upgrades, data.get("upgrades"), true)
	_load_numbers(income_rate, data.get("income_rate"), false)
	peasants = maxi(int(data.get("peasants", 0)), 0)
	trees = clampi(int(data.get("trees", START_TREES)), START_TREES, MAX_TREES)
	builders = maxi(int(data.get("builders", START_BUILDERS)), START_BUILDERS)

	var job: Variant = data.get("job")
	if job is Dictionary and part_levels.has(job.get("part", "")) and float(job.get("work_total", 0.0)) > 0.0:
		job_part = job.part
		job_units = maxi(int(job.get("units", 1)), 1)
		job_hauled = clampi(int(job.get("hauled", 0)), 0, job_units)
		# Loads that were being carried when the game closed go back to the stockhouse.
		job_claimed = job_hauled
		job_work_total = float(job.work_total)
		job_work = clampf(float(job.get("work", 0.0)), 0.0, _job_work_allowed())

	var now := Time.get_unix_time_from_system()
	_grant_offline_progress(now - float(data.get("saved_at", now)))


## Copies saved numbers into target, only for keys target already has.
func _load_numbers(target: Dictionary, saved: Variant, as_int: bool) -> void:
	if not saved is Dictionary:
		return
	for key: String in target:
		var value := maxf(float(saved.get(key, target[key])), 0.0)
		target[key] = int(value) if as_int else value


## Peasants keep gathering while the game is closed. Builders don't build.
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
	if earned_any:
		offline_report = report
