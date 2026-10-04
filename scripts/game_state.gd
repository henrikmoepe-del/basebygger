extends Node
## Global game data (autoload). Scenes read and change the game through this,
## so the 2D builder and the later 3D mode can share the same state.

signal resources_changed
## A load arrived at the stockhouse.
signal income_delivered(type: String, amount: int)
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
signal raid_started
signal raid_resolved(won: bool)
## Something happened that the player should be told about.
signal announced(text: String)

const CastleData = preload("res://scripts/castle_data.gd")
const SkillData = preload("res://scripts/skill_data.gd")
const JobData = preload("res://scripts/job_data.gd")
const QuestData = preload("res://scripts/quest_data.gd")

const START_JOBS := {"wood": 1, "stone": 1, "hunter": 0, "build": 1, "cook": 0, "soldier": 0, "iron": 0, "forester": 0}
const NO_JOBS := {"wood": 0, "stone": 0, "hunter": 0, "build": 0, "cook": 0, "soldier": 0, "iron": 0, "forester": 0}
const START_PEASANTS := 3
## How much better a trained peasant does their job.
const TRAINED_MULT := 2.0
## Training costs food and wood, and each one trained costs more than the last.
const TRAIN_BASE_COST := 12
const TRAIN_COST_GROWTH := 1.3
const PEASANT_BASE_COST := 10
const PEASANT_COST_GROWTH := 1.25
const PEASANT_BASE_CARRY := 2
## Hunters have their own carry size, raised by hunting skills only.
const HUNTER_CARRY := 4

## A day lasts DAY_LENGTH seconds; the last part of it is night, when
## everyone sleeps. Night begins at NIGHT_START (a fraction of the day).
const DAY_LENGTH := 120.0
const NIGHT_START := 0.72
const START_FOOD := 40
## Every peasant eats this much at dawn. If there isn't enough, everyone
## goes hungry and works at HUNGRY_WORK_MULT until the next dawn.
const FOOD_PER_PEASANT := 3.0
const HUNGRY_WORK_MULT := 0.6
## Each cook saves this share of the food; a trained cook counts as two.
const COOK_FOOD_SAVING := 0.05
const MAX_COOK_POINTS := 10

## Raiders test the castle's defence every RAID_INTERVAL days, and each raid is
## RAID_STRENGTH_GROWTH times stronger than the last. Beating one gives renown;
## losing one costs RAID_LOSS of everything in the stockhouse.
const FIRST_RAID_DAY := 5
const RAID_INTERVAL := 3
const RAID_BASE_STRENGTH := 40.0
const RAID_STRENGTH_GROWTH := 1.3
## Seconds between the raiders appearing and reaching the walls.
const RAID_MARCH_TIME := 12.0
const RAID_LOSS := 0.4
const RAID_BASE_RENOWN := 2
const SOLDIER_DEFENCE := 8
const SOLDIERS_PER_GARRISON_LEVEL := 2

## Passing the crown starts a new castle but keeps legacy, which makes every
## later castle faster. It is the game's long loop (what other incremental
## games call prestige). Legacy is earned from castle levels and raids won.
const LEGACY_MIN_RANK := 2
const LEVELS_PER_LEGACY := 8
const RAIDS_WON_PER_LEGACY := 2
## Each point of legacy makes everyone work this much faster.
const LEGACY_WORK_BONUS := 0.1
## Each point of legacy adds this much wood and stone to a new castle's stores.
const LEGACY_START_STOCK := 10

## The village. Houses set how many peasants can live here. The well and the
## tavern each serve a number of peasants per level; the share of peasants
## served decides how much of that building's work bonus everyone gets.
const BASE_POPULATION := 12
const POPULATION_PER_HOUSE := 4
const WELL_SERVES := 8
const WELL_BONUS := 0.15
const TAVERN_SERVES := 10
const TAVERN_BONUS := 0.15

