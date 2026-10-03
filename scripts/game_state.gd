extends Node
## Global game data (autoload). Scenes read and change the game through this,
## so the 2D builder and the later 3D mode can share the same state.

signal resources_changed
## A castle part was ordered or finished.
signal castle_changed
signal job_progress_changed
## Builders dropped materials at the building site.
signal job_delivered
## A peasant was hired or moved to another job.
signal peasants_changed
signal trees_changed
## A skill was bought or renown changed.
signal skills_changed
## Dawn or dusk arrived, or the peasants ate.
signal daytime_changed

const CastleData = preload("res://scripts/castle_data.gd")
const SkillData = preload("res://scripts/skill_data.gd")
const JobData = preload("res://scripts/job_data.gd")

const START_JOBS := {"wood": 1, "stone": 1, "hunter": 1, "build": 1, "forester": 0, "cook": 0}
const START_PEASANTS := 4
const PEASANT_BASE_COST := 10
const PEASANT_COST_GROWTH := 1.25
const PEASANT_BASE_CARRY := 2
## Hunters walk a long way, so they bring back more per trip.
const HUNTER_EXTRA_CARRY := 2

## A day lasts DAY_LENGTH seconds; the last part of it is night, when
## everyone sleeps. Night begins at NIGHT_START (a fraction of the day).
const DAY_LENGTH := 120.0
const NIGHT_START := 0.72
const START_FOOD := 12
## Every peasant eats this much at dawn. If there isn't enough, everyone
## goes hungry and works at HUNGRY_WORK_MULT until the next dawn.
const FOOD_PER_PEASANT := 2.0
const HUNGRY_WORK_MULT := 0.6
const COOK_FOOD_SAVING := 0.08
const MAX_USEFUL_COOKS := 6
const START_TREES := 3
## Trees the grove has room for before any skills. The screen fits MAX_TREE_PLOTS.
const BASE_TREE_PLOTS := 8
const MAX_TREE_PLOTS := 12
## Seconds of forester work to plant a tree; each further tree takes longer.
const PLANT_BASE_TIME := 8.0
const PLANT_TIME_GROWTH := 1.35
## How much each forester speeds up regrowth by tending the grove.
const FORESTER_TEND_BONUS := 0.15
## How many units of material a builder carries per trip.
const BUILDER_BASE_LOAD := 4
## Renown pays for skills. It is earned by building the castle.
const RENOWN_PER_RANK := 3

## No part can go above LEVELS_PER_RANK x castle rank. The rank rises with the
## total of all part levels, so the player must spread out before going higher.
const LEVELS_PER_RANK := 5
const FIRST_RANK_UP := 18
const RANK_UP_STEP := 24

const SAVE_VERSION := 4
const AUTOSAVE_INTERVAL := 10.0
const MAX_OFFLINE_SECONDS := 8 * 3600
## Offline progress is only granted (and reported) after this long away.
const MIN_OFFLINE_SECONDS := 60
## Income is averaged over a whole day, so it includes the night.
const INCOME_WINDOW := DAY_LENGTH

## What is in the stockhouse.
var resources := {"wood": 0, "stone": 0, "food": START_FOOD}
var part_levels := {"walls": 0, "towers": 0, "gate": 0, "keep": 0, "garrison": 0, "court": 0}
var peasants := START_PEASANTS
## How many peasants are assigned to each job. The rest are idle.
var jobs := START_JOBS.duplicate()
var trees := START_TREES
## Seconds of forester work done on the next tree.
var planting_work := 0.0
var renown := 0
## Days start at 1. day_time is the seconds since this day's dawn.
var day := 1
var day_time := 0.0
## False if there wasn't enough food at dawn today.
var fed := true
## Ids of the skills the player owns.
var skills: Array[String] = []

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
var income_rate := {"wood": 0.0, "stone": 0.0, "food": 0.0}
## Filled in by load_game() when time away earned something:
## {"seconds": int, plus the amount gained of each resource}. Empty otherwise.
var offline_report := {}
var save_path := "user://save.json"

var _window_income := {"wood": 0, "stone": 0, "food": 0}
var _was_night := false
var _window_time := 0.0
var _autosave_time := 0.0


func _ready() -> void:
	# Tests pass "-- --save=<path>" so they never touch the real save file.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			save_path = arg.trim_prefix("--save=")
	load_game()


func _process(delta: float) -> void:
	day_time += delta
	if day_time >= DAY_LENGTH:
		day_time -= DAY_LENGTH
		day += 1
		_eat()
	if is_night() != _was_night:
		_was_night = is_night()
		daytime_changed.emit()

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


# --- Resources ---

