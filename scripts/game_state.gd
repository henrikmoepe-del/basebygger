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
## A raider fell.
signal raid_progress
signal raid_resolved(won: bool)
## Something happened that the player should be told about.
signal announced(text: String)
## An event started or ended (see EventData).
signal events_changed
## A policy was turned on or off (see PolicyData).
signal policies_changed
## Happiness moved by a whole point.
signal mood_changed
## A new season began.
signal season_changed
## A boost was bought or ran out.
signal boosts_changed

const CastleData = preload("res://scripts/castle_data.gd")
const SkillData = preload("res://scripts/skill_data.gd")
const JobData = preload("res://scripts/job_data.gd")
const BuildPlan = preload("res://scripts/build_plan.gd")
const QuestData = preload("res://scripts/quest_data.gd")
const EventData = preload("res://scripts/event_data.gd")
const PolicyData = preload("res://scripts/policy_data.gd")
const SeasonData = preload("res://scripts/season_data.gd")
const BoostData = preload("res://scripts/boost_data.gd")

const START_JOBS := {"wood": 1, "stone": 1, "hunter": 0, "build": 1, "cook": 0, "soldier": 0, "iron": 0, "sawyer": 0, "forester": 0}
const NO_JOBS := {"wood": 0, "stone": 0, "hunter": 0, "build": 0, "cook": 0, "soldier": 0, "iron": 0, "sawyer": 0, "forester": 0}
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
const DAY_LENGTH := 300.0
const NIGHT_START := 0.72
const START_FOOD := 40
## Every peasant eats this much at dawn. If there isn't enough, everyone
## goes hungry and works at HUNGRY_WORK_MULT until the next dawn.
const FOOD_PER_PEASANT := 3.0
const HUNGRY_WORK_MULT := 0.6
## Each cook saves this share of the food; a trained cook counts as two.
const COOK_FOOD_SAVING := 0.05
const MAX_COOK_POINTS := 10

## Raiders come on a timetable (the "raid" event in event_data.gd): RAID_BASE_SIZE of them at first,
## RAID_SIZE_GROWTH more each time, each a little tougher than the last. They
## are fought in the world (see raiders.gd). If they reach the castle, the
## fight for the gate is fought in 3D. Beating a raid gives renown; losing
## one costs RAID_LOSS of everything in the stockyard.
const RAID_BASE_SIZE := 3
const RAID_SIZE_GROWTH := 2
const RAIDER_BASE_HP := 12.0
const RAIDER_HP_GROWTH := 1.12
## The gate fight is never smaller than this share of a full one, however
## few raiders got through.
const MIN_SIEGE_SHARE := 0.25
## The 3D fight for the gate is switched off for now (Henrik, 2026-10-05):
## raiders who reach the castle are simply gone, and nothing is taken.
const SIEGE_ENABLED := false
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
## served decides how much of that building's happiness everyone gets.
const BASE_POPULATION := 12
const POPULATION_PER_HOUSE := 4
const WELL_SERVES := 8
const WELL_HAPPY := 15.0
const TAVERN_SERVES := 10
const TAVERN_HAPPY := 15.0

## Happiness, from 0 to 100, drifts towards what the peasants' lives are
## like (happiness_parts) by MOOD_DRIFT a second. At MOOD_BASE nothing
## changes; at 100 everyone works MOOD_WORK faster, at 0 that much slower.
## Some events only happen while people are happy, or unhappy.
const MOOD_BASE := 50.0
const MOOD_DRIFT := 0.5
const MOOD_WORK := 0.2
const MOOD_FED := 5.0
const MOOD_HUNGRY := -25.0
const MOOD_CROWDED := -10.0
## Happiness counts as "happy" above this and "unhappy" below MOOD_UNHAPPY.
const MOOD_HAPPY := 65.0
const MOOD_UNHAPPY := 35.0

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
## How many pieces (a block of stone, a bundle of poles, a fitting) a builder
## brings from the stockhouse per trip: a barrow load.
const BUILDER_BASE_LOAD := 3
## Renown pays for skills. It is earned by building the castle.
const RENOWN_PER_RANK := 3

## No part can go above LEVELS_PER_RANK x castle rank. The rank rises with the
## total of all part levels, so the player must spread out before going higher.
const LEVELS_PER_RANK := 5
const FIRST_RANK_UP := 20
const RANK_UP_STEP := 28

## How many messages the log keeps.
const LOG_SIZE := 30
const SAVE_VERSION := 12
const AUTOSAVE_INTERVAL := 10.0
const MAX_OFFLINE_SECONDS := 8 * 3600
## Offline progress is only granted (and reported) after this long away.
const MIN_OFFLINE_SECONDS := 60
## Income is averaged over a whole day, so it includes the night.
const INCOME_WINDOW := DAY_LENGTH