## Stone: how fast it appears at the stone site and how much can pile up
## there, before and per level of the quarry.
const LOOSE_STONE_RATE := 0.6
const LOOSE_STONE_PILE := 10
const QUARRY_RATE_PER_LEVEL := 0.7
const QUARRY_PILE_PER_LEVEL := 10
## Food works the same way: the wild game is thin, and each Farm level adds to it.
const WILD_FOOD_RATE := 0.25
const WILD_FOOD_PILE := 12
const FARM_RATE_PER_LEVEL := 0.3
const FARM_PILE_PER_LEVEL := 12
## How often the current goal is checked.
const QUEST_CHECK_TIME := 0.5
const MINERS_PER_MINE_LEVEL := 2

## Cows need the Cattle skill. Each costs more than the last and eats every day.
const MAX_COWS := 6
const COW_BASE_COST := {"food": 40, "wood": 25}
const COW_COST_GROWTH := 1.5
const COW_FOOD := 2
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
const BUILDER_BASE_LOAD := 12
## Renown pays for skills. It is earned by building the castle.
const RENOWN_PER_RANK := 3

## No part can go above LEVELS_PER_RANK x castle rank. The rank rises with the
## total of all part levels, so the player must spread out before going higher.
const LEVELS_PER_RANK := 5
const FIRST_RANK_UP := 20
const RANK_UP_STEP := 28

const SAVE_VERSION := 12
const AUTOSAVE_INTERVAL := 10.0
const MAX_OFFLINE_SECONDS := 8 * 3600
## Offline progress is only granted (and reported) after this long away.
const MIN_OFFLINE_SECONDS := 60
## Income is averaged over a whole day, so it includes the night.
const INCOME_WINDOW := DAY_LENGTH

## What is in the stockhouse.
var resources := {"wood": 0, "stone": 0, "food": START_FOOD, "iron": 0}
var cows := 0
var part_levels := {
	"walls": 0, "towers": 0, "gate": 0, "keep": 0, "garrison": 0, "court": 0,
	"palisade": 0, "watchtower": 0,
	"houses": 0, "well": 0, "tavern": 0, "quarry": 0, "farm": 0, "mine": 0,
}
var peasants := START_PEASANTS
## How many peasants are assigned to each job. The rest are idle.
var jobs := START_JOBS.duplicate()
## How many of the peasants in each job are trained in its trade.
var trained := NO_JOBS.duplicate()
var trees := START_TREES
## Seconds of forester work done on the next tree.
var planting_work := 0.0
var renown := 0
## Days start at 1. day_time is the seconds since this day's dawn.
var day := 1
var day_time := 0.0
## False if there wasn't enough food at dawn today.
var fed := true
## Which goal in QuestData.QUESTS the player is on.
var quest_index := 0
var raids_faced := 0
var raids_won := 0
## Kept when the crown is passed on. See LEGACY_* above.
var legacy := 0
## True while raiders are marching on the castle.
var raid_incoming := false
## True while the player is defending the castle in the 3D siege. The 2D
## world (time, autosaves, raid countdown) waits until it is over.
var siege_active := false
## How many levels of each skill the player owns (skills not bought are left out).
var skills := {}

## The building job: the one part being raised a level right now ("" = none).
## Its materials are paid for when ordered, then builders haul them from the
## stockhouse to the foot of the site, pull them up to the top of the scaffold
## by rope, and can only hammer in what has been lifted. Parts without a
## scaffold are built from the ground: what arrives counts as lifted.
var job_part := ""
var job_units := 0        ## Material units the job needs in total.
var job_claimed := 0      ## Units builders have picked up so far.
var job_hauled := 0       ## Units that have arrived at the site.
var job_lifted := 0       ## Units that have been pulled up to the builders.
var job_work := 0.0       ## Seconds of hammering done.
var job_work_total := 0.0

## Measured resources per second brought in by peasants. Used for offline progress.
var income_rate := {"wood": 0.0, "stone": 0.0, "food": 0.0, "iron": 0.0}
## Filled in by load_game() when time away earned something:
## {"seconds": int, plus the amount gained of each resource}. Empty otherwise.
var offline_report := {}
var save_path := "user://save.json"

var _window_income := {"wood": 0, "stone": 0, "food": 0, "iron": 0}
var _was_night := false
var _raid_timer := 0.0
var _quest_timer := 0.0
var _window_time := 0.0
var _autosave_time := 0.0


func _ready() -> void:
	# Tests pass "-- --save=<path>" so they never touch the real save file.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			save_path = arg.trim_prefix("--save=")
	load_game()