## Peasants deliver to the stockhouse through this, so income can be measured.
func add_income(type: String, amount: int) -> void:
	_window_income[type] += amount
	resources[type] += amount
	resources_changed.emit()


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


# --- Day, night and food ---

## How far through the day it is, from 0 (dawn) to 1 (the next dawn).
func day_fraction() -> float:
	return day_time / DAY_LENGTH


## The fraction of the day at which night begins.
func night_start() -> float:
	return NIGHT_START + skill_total("night_shorter")


func is_night() -> bool:
	return day_fraction() >= night_start()


## How much food the peasants eat at dawn.
func food_needed() -> int:
	var saving: float = mini(jobs.cook, MAX_USEFUL_COOKS) * COOK_FOOD_SAVING + skill_total("food_saving")
	return ceili(peasants * FOOD_PER_PEASANT * (1.0 - saving))


## Multiplies how fast everyone walks and works: slower when hungry.
func work_mult() -> float:
	if not fed:
		return HUNGRY_WORK_MULT
	return 1.0 + skill_total("fed_bonus")


func _eat() -> void:
	var needed := food_needed()
	fed = resources.food >= needed
	resources.food = maxi(resources.food - needed, 0)
	resources_changed.emit()
	daytime_changed.emit()


# --- Peasants and their jobs ---

func idle_peasants() -> int:
	var busy := 0
	for job: String in jobs:
		busy += jobs[job]
	return peasants - busy


## Each peasant costs more than the last (the classic incremental curve).
func peasant_cost() -> Dictionary:
	var discount := 1.0 - skill_total("peasant_discount")
	# A grander court draws people in.
	discount *= pow(1.0 - CastleData.COURT_HIRE_DISCOUNT, part_levels.court)
	var growth := pow(PEASANT_COST_GROWTH, peasants - START_PEASANTS)
	return {"wood": ceili(PEASANT_BASE_COST * growth * discount), "food": 2 + peasants - START_PEASANTS}


## Hires a peasant. They start idle until given a job.
func hire_peasant() -> bool:
	if not spend(peasant_cost()):
		return false
	peasants += 1
	peasants_changed.emit()
	return true


## Some jobs only exist once a skill is owned (see "requires_skill" in JobData).
func job_unlocked(job: String) -> bool:
	var skill: String = JobData.JOBS[job].get("requires_skill", "")
	return skill == "" or skill in skills


## Moves one idle peasant into a job (change = 1) or one out of it (change = -1).
func assign(job: String, change: int) -> bool:
	if change > 0 and (idle_peasants() <= 0 or not job_unlocked(job)):
		return false
	if change < 0 and jobs[job] <= 0:
		return false
	jobs[job] += change
	peasants_changed.emit()
	return true


# --- The grove ---

## How many trees the grove has room for.
func max_trees() -> int:
	return mini(BASE_TREE_PLOTS + int(skill_total("tree_plots")), MAX_TREE_PLOTS)


## Seconds of forester work the next tree needs.
func plant_time() -> float:
	return PLANT_BASE_TIME * pow(PLANT_TIME_GROWTH, trees - START_TREES) / (1.0 + skill_total("plant_speed"))


## A forester at the next plot spent this long planting.
func add_planting_work(seconds: float) -> void:
	if trees >= max_trees():
		return
	planting_work += seconds
	if planting_work >= plant_time():
		planting_work = 0.0
		trees += 1
		trees_changed.emit()


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
	var cost := _scaled_cost(CastleData.PARTS[id].cost, CastleData.COST_GROWTH, part_levels[id])
	var discount := 1.0 - skill_total("part_discount")
	for type: String in cost:
		cost[type] = ceili(cost[type] * discount)
	return cost


## Seconds of hammering for the part's next level.
func part_work(id: String) -> float:
	var discount := 1.0 - skill_total("work_discount")
	return CastleData.PARTS[id].work * pow(CastleData.WORK_GROWTH, part_levels[id]) * discount


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


func _scaled_cost(base: Dictionary, growth: float, level: int) -> Dictionary:
	var cost := {}
	for type: String in base:
		cost[type] = ceili(base[type] * pow(growth, level))
	return cost


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


## A builder was reassigned mid-trip: their load goes back to the stockhouse.
func job_return_load(units: int) -> void:
	job_claimed = maxi(job_claimed - units, job_hauled)


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
		_finish_job()
	job_progress_changed.emit()


## How far along the job is, from 0 to 1.
func job_fraction() -> float:
	if job_part == "":
		return 0.0
	return clampf(job_work / job_work_total, 0.0, 1.0)


func _job_work_allowed() -> float:
	if job_hauled >= job_units:
		return job_work_total
	return job_work_total * job_hauled / job_units