## What is in the stockhouse.
var resources := {"wood": 0, "stone": 0, "food": START_FOOD, "iron": 0, "planks": 0}
var cows := 0
var part_levels := {
	"walls": 0, "towers": 0, "gate": 0, "keep": 0, "garrison": 0, "court": 0,
	"palisade": 0, "watchtower": 0,
	"houses": 0, "well": 0, "tavern": 0, "quarry": 0, "farm": 0, "mine": 0, "sawmill": 0, "stockhouse": 0,
}
## The rooms the player chose for each storey of the keep above the first
## keep's own, lowest first, each [left room, right room] (see CastleData.ROOMS).
## While a storey is being built its rooms are already last in the list.
var keep_picks := []
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
## For playtesting: when true, night never comes. Dusk turns straight into
## the next dawn, so days, meals and raids still go by.
var no_nights := false
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
## How many raiders are still standing in the raid being fought.
var raiders_left := 0
## How big the gate fight is: the share of the raiders who reached the castle.
var siege_share := 1.0
## True while the player is defending the castle in the 3D siege. The 2D
## world (time, autosaves, raid countdown) waits until it is over.
var siege_active := false
## How many levels of each skill the player owns (skills not bought are left out).
var skills := {}
## The events going on now: event id -> seconds left (see EventData).
var events := {}
## The last messages, oldest first, each {"day", "text"} (the Log button).
var messages := []
## How many times each event has happened, by id.
var event_counts := {}
## How happy the peasants are, 0 to 100 (see MOOD_BASE).
var happiness := MOOD_BASE
## The boosts going on: boost id -> seconds left (see BoostData).
var boosts := {}
## The policies turned on, by id (see PolicyData).
var policies := []

## The building job: the one part being raised a level right now ("" = none).
## Its materials are paid for when ordered. The job is then a list of pieces
## (job_plan, see build_plan.gd), and each piece goes through the same steps
## in the same order: a builder fetches it from the stockhouse, it is shaped
## at the bench at the foot of the site, pulled up by the rope, picked up at
## the top and put in place. Each counter says how many pieces, counted from
## the first, have got that far; pieces skip the steps they don't need.
var job_part := ""
var job_plan := {}
var job_claimed := 0      ## Pieces builders have set off from the stockhouse with.
var job_hauled := 0       ## Pieces that have arrived at the foot of the site.
var job_formed := 0       ## Pieces shaped at the bench.
var job_lifted := 0       ## Pieces pulled up to the top.
var job_hooked := false   ## True while a piece is tied on the rope, ready to be pulled up.
var job_taken := 0        ## Pieces a builder has picked up to put in place.
var job_placed := 0       ## Pieces in place.

## Measured resources per second brought in by peasants. Used for offline progress.
var income_rate := {"wood": 0.0, "stone": 0.0, "food": 0.0, "iron": 0.0, "planks": 0.0}
## Filled in by load_game() when time away earned something:
## {"seconds": int, plus the amount gained of each resource}. Empty otherwise.
var offline_report := {}
var save_path := "user://save.json"

var _window_income := {"wood": 0, "stone": 0, "food": 0, "iron": 0, "planks": 0}
var _was_night := false
var _quest_timer := 0.0
var _window_time := 0.0
var _autosave_time := 0.0
var _event_timer := 0.0


func _ready() -> void:
	# Tests pass "-- --save=<path>" so they never touch the real save file.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			save_path = arg.trim_prefix("--save=")
	announced.connect(_log_message)
	load_game()


func _process(delta: float) -> void:
	if siege_active:
		return
	day_time += delta
	if no_nights and day_time >= DAY_LENGTH * night_start():
		day_time = DAY_LENGTH
	if day_time >= DAY_LENGTH:
		day_time -= DAY_LENGTH
		_new_day()
	if is_night() != _was_night:
		_was_night = is_night()
		daytime_changed.emit()
	_update_events(delta)
	_update_mood(delta)
	_update_boosts(delta)
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

## A sawyer takes up to this many logs from the wood stack. Returns how many they got.
func take_wood(logs: int) -> int:
	var taken := mini(logs, resources.wood)
	resources.wood -= taken
	if taken > 0:
		resources_changed.emit()
	return taken


## Peasants deliver to the stockhouse through this, so income can be
## measured. What does not fit in a full store is lost.
func add_income(type: String, amount: int) -> void:
	amount = mini(amount, store_room(type))
	_window_income[type] += amount
	resources[type] += amount
	resources_changed.emit()
	income_delivered.emit(type, amount)