func _process(delta: float) -> void:
	if siege_active:
		return
	day_time += delta
	if day_time >= DAY_LENGTH:
		day_time -= DAY_LENGTH
		day += 1
		_eat()
	if is_night() != _was_night:
		_was_night = is_night()
		daytime_changed.emit()
	_update_raid(delta)
	_quest_timer += delta
	if _quest_timer >= QUEST_CHECK_TIME:
		_quest_timer = 0.0
		_check_quest()

	_window_time += delta
	if _window_time >= INCOME_WINDOW:
		for type: String in _window_income:
			income_rate[type] = _window_income[type] / _window_time
			_window_income[type] = 0
		_window_time = 0.0
		resources_changed.emit()

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
	income_delivered.emit(type, amount)


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
	var cook_points: int = mini(jobs.cook + trained.cook, MAX_COOK_POINTS)
	var saving: float = cook_points * COOK_FOOD_SAVING + skill_total("food_saving")
	# Drawbacks: soldiers eat extra, the tavern whets appetites, the court has a household.
	var mouths: float = peasants + jobs.soldier * CastleData.SOLDIER_EXTRA_FOOD + jobs.iron * CastleData.MINER_EXTRA_FOOD
	mouths *= 1.0 + CastleData.TAVERN_EXTRA_EATING * part_levels.tavern
	return ceili(mouths * FOOD_PER_PEASANT * (1.0 - saving)) + CastleData.COURT_FOOD_UPKEEP * part_levels.court + COW_FOOD * cows


## Multiplies how fast everyone walks and works: slower when hungry.
func work_mult() -> float:
	var legacy_mult := (1.0 + LEGACY_WORK_BONUS * legacy) * (1.0 + morale_bonus())
	if not fed:
		return HUNGRY_WORK_MULT * legacy_mult
	return (1.0 + skill_total("fed_bonus")) * legacy_mult


func _eat() -> void:
	var needed := food_needed()
	fed = resources.food >= needed
	resources.food = maxi(resources.food - needed, 0)
	resources_changed.emit()
	daytime_changed.emit()
	if not fed:
		announced.emit("Not enough food: your peasants are hungry and slow today")


# --- Goals ---

## The goal the player is working on, or an empty Dictionary when all are done.
func current_quest() -> Dictionary:
	if quest_index >= QuestData.QUESTS.size():
		return {}
	return QuestData.QUESTS[quest_index]


func _quest_done(quest: Dictionary) -> bool:
	var amount: int = quest.amount
	match quest.kind:
		"part":
			return part_levels[quest.id] >= amount
		"parts":
			for id: String in quest.ids:
				if part_levels[id] < amount:
					return false
			return true
		"job":
			return jobs[quest.id] >= amount
		"peasants":
			return peasants >= amount
		"skills":
			var levels := 0
			for id: String in skills:
				levels += skills[id]
			return levels >= amount
		"trained":
			return total_trained() >= amount
		"raids_won":
			return raids_won >= amount
		"rank":
			return castle_rank() >= amount
		"cows":
			return cows >= amount
	return false


func _check_quest() -> void:
	var quest := current_quest()
	if quest.is_empty() or not _quest_done(quest):
		return
	renown += quest.renown
	quest_index += 1
	announced.emit("Goal reached! +%d renown" % quest.renown)
	skills_changed.emit()


# --- Raids ---

## The day the next raid arrives.
func next_raid_day() -> int:
	return FIRST_RAID_DAY + RAID_INTERVAL * raids_faced


## How much defence the next raid needs to be beaten.
func raid_strength() -> int:
	var greed: float = 1.0 + CastleData.KEEP_RAID_GROWTH * part_levels.keep
	return roundi(RAID_BASE_STRENGTH * pow(RAID_STRENGTH_GROWTH, raids_faced) * greed)


func _update_raid(delta: float) -> void:
	if not raid_incoming:
		if day >= next_raid_day():
			raid_incoming = true
			_raid_timer = RAID_MARCH_TIME
			raid_started.emit()
			announced.emit("Raiders approach! Their strength is %d, your defence is %d" % [raid_strength(), total_defence()])
		return
	_raid_timer -= delta
	if _raid_timer <= 0.0:
		# Nobody took command: the defence is weighed against the raid.
		_resolve_raid(total_defence() >= raid_strength())