func _finish_job() -> void:
	var rank_before := castle_rank()
	part_levels[job_part] += 1
	renown += CastleData.PARTS[job_part].renown
	if castle_rank() > rank_before:
		renown += RENOWN_PER_RANK + int(skill_total("rank_renown"))
	job_part = ""
	castle_changed.emit()
	skills_changed.emit()


# --- Skills ---

## Why the skill can't be bought right now, or "" if it can.
func skill_block_reason(id: String) -> String:
	var skill: Dictionary = SkillData.SKILLS[id]
	if id in skills:
		return "Owned"
	if skill.requires != "" and not skill.requires in skills:
		return "Needs %s" % SkillData.SKILLS[skill.requires].name
	if renown < skill.cost:
		return "Not enough renown"
	return ""


func buy_skill(id: String) -> bool:
	if skill_block_reason(id) != "":
		return false
	renown -= SkillData.SKILLS[id].cost
	skills.append(id)
	skills_changed.emit()
	# Skills change costs and speeds, so everything on screen refreshes.
	resources_changed.emit()
	return true


## Adds up one effect across all owned skills.
func skill_total(effect: String) -> float:
	var total := 0.0
	for id in skills:
		total += SkillData.SKILLS[id].effects.get(effect, 0.0)
	return total


# --- What skills do ---

func peasant_speed_mult() -> float:
	return (1.0 + skill_total("peasant_speed")) * work_mult()


## How many resources a gatherer with this job carries per trip.
func carry_amount(job: String) -> int:
	var amount := PEASANT_BASE_CARRY + int(skill_total("carry"))
	if job == "hunter":
		amount += HUNTER_EXTRA_CARRY + int(skill_total("hunter_carry"))
	return amount


## Multiplies how long a gatherer spends chopping or mining.
func gather_time_mult() -> float:
	return 1.0 / ((1.0 + skill_total("gather_speed")) * work_mult())


func tree_grow_mult() -> float:
	var tending: float = jobs.forester * (FORESTER_TEND_BONUS + skill_total("tend"))
	return 1.0 + skill_total("tree_growth") + tending


func tree_bonus_wood() -> int:
	return int(skill_total("tree_wood"))


## How many units of material a builder carries per trip.
func builder_load() -> int:
	return BUILDER_BASE_LOAD + int(skill_total("builder_load"))


func builder_speed_mult() -> float:
	return (1.0 + skill_total("peasant_speed") + skill_total("builder_speed")) * work_mult()


## Seconds of hammering one builder does per second.
func hammer_rate() -> float:
	return (1.0 + skill_total("hammer")) * work_mult()


# --- Save and load ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"resources": resources,
		"part_levels": part_levels,
		"peasants": peasants,
		"jobs": jobs,
		"trees": trees,
		"renown": renown,
		"day": day,
		"day_time": day_time,
		"fed": fed,
		"skills": skills,
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
	_load_numbers(jobs, data.get("jobs"), true)
	_load_numbers(income_rate, data.get("income_rate"), false)
	peasants = maxi(int(data.get("peasants", START_PEASANTS)), START_PEASANTS)
	if idle_peasants() < 0:
		# More workers than peasants: the save is inconsistent, so everyone goes idle.
		for job: String in jobs:
			jobs[job] = 0
	trees = clampi(int(data.get("trees", START_TREES)), START_TREES, MAX_TREE_PLOTS)
	renown = maxi(int(data.get("renown", 0)), 0)
	day = maxi(int(data.get("day", 1)), 1)
	day_time = clampf(float(data.get("day_time", 0.0)), 0.0, DAY_LENGTH - 0.1)
	fed = bool(data.get("fed", true))
	_was_night = is_night()
	skills.clear()
	var saved_skills: Variant = data.get("skills")
	if saved_skills is Array:
		for id: Variant in saved_skills:
			# Skip anything that is no longer in the skill tree.
			if id is String and SkillData.SKILLS.has(id) and not id in skills:
				skills.append(id)

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


## Woodcutters and quarrymen keep working while the game is closed. Builders
## don't build, and food stays as it was (nobody hunts, nobody eats).
func _grant_offline_progress(seconds_away: float) -> void:
	offline_report = {}
	var seconds := minf(seconds_away, MAX_OFFLINE_SECONDS)
	if seconds < MIN_OFFLINE_SECONDS:
		return
	var report := {"seconds": int(seconds)}
	var earned_any := false
	for type: String in ["wood", "stone"]:
		var gained := int(income_rate[type] * seconds)
		resources[type] += gained
		report[type] = gained
		earned_any = earned_any or gained > 0
	if earned_any:
		offline_report = report