## How much each store of the stockyard holds (raised by the stockhouse).
func store_capacity() -> int:
	return roundi(CastleData.STORE_BASE * pow(CastleData.STORE_GROWTH, part_levels.stockhouse))


## How much more fits in a resource's store.
func store_room(type: String) -> int:
	return maxi(store_capacity() - resources[type], 0)


func store_full(type: String) -> bool:
	return store_room(type) <= 0


## Adds to a store as far as it has room (gifts, rewards, offline work).
func _add_to_store(type: String, amount: int) -> void:
	resources[type] += mini(amount, store_room(type))


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


func set_no_nights(on: bool) -> void:
	no_nights = on
	daytime_changed.emit()
	save_game()


## Dawn: a new day begins, everyone eats, and sometimes a new season starts.
func _new_day() -> void:
	var season_before := season_index()
	day += 1
	_eat()
	if season_index() != season_before:
		announced.emit("%s has come: %s" % [season().name, season().text.to_lower()])
		season_changed.emit()


## Which season it is, 0 (spring) to 3 (winter).
func season_index() -> int:
	return ((day - 1) / SeasonData.DAYS_PER_SEASON) % SeasonData.SEASONS.size()


## The season now (see SeasonData).
func season() -> Dictionary:
	return SeasonData.SEASONS[season_index()]


## How many days are left of this season, today included.
func season_days_left() -> int:
	return SeasonData.DAYS_PER_SEASON - (day - 1) % SeasonData.DAYS_PER_SEASON


func is_night() -> bool:
	return day_fraction() >= night_start()


## How much food the peasants eat at dawn.
func food_needed() -> int:
	var cook_points: int = mini(jobs.cook + trained.cook, MAX_COOK_POINTS)
	var saving: float = cook_points * COOK_FOOD_SAVING + skill_total("food_saving") + effect_total("food_saving")
	# Drawbacks: soldiers eat extra, the tavern whets appetites, the court has a household.
	var mouths: float = peasants + jobs.soldier * CastleData.SOLDIER_EXTRA_FOOD + jobs.iron * CastleData.MINER_EXTRA_FOOD
	mouths *= 1.0 + CastleData.TAVERN_EXTRA_EATING * part_levels.tavern
	return ceili(mouths * FOOD_PER_PEASANT * maxf(1.0 - saving, 0.0)) + CastleData.COURT_FOOD_UPKEEP * part_levels.court + COW_FOOD * cows


## Multiplies how fast everyone walks and works: slower when hungry.
func work_mult() -> float:
	var legacy_mult := (1.0 + LEGACY_WORK_BONUS * legacy) * (1.0 + morale_bonus()) * maxf(1.0 + effect_total("work_speed"), 0.1)
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

## The day the next raid arrives (the raid is an event on a timetable).
func next_raid_day() -> int:
	return next_event_day("raid")


## How many raiders come next time. A rich keep draws more of them.
func raid_size() -> int:
	var greed: float = 1.0 + CastleData.KEEP_RAID_GROWTH * part_levels.keep
	return roundi((RAID_BASE_SIZE + RAID_SIZE_GROWTH * raids_faced) * greed)


## How much each raider of the next raid can take.
func raider_hp() -> float:
	return RAIDER_BASE_HP * pow(RAIDER_HP_GROWTH, raids_faced)


## The raid event has started: raiders.gd sends them in from the west.
func _begin_raid() -> void:
	raid_incoming = true
	raiders_left = raid_size()
	raid_started.emit()


## Every raider has fallen before reaching the castle.
func raid_beaten() -> void:
	_resolve_raid(true)


## Raiders have reached the castle: the fight for the gate begins, with as
## many of them as are still standing.
func raiders_reached(standing: int) -> void:
	siege_share = clampf(float(standing) / raid_size(), MIN_SIEGE_SHARE, 1.0)
	if SIEGE_ENABLED:
		start_siege()
		return
	announced.emit("%d raiders reached the castle, and were gone again" % standing)
	raids_faced += 1
	raid_incoming = false
	end_event("raid", "done")
	raid_resolved.emit(false)


## Leaves the 2D world to fight the incoming raid in 3D (see siege.gd).
## With no raid on the way, one is called early (used by the dev tools).
func start_siege() -> void:
	if not raid_incoming:
		siege_share = 1.0
		start_event("raid")
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
	end_event("raid", "done")
	raid_resolved.emit(won)
	resources_changed.emit()
	skills_changed.emit()


# --- The message log ---

func _log_message(text: String) -> void:
	messages.append({"day": day, "text": text})
	if messages.size() > LOG_SIZE:
		messages.pop_front()


# --- Events ---