## Leaves the 2D world to fight the incoming raid in 3D (see siege.gd).
## With no raid on the way, one is called early (used by the dev tools).
func start_siege() -> void:
	if not raid_incoming:
		raid_incoming = true
		raid_started.emit()
	siege_active = true
	save_game()
	get_tree().change_scene_to_file("res://scenes/siege.tscn")


## Called by the 3D siege when it is won or lost.
func finish_siege(won: bool) -> void:
	siege_active = false
	_resolve_raid(won)
	save_game()


func _resolve_raid(won: bool) -> void:
	if won:
		var reward := RAID_BASE_RENOWN + raids_faced / 3 + int(skill_total("raid_renown"))
		renown += reward
		raids_won += 1
		announced.emit("Raid repelled! +%d renown" % reward)
	else:
		var loss := RAID_LOSS * (1.0 - skill_total("raid_loss_cut"))
		for type: String in resources:
			resources[type] -= int(resources[type] * loss)
		announced.emit("The raiders broke in and took %d%% of your stores" % roundi(loss * 100))
	raids_faced += 1
	raid_incoming = false
	raid_resolved.emit(won)
	resources_changed.emit()
	skills_changed.emit()


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


## How many peasants the village has room for.
func max_peasants() -> int:
	return BASE_POPULATION + (POPULATION_PER_HOUSE + int(skill_total("house_room"))) * part_levels.houses


## How much faster everyone works for being content: the well and the tavern
## each give their full bonus only if they are big enough for every peasant.
func morale_bonus() -> float:
	var well_serves := WELL_SERVES + int(skill_total("well_serves"))
	var watered := clampf(float(part_levels.well * well_serves) / peasants, 0.0, 1.0)
	var cheered := clampf(float(part_levels.tavern * TAVERN_SERVES) / peasants, 0.0, 1.0)
	var dust: float = CastleData.QUARRY_DUST * part_levels.quarry
	return WELL_BONUS * watered + (TAVERN_BONUS + skill_total("tavern_bonus")) * cheered - dust


## Hires a peasant. They start idle until given a job.
func hire_peasant() -> bool:
	if peasants >= max_peasants() or not spend(peasant_cost()):
		return false
	peasants += 1
	peasants_changed.emit()
	return true


## Some jobs only exist once a skill is owned (see "requires_skill" in JobData).
func job_unlocked(job: String) -> bool:
	var info: Dictionary = JobData.JOBS[job]
	if info.has("requires_part") and part_levels[info.requires_part] == 0:
		return false
	return not info.has("requires_skill") or skill_level(info.requires_skill) > 0


## The most peasants a job can hold, or -1 for no limit.
func job_limit(job: String) -> int:
	if job == "soldier":
		return part_levels.garrison * (SOLDIERS_PER_GARRISON_LEVEL + int(skill_total("soldier_room")))
	if job == "iron":
		return part_levels.mine * MINERS_PER_MINE_LEVEL
	return -1


## Moves one idle peasant into a job (change = 1) or one out of it (change = -1).
func assign(job: String, change: int) -> bool:
	if change > 0 and (idle_peasants() <= 0 or not job_unlocked(job)):
		return false
	if change > 0 and job_limit(job) >= 0 and jobs[job] >= job_limit(job):
		return false
	if change < 0 and jobs[job] <= 0:
		return false
	jobs[job] += change
	if job == "forester":
		trained[job] = jobs[job]
	# Taking the last untrained peasant off a job takes a trained one next,
	# and their training is lost.
	trained[job] = mini(trained[job], jobs[job])
	peasants_changed.emit()
	return true


## True once the job's trade has been bought in the skill tree.
func trade_unlocked(job: String) -> bool:
	return skill_level(JobData.JOBS[job].trade_skill) > 0


func total_trained() -> int:
	var total := 0
	for job: String in trained:
		total += trained[job]
	return total


func train_cost() -> Dictionary:
	var amount := ceili(TRAIN_BASE_COST * pow(TRAIN_COST_GROWTH, total_trained()))
	return {"food": amount, "wood": amount}