## Events on a timetable start on their day; every so often a chance event
## may start; the ones with a time limit run out.
func _update_events(delta: float) -> void:
	for id: String in events.keys():
		if EventData.EVENTS[id].get("until_done", false):
			continue
		events[id] -= delta
		if events[id] <= 0.0:
			end_event(id, "ran_out")
	for id: String in EventData.EVENTS:
		if EventData.EVENTS[id].has("schedule") and not events.has(id) and day >= next_event_day(id) and event_allowed(id):
			start_event(id)
	_event_timer += delta
	if _event_timer >= EventData.CHECK_TIME:
		_event_timer = 0.0
		if randf() < EventData.CHANCE:
			start_event(pick_event())


## The day an event on a timetable next comes.
func next_event_day(id: String) -> int:
	var schedule: Dictionary = EventData.EVENTS[id].schedule
	return schedule.from_day + schedule.every_days * _times_happened(id)


## How often an event on a timetable has happened (and ended) so far.
func _times_happened(id: String) -> int:
	if id == "raid":
		return raids_faced
	return int(event_counts.get(id, 0))


## True if an event may start now: from its first day, and only while what
## it "needs" holds.
func event_allowed(id: String) -> bool:
	var info: Dictionary = EventData.EVENTS[id]
	var needs: Dictionary = info.get("needs", {})
	if needs.get("happy", false) and happiness <= MOOD_HAPPY:
		return false
	if needs.get("unhappy", false) and happiness >= MOOD_UNHAPPY:
		return false
	if needs.has("season") and needs.season != season().id:
		return false
	return day >= info.get("from_day", 1)


## A random chance event that may start now (by weight), or "" if there is none.
func pick_event() -> String:
	var total := 0.0
	var allowed := []
	for id: String in EventData.EVENTS:
		var info: Dictionary = EventData.EVENTS[id]
		if info.has("weight") and not events.has(id) and event_allowed(id):
			allowed.append(id)
			total += info.weight
	var roll := randf() * total
	for id: String in allowed:
		roll -= EventData.EVENTS[id].weight
		if roll <= 0.0:
			return id
	return ""


func start_event(id: String) -> bool:
	if id == "" or events.has(id):
		return false
	var info: Dictionary = EventData.EVENTS[id]
	events[id] = info.get("lasts", 0.0)
	if id == "raid":
		_begin_raid()
	announced.emit(_event_text(info.start_text))
	events_changed.emit()
	return true


## Ends an event. how is "ran_out" (its time is up), "clicked" (the player
## clicked it away early, for its reward) or "done" (the game ended it, as
## a raid ends when it is beaten; it says so itself).
func end_event(id: String, how: String) -> void:
	if not events.has(id):
		return
	events.erase(id)
	event_counts[id] = int(event_counts.get(id, 0)) + 1
	var info: Dictionary = EventData.EVENTS[id]
	if how == "clicked":
		for type: String in info.get("reward", {}):
			_add_to_store(type, info.reward[type])
		resources_changed.emit()
		announced.emit(_event_text(info.click_text))
	elif how == "ran_out":
		announced.emit(_event_text(info.end_text))
	events_changed.emit()


## An event's message, with {raiders} and the like filled in.
func _event_text(text: String) -> String:
	return text.format({"raiders": raid_size()})


## The sum of an effect over everything going on that changes how the
## castle works: the events now, and the policies chosen.
func effect_total(effect: String) -> float:
	var total := 0.0
	for id: String in events:
		total += EventData.EVENTS[id].effects.get(effect, 0.0)
	for id: String in policies:
		total += PolicyData.POLICIES[id].effects.get(effect, 0.0)
	total += season().effects.get(effect, 0.0)
	for id: String in boosts:
		total += BoostData.BOOSTS[id].effects.get(effect, 0.0)
	return total


# --- Boosts ---

## Why a boost can't be bought right now (apart from its cost), or "".
func boost_block_reason(id: String) -> String:
	var info: Dictionary = BoostData.BOOSTS[id]
	if part_levels[info.building] == 0:
		return "Needs a %s" % CastleData.PARTS[info.building].name
	if boosts.has(id):
		return "Going on: %d s left" % ceili(boosts[id])
	return ""


func buy_boost(id: String) -> bool:
	if boost_block_reason(id) != "" or not spend(BoostData.BOOSTS[id].cost):
		return false
	boosts[id] = BoostData.BOOSTS[id].lasts
	announced.emit("%s at the %s: %s" % [BoostData.BOOSTS[id].name, CastleData.PARTS[BoostData.BOOSTS[id].building].name.to_lower(),
		BoostData.BOOSTS[id].text.to_lower()])
	boosts_changed.emit()
	return true


func _update_boosts(delta: float) -> void:
	for id: String in boosts.keys():
		boosts[id] -= delta
		if boosts[id] <= 0.0:
			boosts.erase(id)
			announced.emit("The %s has worn off" % BoostData.BOOSTS[id].name.to_lower())
			boosts_changed.emit()


# --- Policies ---

## Turns a policy on, or off if it is on.
func toggle_policy(id: String) -> void:
	if not PolicyData.POLICIES.has(id):
		return
	if id in policies:
		policies.erase(id)
	else:
		policies.append(id)
	policies_changed.emit()
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


## How many peasants the village has room for.
func max_peasants() -> int:
	return BASE_POPULATION + (POPULATION_PER_HOUSE + int(skill_total("house_room"))) * part_levels.houses 			+ CastleData.BEDCHAMBER_PEASANTS * room_count("beds")


## How much faster everyone works for being happy (slower when unhappy).
func morale_bonus() -> float:
	return (happiness - MOOD_BASE) / (100.0 - MOOD_BASE) * MOOD_WORK


## What makes the peasants happy or unhappy, each [what, points]. The well
## and the tavern give their full points only if they are big enough for
## every peasant.
func happiness_parts() -> Array:
	var parts := []
	parts.append(["Fed", MOOD_FED] if fed else ["Hungry", MOOD_HUNGRY])
	var well_serves := WELL_SERVES + int(skill_total("well_serves"))
	var watered := clampf(float(part_levels.well * well_serves) / peasants, 0.0, 1.0)
	if watered > 0.0:
		parts.append(["Well", WELL_HAPPY * watered])
	var cheered := clampf(float(part_levels.tavern * TAVERN_SERVES) / peasants, 0.0, 1.0)
	if cheered > 0.0:
		parts.append(["Tavern", (TAVERN_HAPPY + skill_total("tavern_bonus") * 100.0) * cheered])
	if part_levels.quarry > 0:
		parts.append(["Quarry dust", -CastleData.QUARRY_DUST * 100.0 * part_levels.quarry])
	if peasants >= max_peasants():
		parts.append(["Crowded houses", MOOD_CROWDED])
	for id: String in policies:
		var points: float = PolicyData.POLICIES[id].effects.get("happiness", 0.0)
		if points != 0.0:
			parts.append([PolicyData.POLICIES[id].name, points])
	for id: String in events:
		var points: float = EventData.EVENTS[id].effects.get("happiness", 0.0)
		if points != 0.0:
			parts.append([EventData.EVENTS[id].name, points])
	for id: String in boosts:
		var points: float = BoostData.BOOSTS[id].effects.get("happiness", 0.0)
		if points != 0.0:
			parts.append([BoostData.BOOSTS[id].name, points])
	var season_points: float = season().effects.get("happiness", 0.0)
	if season_points != 0.0:
		parts.append([season().name, season_points])
	return parts


## Where happiness is heading.
func happiness_target() -> float:
	var target := MOOD_BASE
	for part: Array in happiness_parts():
		target += part[1]
	return clampf(target, 0.0, 100.0)


func _update_mood(delta: float) -> void:
	var before := roundi(happiness)
	happiness = move_toward(happiness, happiness_target(), MOOD_DRIFT * delta)
	if roundi(happiness) != before:
		mood_changed.emit()


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
	if job == "sawyer":
		return part_levels.sawmill * CastleData.SAWYERS_PER_LEVEL
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
		var rate: float = WILD_FOOD_RATE + FARM_RATE_PER_LEVEL * part_levels.farm
		return rate * maxf(1.0 + effect_total("food_site_rate"), 0.0)
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
	var discount := (1.0 - skill_total("part_discount")) * pow(1.0 - CastleData.STOREROOM_DISCOUNT, room_count("store"))
	for type: String in cost:
		cost[type] = ceili(cost[type] * discount)
	# The higher levels of the castle itself need iron fittings.
	var next_level: int = part_levels[id] + 1
	if not is_village(id) and next_level >= CastleData.IRON_FROM_LEVEL:
		cost["iron"] = CastleData.IRON_PER_LEVEL * (next_level - CastleData.IRON_FROM_LEVEL + 1)
	# Basic building needs only wood; later levels, and the finer buildings
	# sooner, need sawn planks as well.
	var fine: bool = id in CastleData.FINE
	var planks_from: int = CastleData.PLANKS_FROM_LEVEL - (1 if fine else 0)
	if next_level >= planks_from and id != "sawmill":
		cost["planks"] = CastleData.PLANKS_PER_LEVEL * (next_level - planks_from + 1) * (2 if fine else 1)
	return cost