## Why nobody in the job can be trained right now (apart from cost), or "".
func train_block_reason(job: String) -> String:
	if not trade_unlocked(job):
		return "Needs the %s skill" % SkillData.SKILLS[JobData.JOBS[job].trade_skill].name
	if trained[job] >= jobs[job]:
		return "Nobody left to train"
	return ""


## Trains one peasant in the job's trade.
func train(job: String) -> bool:
	if train_block_reason(job) != "" or not spend(train_cost()):
		return false
	trained[job] += 1
	peasants_changed.emit()
	return true


# --- Stone and cows ---

## How much of a resource appears per second at its gathering site.
func site_rate(type: String) -> float:
	if type == "food":
		return WILD_FOOD_RATE + FARM_RATE_PER_LEVEL * part_levels.farm
	return LOOSE_STONE_RATE + QUARRY_RATE_PER_LEVEL * part_levels.quarry


## How much of a resource can wait at its gathering site.
func site_capacity(type: String) -> float:
	if type == "food":
		return WILD_FOOD_PILE + FARM_PILE_PER_LEVEL * part_levels.farm
	return LOOSE_STONE_PILE + QUARRY_PILE_PER_LEVEL * part_levels.quarry


func cow_cost() -> Dictionary:
	return _scaled_cost(COW_BASE_COST, COW_COST_GROWTH, cows)


## Why a cow can't be bought right now (apart from cost), or "".
func cow_block_reason() -> String:
	if skill_level("cattle") == 0:
		return "Needs the Cattle skill"
	if cows >= MAX_COWS:
		return "The pasture is full"
	return ""


func buy_cow() -> bool:
	if cow_block_reason() != "" or not spend(cow_cost()):
		return false
	cows += 1
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

## The castle's levels added together. Village buildings don't count.
func total_levels() -> int:
	var total := 0
	for id: String in part_levels:
		if not is_village(id):
			total += part_levels[id]
	return total


func is_village(id: String) -> bool:
	return CastleData.PARTS[id].get("village", false)


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
	# The higher levels of the castle itself need iron fittings.
	var next_level: int = part_levels[id] + 1
	if not is_village(id) and next_level >= CastleData.IRON_FROM_LEVEL:
		cost["iron"] = CastleData.IRON_PER_LEVEL * (next_level - CastleData.IRON_FROM_LEVEL + 1)
	return cost


## Seconds of hammering for the part's next level.
func part_work(id: String) -> float:
	var discount := 1.0 - skill_total("work_discount")
	return CastleData.PARTS[id].work * pow(CastleData.WORK_GROWTH, part_levels[id]) * discount


## Why the part can't be ordered right now (apart from cost), or "" if it can.
func part_block_reason(id: String) -> String:
	if job_part != "":
		return "Builders are busy"
	if is_village(id):
		return "Fully built" if part_levels[id] >= CastleData.PARTS[id].max_level else ""
	if id != "walls" and part_levels.walls == 0:
		return "Needs Walls first"
	if part_levels[id] >= level_cap():
		return "Raise castle rank"
	return ""


## The castle's defence: every part's levels, plus the soldiers on the walls.
## Raids are checked against this, and the 3D mode will use it too.
func total_defence() -> int:
	var from_parts := 0.0
	for id: String in part_levels:
		from_parts += part_levels[id] * CastleData.PARTS[id].defence
	from_parts *= 1.0 + skill_total("part_defence")
	# A trained soldier counts as two.
	return roundi(from_parts) + (jobs.soldier + trained.soldier) * soldier_defence()


func soldier_defence() -> int:
	return SOLDIER_DEFENCE + int(skill_total("soldier_defence"))


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
	job_lifted = 0
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
	if CastleData.PARTS[job_part].scaffold.is_empty():
		job_lifted = job_hauled
	job_delivered.emit()
	job_progress_changed.emit()


## How many delivered units are waiting at the foot of the hoist.
func job_waiting() -> int:
	return job_hauled - job_lifted


## A builder at the top pulls up to max_units from the pile below.
## Returns how many came up.
func job_lift(max_units: int) -> int:
	var units := mini(max_units, job_waiting())
	if units > 0:
		job_lifted += units
		job_progress_changed.emit()
	return units