## How much longer or shorter than usual shaping and placing a piece takes.
func build_time_mult() -> float:
	return 1.0 - skill_total("work_discount")


## Why the part can't be ordered right now (apart from cost), or "" if it can.
func part_block_reason(id: String) -> String:
	if job_part != "":
		return "Builders are busy"
	if is_village(id):
		if part_levels[id] >= CastleData.PARTS[id].max_level:
			return "Fully built"
	elif id != "walls" and part_levels.walls == 0:
		return "Needs Walls first"
	elif part_levels[id] >= level_cap():
		return "Raise castle rank"
	# The materials must fit in the stores at once.
	for type: String in part_cost(id):
		if part_cost(id)[type] > store_capacity():
			return "Needs a bigger stockhouse (stores hold %d)" % store_capacity()
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


# --- The rooms of the keep ---

## How many rooms of a kind stand finished in the keep.
func room_count(kind: String) -> int:
	var count := 0
	for storey in CastleData.keep_storeys(part_levels.keep):
		count += CastleData.keep_rooms(storey, keep_picks).count(kind)
	return count


## True if raising the part adds a storey whose rooms the player chooses: any
## level of the keep after the first, while it still grows taller.
func needs_room_choice(id: String) -> bool:
	var level: int = part_levels.keep
	return id == "keep" and level > 0 and CastleData.keep_storeys(level + 1) > CastleData.keep_storeys(level)


## How much harder soldiers hit for the armouries in the keep (and boosts).
func armoury_mult() -> float:
	return 1.0 + CastleData.ARMOURY_MIGHT * room_count("armoury") + effect_total("soldier_might")


## What the keep's finished rooms add up to, one line per kind of room, e.g.
## "Bedchamber x3: room for 6 more peasants". Empty without a keep.
func keep_summary() -> PackedStringArray:
	var lines: PackedStringArray = []
	for kind: String in CastleData.ROOMS:
		var count := room_count(kind)
		if count > 0:
			lines.append("%s x%d: %s" % [CastleData.ROOMS[kind].name, count, _room_effect(kind, count)])
	return lines


## What count rooms of a kind do together.
func _room_effect(kind: String, count: int) -> String:
	match kind:
		"beds":
			return "room for %d more peasants" % (CastleData.BEDCHAMBER_PEASANTS * count)
		"store":
			return "building costs %d%% less" % roundi((1.0 - pow(1.0 - CastleData.STOREROOM_DISCOUNT, count)) * 100)
		"armoury":
			return "soldiers hit %d%% harder" % roundi(CastleData.ARMOURY_MIGHT * count * 100)
		"kitchen":
			return "the cooks work here"
	return "no effect yet"


func _scaled_cost(base: Dictionary, growth: float, level: int) -> Dictionary:
	var cost := {}
	for type: String in base:
		cost[type] = ceili(base[type] * pow(growth, level))
	return cost


# --- The building job ---

## Pays for the part's next level and gives the builders the job. rooms is
## the [left room, right room] chosen for a new storey of the keep (see
## needs_room_choice); left out, the storey becomes bedchambers.
func order_part(id: String, rooms := []) -> bool:
	if part_block_reason(id) != "":
		return false
	if not spend(part_cost(id)):
		return false
	if needs_room_choice(id):
		var valid: bool = rooms.size() == 2 and rooms[0] in CastleData.ROOM_PICKS and rooms[1] in CastleData.ROOM_PICKS
		_fit_keep_picks(part_levels.keep - 1)
		keep_picks.append(rooms.duplicate() if valid else CastleData.KEEP_DEFAULT_ROOMS.duplicate())
	job_part = id
	job_plan = BuildPlan.make(id, part_levels[id])
	job_claimed = 0
	job_hauled = 0
	job_formed = 0
	job_lifted = 0
	job_hooked = false
	job_taken = 0
	job_placed = 0
	if job_size() == 0:
		# Nothing to see changes at this level, so there is nothing to place.
		_finish_job()
		return true
	_job_advance()
	castle_changed.emit()
	return true


## The pieces of the job, in the order they are placed.
func job_pieces() -> Array:
	return job_plan.get("pieces", [])


func job_size() -> int:
	return job_pieces().size()


## How many pieces it takes to build the part. The rest, at the end, are
## the scaffolding and the builders' gear being taken away again.
func job_fetch() -> int:
	return job_plan.get("fetch", 0)


## True if the next piece is one a builder can go and fetch from the stockyard.
func job_can_fetch() -> bool:
	return job_claimed < job_size() and job_pieces()[job_claimed].fetch


## A builder at the stockhouse picks up to max_pieces for the job.
## Returns how many they got (0 = nothing left to carry).
func job_take_load(max_pieces: int) -> int:
	var pieces := mini(max_pieces, job_size() - job_claimed)
	job_claimed += pieces
	return pieces