## True if there is lifted material that hasn't been hammered in yet.
func job_can_hammer() -> bool:
	return job_part != "" and job_work < _job_work_allowed()


func job_add_work(seconds: float) -> void:
	job_work = minf(job_work + seconds, _job_work_allowed())
	if job_lifted >= job_units and job_work >= job_work_total:
		_finish_job()
	job_progress_changed.emit()


## How far along the job is, from 0 to 1.
func job_fraction() -> float:
	if job_part == "":
		return 0.0
	return clampf(job_work / job_work_total, 0.0, 1.0)


func _job_work_allowed() -> float:
	if job_lifted >= job_units:
		return job_work_total
	return job_work_total * job_lifted / job_units


func _finish_job() -> void:
	var rank_before := castle_rank()
	part_levels[job_part] += 1
	renown += CastleData.PARTS[job_part].renown
	if castle_rank() > rank_before:
		renown += RENOWN_PER_RANK + int(skill_total("rank_renown"))
		announced.emit("Castle rank %d! Parts can now reach level %d" % [castle_rank(), level_cap()])
	job_part = ""
	castle_changed.emit()
	skills_changed.emit()


# --- Skills ---

func skill_level(id: String) -> int:
	return skills.get(id, 0)


## Renown for the skill's next level.
func skill_cost(id: String) -> int:
	var skill: Dictionary = SkillData.SKILLS[id]
	return skill.cost + skill.cost_step * skill_level(id)


## Why the skill's next level can't be bought right now, or "" if it can.
func skill_block_reason(id: String) -> String:
	var skill: Dictionary = SkillData.SKILLS[id]
	if skill_level(id) >= skill.max_level:
		return "Fully learned"
	if skill.requires != "" and skill_level(skill.requires) == 0:
		return "Needs %s" % SkillData.SKILLS[skill.requires].name
	if renown < skill_cost(id):
		return "Not enough renown"
	return ""


## Buys one level of the skill.
func buy_skill(id: String) -> bool:
	if skill_block_reason(id) != "":
		return false
	renown -= skill_cost(id)
	skills[id] = skill_level(id) + 1
	skills_changed.emit()
	# Skills change costs and speeds, so everything on screen refreshes.
	resources_changed.emit()
	peasants_changed.emit()
	return true


## Adds up one effect across all owned skill levels.
func skill_total(effect: String) -> float:
	var total := 0.0
	for id: String in skills:
		total += SkillData.SKILLS[id].effects.get(effect, 0.0) * skills[id]
	return total


# --- What skills do ---

func peasant_speed_mult() -> float:
	return (1.0 + skill_total("peasant_speed")) * work_mult()


## How many resources a gatherer with this job carries per trip.
func carry_amount(job: String) -> int:
	if job == "hunter":
		return HUNTER_CARRY + int(skill_total("hunter_carry"))
	return PEASANT_BASE_CARRY + int(skill_total("carry"))


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


# --- Developer tools ---

## Jumps the game forward for testing (see dev_tools.gd). It is an estimate,
## not a real simulation: gatherers bring in what they currently earn per
## second, the days tick over (with meals), and the building job finishes.
func dev_skip(seconds: float) -> void:
	for type: String in income_rate:
		resources[type] += int(income_rate[type] * seconds)
	var total := day_time + seconds
	var days_passed := int(total / DAY_LENGTH)
	day_time = fmod(total, DAY_LENGTH)
	for i in days_passed:
		day += 1
		_eat()
	if job_part != "":
		job_hauled = job_units
		job_claimed = job_units
		job_lifted = job_units
		job_work = job_work_total
		_finish_job()
	resources_changed.emit()
	job_progress_changed.emit()
	announced.emit("DEV: skipped %d minutes" % roundi(seconds / 60))


# --- Save and load ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"resources": resources,
		"part_levels": part_levels,
		"peasants": peasants,
		"cows": cows,
		"jobs": jobs,
		"trained": trained,
		"trees": trees,
		"renown": renown,
		"day": day,
		"day_time": day_time,
		"fed": fed,
		"raids_faced": raids_faced,
		"quest_index": quest_index,
		"raids_won": raids_won,
		"legacy": legacy,
		"skills": skills,
		"income_rate": income_rate,
		"job": {
			"part": job_part, "units": job_units, "hauled": job_hauled, "lifted": job_lifted,
			"work": job_work, "work_total": job_work_total,
		},
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save to %s" % save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))


## How much legacy passing the crown would give right now.
func legacy_gain() -> int:
	if castle_rank() < LEGACY_MIN_RANK:
		return 0
	return total_levels() / LEVELS_PER_LEGACY + raids_won / RAIDS_WON_PER_LEGACY


## The heir starts a new castle from nothing, but with more legacy.
func pass_the_crown() -> bool:
	var gain := legacy_gain()
	if gain <= 0:
		return false
	legacy += gain
	_start_over()
	announced.emit("A new heir begins with %d legacy: everyone works %d%% faster" % [legacy, roundi(legacy * LEGACY_WORK_BONUS * 100)])
	return true


## Wipes everything, legacy included, and starts from the very beginning.
func reset_game() -> void:
	legacy = 0
	_start_over()


func _start_over() -> void:
	var start_stock := LEGACY_START_STOCK * legacy
	resources = {"wood": start_stock, "stone": start_stock, "food": START_FOOD, "iron": 0}
	cows = 0
	for id: String in part_levels:
		part_levels[id] = 0
	peasants = START_PEASANTS
	jobs = START_JOBS.duplicate()
	trained = NO_JOBS.duplicate()
	trees = START_TREES
	planting_work = 0.0
	renown = 0
	skills.clear()
	day = 1
	day_time = 0.0
	fed = true
	raids_faced = 0
	raids_won = 0
	quest_index = 0
	raid_incoming = false
	job_part = ""
	for type: String in income_rate:
		income_rate[type] = 0.0
		_window_income[type] = 0
	_window_time = 0.0
	_was_night = false
	offline_report = {}
	save_game()
	# Reloading the scene rebuilds everything on screen from the fresh state.
	get_tree().reload_current_scene()


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
	_load_numbers(trained, data.get("trained"), true)
	for job: String in trained:
		trained[job] = mini(trained[job], jobs[job])
	_load_numbers(income_rate, data.get("income_rate"), false)
	peasants = maxi(int(data.get("peasants", START_PEASANTS)), START_PEASANTS)
	cows = clampi(int(data.get("cows", 0)), 0, MAX_COWS)
	if idle_peasants() < 0:
		# More workers than peasants: the save is inconsistent, so everyone goes idle.
		for job: String in jobs:
			jobs[job] = 0
	trees = clampi(int(data.get("trees", START_TREES)), START_TREES, MAX_TREE_PLOTS)
	renown = maxi(int(data.get("renown", 0)), 0)
	day = maxi(int(data.get("day", 1)), 1)
	day_time = clampf(float(data.get("day_time", 0.0)), 0.0, DAY_LENGTH - 0.1)
	fed = bool(data.get("fed", true))
	raids_faced = maxi(int(data.get("raids_faced", 0)), 0)
	quest_index = clampi(int(data.get("quest_index", 0)), 0, QuestData.QUESTS.size())
	raids_won = clampi(int(data.get("raids_won", 0)), 0, raids_faced)
	legacy = maxi(int(data.get("legacy", 0)), 0)
	_was_night = is_night()
	skills.clear()
	var saved_skills: Variant = data.get("skills")
	if saved_skills is Dictionary:
		for id: String in saved_skills:
			# Skip anything that is no longer in the skill tree.
			if SkillData.SKILLS.has(id):
				skills[id] = clampi(int(saved_skills[id]), 0, SkillData.SKILLS[id].max_level)

	var job: Variant = data.get("job")
	if job is Dictionary and part_levels.has(job.get("part", "")) and float(job.get("work_total", 0.0)) > 0.0:
		job_part = job.part
		job_units = maxi(int(job.get("units", 1)), 1)
		job_hauled = clampi(int(job.get("hauled", 0)), 0, job_units)
		# Loads that were being carried when the game closed go back to the stockhouse.
		job_claimed = job_hauled
		job_lifted = clampi(int(job.get("lifted", job_hauled)), 0, job_hauled)
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