## A builder was reassigned mid-trip: their load goes back to the stockhouse.
func job_return_load(pieces: int) -> void:
	job_claimed = maxi(job_claimed - pieces, job_hauled)


## A builder dropped pieces at the foot of the site.
func job_deliver(pieces: int) -> void:
	job_hauled += pieces
	_job_advance()
	job_delivered.emit()
	job_progress_changed.emit()


## Pieces at the foot of the site waiting to be shaped at the bench.
func job_rough() -> int:
	return job_hauled - job_formed


## The piece on the bench has been shaped.
func job_form() -> void:
	job_formed += 1
	_job_advance()
	job_progress_changed.emit()


## Shaped pieces waiting at the foot of the rope.
func job_ready() -> int:
	return job_formed - job_lifted


## A builder at the foot of the rope has tied the next shaped piece on.
func job_hook() -> void:
	if job_ready() > 0:
		job_hooked = true
		job_progress_changed.emit()


## A piece has been pulled up to the top.
func job_lift() -> void:
	job_hooked = false
	job_lifted += 1
	_job_advance()
	job_progress_changed.emit()


## Pieces waiting for a builder to pick them up and put them in place.
func job_landed() -> int:
	return job_lifted - job_taken


## A builder picks up the next piece to place. Returns which one it is
## (its place in job_pieces()), or -1 if none is waiting.
func job_take_piece() -> int:
	if job_landed() <= 0:
		return -1
	job_taken += 1
	job_progress_changed.emit()
	return job_taken - 1


## A builder was reassigned while carrying a piece to its place: it goes back.
func job_untake() -> void:
	job_taken = maxi(job_taken - 1, job_placed)


## A piece has been put in place. The last one finishes the job.
func job_place() -> void:
	job_placed += 1
	if job_placed >= job_size():
		_finish_job()
	job_progress_changed.emit()


## How far along the job is, from 0 to 1.
func job_fraction() -> float:
	if job_size() == 0:
		return 0.0
	return clampf(float(job_placed) / job_size(), 0.0, 1.0)


## Pieces that need no shaping or no lifting pass those steps by themselves.
func _job_advance() -> void:
	var pieces := job_pieces()
	# Pieces that are not fetched (old work to knock down, scaffolding to
	# take away) are there already, once everything before them has arrived.
	while job_hauled == job_claimed and job_claimed < pieces.size() and not pieces[job_claimed].fetch:
		job_claimed += 1
		job_hauled += 1
	while job_formed < job_hauled and not pieces[job_formed].form:
		job_formed += 1
	while job_lifted < job_formed and not pieces[job_lifted].lift:
		job_lifted += 1


## Makes keep_picks exactly this long: one entry per storey above the first keep's.
func _fit_keep_picks(storeys: int) -> void:
	keep_picks.resize(maxi(storeys, 0))
	for i in keep_picks.size():
		var pick: Variant = keep_picks[i]
		if not (pick is Array and pick.size() == 2 and CastleData.ROOMS.has(pick[0]) and CastleData.ROOMS.has(pick[1])):
			keep_picks[i] = CastleData.KEEP_DEFAULT_ROOMS.duplicate()


func _finish_job() -> void:
	var rank_before := castle_rank()
	part_levels[job_part] += 1
	renown += CastleData.PARTS[job_part].renown
	if castle_rank() > rank_before:
		renown += RENOWN_PER_RANK + int(skill_total("rank_renown"))
		announced.emit("Castle rank %d! Parts can now reach level %d" % [castle_rank(), level_cap()])
	job_part = ""
	job_plan = {}
	job_hooked = false
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
	return 1.0 / ((1.0 + skill_total("gather_speed") + effect_total("gather_speed")) * work_mult())


func tree_grow_mult() -> float:
	var tending: float = jobs.forester * (FORESTER_TEND_BONUS + skill_total("tend"))
	return 1.0 + skill_total("tree_growth") + tending


func tree_bonus_wood() -> int:
	return int(skill_total("tree_wood"))


## How many pieces a builder carries per trip.
func builder_load() -> int:
	return BUILDER_BASE_LOAD + int(skill_total("builder_load"))


func builder_speed_mult() -> float:
	return (1.0 + skill_total("peasant_speed") + skill_total("builder_speed") + effect_total("builder_speed")) * work_mult()


## Seconds of hammering one builder does per second.
func hammer_rate() -> float:
	return (1.0 + skill_total("hammer") + effect_total("hammer")) * work_mult()


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
		_new_day()
	if job_part != "":
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
		"keep_picks": keep_picks,
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
		"no_nights": no_nights,
		"skills": skills,
		"events": events,
		"event_counts": event_counts,
		"messages": messages,
		"policies": policies,
		"boosts": boosts,
		"happiness": happiness,
		"income_rate": income_rate,
		"job": {
			"part": job_part, "hauled": job_hauled, "formed": job_formed,
			"lifted": job_lifted, "placed": job_placed,
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
	var start_stock := mini(LEGACY_START_STOCK * legacy, CastleData.STORE_BASE)
	resources = {"wood": start_stock, "stone": start_stock, "food": START_FOOD, "iron": 0, "planks": 0}
	cows = 0
	for id: String in part_levels:
		part_levels[id] = 0
	keep_picks.clear()
	peasants = START_PEASANTS
	jobs = START_JOBS.duplicate()
	trained = NO_JOBS.duplicate()
	trees = START_TREES
	planting_work = 0.0
	renown = 0
	skills.clear()
	events.clear()
	event_counts.clear()
	messages.clear()
	_event_timer = 0.0
	policies.clear()
	boosts.clear()
	happiness = MOOD_BASE
	day = 1
	day_time = 0.0
	fed = true
	raids_faced = 0
	raids_won = 0
	quest_index = 0
	raid_incoming = false
	job_part = ""
	job_plan = {}
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
	no_nights = bool(data.get("no_nights", false))
	_was_night = is_night()
	skills.clear()
	var saved_skills: Variant = data.get("skills")
	if saved_skills is Dictionary:
		for id: String in saved_skills:
			# Skip anything that is no longer in the skill tree.
			if SkillData.SKILLS.has(id):
				skills[id] = clampi(int(saved_skills[id]), 0, SkillData.SKILLS[id].max_level)

	events.clear()
	var saved_events: Variant = data.get("events")
	if saved_events is Dictionary:
		for id: String in saved_events:
			# An event the game ends itself (a raid) starts again when its time comes.
			if EventData.EVENTS.has(id) and not EventData.EVENTS[id].get("until_done", false):
				events[id] = clampf(float(saved_events[id]), 0.0, EventData.EVENTS[id].lasts)
	messages.clear()
	var saved_messages: Variant = data.get("messages")
	if saved_messages is Array:
		for message: Variant in saved_messages.slice(-LOG_SIZE):
			if message is Dictionary and message.get("text") is String:
				messages.append({"day": int(message.get("day", 1)), "text": message.text})
	event_counts.clear()
	var saved_counts: Variant = data.get("event_counts")
	if saved_counts is Dictionary:
		for id: String in saved_counts:
			if EventData.EVENTS.has(id):
				event_counts[id] = maxi(int(saved_counts[id]), 0)

	happiness = clampf(float(data.get("happiness", MOOD_BASE)), 0.0, 100.0)
	boosts.clear()
	var saved_boosts: Variant = data.get("boosts")
	if saved_boosts is Dictionary:
		for id: String in saved_boosts:
			if BoostData.BOOSTS.has(id):
				boosts[id] = clampf(float(saved_boosts[id]), 0.0, BoostData.BOOSTS[id].lasts)
	policies.clear()
	var saved_policies: Variant = data.get("policies")
	if saved_policies is Array:
		for id: Variant in saved_policies:
			if id is String and PolicyData.POLICIES.has(id) and not id in policies:
				policies.append(id)

	var job: Variant = data.get("job")
	if job is Dictionary and part_levels.has(job.get("part", "")):
		job_part = job.part
		job_plan = BuildPlan.make(job_part, part_levels[job_part])
		job_hauled = clampi(int(job.get("hauled", 0)), 0, job_size())
		job_formed = clampi(int(job.get("formed", 0)), 0, job_hauled)
		job_lifted = clampi(int(job.get("lifted", 0)), 0, job_formed)
		job_placed = clampi(int(job.get("placed", 0)), 0, job_lifted)
		# Pieces that were being carried when the game closed go back to where they were picked up.
		job_claimed = job_hauled
		job_taken = job_placed
		_job_advance()
		if job_placed >= job_size():
			job_part = ""
			job_plan = {}

	# One pair of rooms per storey chosen so far; a storey being built has its pair already.
	var saved_picks: Variant = data.get("keep_picks")
	keep_picks = saved_picks.duplicate(true) if saved_picks is Array else []
	_fit_keep_picks(part_levels.keep - 1 + (1 if needs_room_choice(job_part) else 0))

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
		var gained := mini(int(income_rate[type] * seconds), store_room(type))
		resources[type] += gained
		report[type] = gained
		earned_any = earned_any or gained > 0
	if earned_any:
		offline_report = report
