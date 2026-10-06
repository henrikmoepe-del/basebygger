extends "res://sandbox/sb_thing.gd"
## A peasant in the sandbox. Has a job (a preset of work priorities, see
## sb_data.gd), may have an ORDER from the player, and otherwise chooses
## work by itself (`_choose`): the lowest priority number first, then the
## Work grid's column order, then the nearest target.
##
## What the peasant is doing right now is its TASK: a Dictionary with
## "kind" (a work type, or "goto", "flee", "idle"), "target" (a node or null),
## "pos" (for "goto") and "forced" (true when it is the player's order).

const SPEED := 32.0
const PLACE_TIME := 1.2
const FILL_TIME := 0.8
const THROW_TIME := 0.5
const HIT_EVERY := 1.0
const REACH := 9.0
const FLEE_FROM := 70.0
const MAX_LOAD := 3
## Hunting: shooting range, time to aim, chance to hit at skill 0 and per level.
const BOW_RANGE := 70.0
const AIM_TIME := 2.5
const HIT_BASE := 0.35
const HIT_PER_LEVEL := 0.06
## Further than this along the ground, one keeps to the path.
const PATH_FROM := 60.0
## Loose things this near the one picked up are taken along on the same trip.
const GATHER_RADIUS := 26.0
## How near a raider must come before a drafted peasant goes for it.
const DRAFT_ENGAGE := 45.0

var person_name := ""
## A key of SbData.TRAITS.
var trait_key := "plain"
## Dozing on the job (seconds left), and a short boost after being woken.
var dozing := 0.0
var _boost := 0.0
var job := "builder"
## Work type -> priority (1 first, 3 last, 0 never).
var prio := {}
## Skill per kind of work (SbData.SKILLED): level 0-10, and practice
## towards the next level in seconds.
var skill := {}
var practice := {}
## Mood, 0-100, memories (key of SbData.MEMORIES -> seconds left) and
## sulking (seconds left of a break).
var mood := 55.0
var memories := {}
var sulking := 0.0
## Needs, 0-100 (see SbData.HUNGER_TIME and TIRED_TIME).
var hunger := 0.0
var tired := 0.0
## The Hut whose bed one sleeps in, and true while lying asleep.
var _sleep_bed: Node2D = null
var _asleep := false
var hp := 10.0
var max_hp := 10.0
var downed := false
## While down: who carries them, and the Hut whose bed they lie in.
var carried_by: Node2D = null
var bed: Node2D = null
## Down and already brought somewhere safe (a bed, or by the well).
var _safe := false
## The hurt peasant this one is carrying.
var _patient: Node2D = null
var selected := false
## A child: when they were born (world time) and their parents. Children
## do no work unless the Child labour policy is on; they grow up in time.
var child := false
var born := 0.0
var parents: Array = []
## Trapped under the rubble of a cave-in at this rock (or null).
var trapped_at: Node2D = null
## A traveller not yet taken in (does no work), and one sent on their way.
var guest := false
var leaving := false
## The player's order, or empty. Same shape as a task.
var order := {}
## Orders queued after this one (Shift + right-click), done in turn.
var queue: Array = []
## Drafted (G): no work and no fleeing; stands where told and fights any
## raider that comes near, until undrafted.
var drafted := false
var _hold := Vector2.ZERO
var task := {}
## What is on the shoulder: "", "wood", "stone", "food", "water" or
## "person", and how many (a hauler takes up to MAX_LOAD of one kind).
## Setting `carrying` makes it one again.
var carrying := "":
	set(value):
		carrying = value
		carry_n = 1
var carry_n := 1

var _timer := 0.0
var _cool := 0.0
var _walking := false
var _anim := ""
var _wander_to := Vector2.INF
var _idle_think := 0.0
var _hurt := 0.0
var _short := ""
## Made so far of the batch in hand at a workshop.
var _made := 0


func setup(name_: String, job_: String) -> void:
	kind = "peasant"
	person_name = name_
	name = name_
	# A start in their own trade, a little in the others.
	for w in SbData.SKILLED:
		skill[w] = randi_range(0, 2)
		practice[w] = 0.0
	trait_key = SbData.TRAITS.keys().pick_random()
	hunger = randf_range(0.0, 45.0)
	tired = randf_range(0.0, 50.0)
	set_job(job_)
	for w in SbData.SKILLED:
		if SbData.JOBS[job_].work.get(w, 0) == 1:
			skill[w] = randi_range(3, 5)
	hp = max_hp


## How fast the peasant does this work: 0.6 at level 0, 1.0 at 5, 1.4 at 10,
## and slower when starving or worn out.
func skill_mult(work: String) -> float:
	var pace := SbData.STARVED_PACE if hunger >= 100.0 or tired >= 100.0 else 1.0
	if world.is_night():
		pace *= SbData.NIGHT_PACE
	if _boost > 0.0:
		pace *= SbData.BOOST
	if mood >= SbData.MOOD_HIGH:
		pace *= SbData.MOOD_HIGH_PACE
	if child:
		pace *= SbData.CHILD_PACE
	pace *= SbData.TRAITS[trait_key].get("work", 1.0)
	return (0.6 + 0.08 * float(skill.get(work, 5))) * pace


func trait_name() -> String:
	return SbData.TRAITS[trait_key].name


## Something to remember for a while (a key of SbData.MEMORIES).
func remember(key: String) -> void:
	memories[key] = SbData.MEMORIES[key].time


## What the peasant is thinking: [text, value] pairs, worst and best first.
func thoughts() -> Array:
	var list: Array = []
	if hunger >= 100.0:
		list.append(["Starving", -20.0])
	elif hunger >= SbData.HUNGER_NEED:
		list.append(["Hungry", -8.0])
	if tired >= 100.0:
		list.append(["Worn out", -15.0])
	elif tired >= SbData.TIRED_NEED:
		list.append(["Tired", -6.0])
	if hp < max_hp:
		list.append(["In pain", -4.0])
	if drafted:
		list.append(["Drafted", -3.0])
	if world.night_work:
		list.append(["Night work", -5.0])
	if world.child_labour and not child and world.peasants.any(func(o): return o.child):
		list.append(["Children made to work", -4.0])
	for key in memories:
		list.append([SbData.MEMORIES[key].text, SbData.MEMORIES[key].value])
	list.sort_custom(func(a, b): return absf(a[1]) > absf(b[1]))
	return list


func mood_target() -> float:
	var t := SbData.MOOD_BASE
	for th in thoughts():
		t += th[1]
	return clampf(t, 0.0, 100.0)


func _update_mood(delta: float) -> void:
	for key in memories.keys():
		memories[key] -= delta
		if memories[key] <= 0.0:
			memories.erase(key)
	mood = move_toward(mood, mood_target(), SbData.MOOD_DRIFT * delta)


## Woken by the player's click: a start, and a short burst of effort.
func wake() -> void:
	if dozing <= 0.0:
		return
	dozing = 0.0
	_boost = SbData.BOOST_TIME
	world.announce("%s wakes with a start and works all the harder." % person_name)
	queue_redraw()


## " · hungry", " · tired" and so on, for the HUD.
func needs_text() -> String:
	var parts := ""
	if hunger >= 100.0:
		parts += " · starving"
	elif hunger >= SbData.HUNGER_NEED:
		parts += " · hungry"
	if tired >= 100.0:
		parts += " · worn out"
	elif tired >= SbData.TIRED_NEED:
		parts += " · tired"
	return parts


## Practice: seconds spent on skilled work raise the skill.
func learn(work: String, seconds: float) -> void:
	if not skill.has(work) or skill[work] >= SbData.SKILL_MAX:
		return
	practice[work] += seconds
	var need: float = SbData.SKILL_BASE + SbData.SKILL_PER_LEVEL * skill[work]
	if practice[work] >= need:
		practice[work] -= need
		skill[work] += 1
		world.announce("%s got better at %s (level %d)." % [person_name, SbData.WORK_NAMES[work].to_lower(), skill[work]])


func set_job(job_: String) -> void:
	if child and job_ != "hauler":
		# Children have no job until they grow up.
		return
	job = job_
	prio.clear()
	for w in SbData.WORK:
		prio[w] = SbData.JOBS[job].work.get(w, 0)
	max_hp = 16.0 if job == "guard" else 10.0
	hp = minf(hp, max_hp)
	rethink()
	queue_redraw()


## Changes one priority: 1 -> 2 -> 3 -> 0 -> 1.
func cycle_prio(work: String) -> void:
	prio[work] = (prio[work] + 1) % 4
	rethink()


func capacity() -> int:
	return 1


## As a target: a peasant can be worked on (rescued) while down and not
## yet somewhere safe.
func is_open() -> bool:
	return downed and not _safe


func hit(p: Vector2) -> bool:
	if not visible or trapped_at != null:
		return false
	if child and not downed:
		return Rect2(position + Vector2(-4, -11), Vector2(8, 12)).has_point(p)
	if downed:
		return Rect2(position + Vector2(-9, -6), Vector2(18, 8)).has_point(p)
	return Rect2(position + Vector2(-5, -18), Vector2(10, 20)).has_point(p)


func label() -> String:
	return person_name


func job_name() -> String:
	return "Child" if child else SbData.JOBS[job].name


## Buried by a cave-in: out of sight and out of action until dug out.
func trap(rock: Node2D) -> void:
	_drop()
	queue.clear()
	order = {}
	drafted = false
	_end_task()
	trapped_at = rock
	visible = false
	remember("trapped")


func untrap() -> void:
	trapped_at = null
	visible = true
	position = position + Vector2(0, 6)


## Makes this peasant a newborn child of the two parents.
func make_child(parents_: Array) -> void:
	child = true
	born = world.time
	parents = parents_
	_set_child_prio()
	hp = 6.0
	max_hp = 6.0


## Children's priorities follow the Child labour policy.
func _set_child_prio() -> void:
	for w in SbData.WORK:
		prio[w] = SbData.CHILD_WORK.get(w, 0) if world.child_labour else 0


## Grown up: a Hauler from now on.
func grow_up() -> void:
	child = false
	parents = []
	set_job("hauler")
	max_hp = 10.0
	hp = max_hp
	world.announce("%s has grown up and joins the work." % person_name)


## Give an order from the player. It comes before anything else. With
## `add`, it is queued after the orders already given instead.
func set_order(o: Dictionary, add := false) -> void:
	if trapped_at != null:
		return
	var t = o.get("target")
	if t != null and is_instance_valid(t) and t.forbidden:
		# Ordering someone to a forbidden thing allows it again.
		t.forbidden = false
	if add and not order.is_empty():
		queue.append(o)
		return
	queue.clear()
	_end_task()
	if carrying == "person" and o.get("kind", "") != "rescue":
		# Put the hurt one down here before doing something else.
		_drop()
	order = o
	order.forced = true
	task = order
	_claim_task()
	queue_redraw()


## Draft or undraft. Drafting drops the work in hand (and what is carried).
func set_drafted(on: bool) -> void:
	if on == drafted or (on and child):
		return
	drafted = on
	queue.clear()
	order = {}
	_end_task()
	if on:
		_drop()
		_hold = position
	queue_redraw()


## Drop the order and go back to choosing work by oneself.
func release_order() -> void:
	queue.clear()
	if order.is_empty():
		return
	order = {}
	_end_task()


## Starts the next queued order, if any. Returns true if one was started.
func _next_order() -> bool:
	while not queue.is_empty():
		var o: Dictionary = queue.pop_front()
		var t = o.get("target")
		if t != null and (not is_instance_valid(t) or not t.is_open()):
			continue
		order = o
		order.forced = true
		task = order
		_claim_task()
		return true
	return false


## Stop what one is doing now and choose again (an emergency, a new job).
func rethink() -> void:
	if order.is_empty():
		_end_task()


## The thing is leaving the world: stop pointing at it.
func forget(t: Node2D) -> void:
	if order.get("target") == t:
		order = {}
	queue = queue.filter(func(o): return o.get("target") != t)
	if task.get("target") == t:
		task = {}
		_timer = 0.0
		_short = ""


## What the peasant is doing, in a few words, for the HUD.
func activity() -> String:
	if trapped_at != null:
		return "Trapped in a cave-in!"
	if downed:
		return "Down, hurt"
	if dozing > 0.0:
		return "Dozing on the job! (click to wake)"
	if sulking > 0.0 and task.get("kind", "") == "sulk":
		return "Sulking (mood too low)"
	if drafted and not task.get("forced", false):
		return "Drafted: fighting a raider" if task.get("kind", "") == "fight" else "Drafted: holding"
	var prefix := ("Drafted: " if drafted else "Ordered: ") if task.get("forced", false) else ""
	var t: Node2D = task.get("target")
	match task.get("kind", ""):
		"supply":
			return prefix + "bringing %s to %s" % [task.res, t.label()]
		"hunt":
			return prefix + "hunting " + t.label()
		"craft":
			if _short != "":
				return prefix + "waiting for %s at %s" % [_short, t.label()]
			return prefix + "%s at %s" % [t.recipe().bill.to_lower(), t.label()]
		"rescue":
			if t.kind == "rock":
				return prefix + "digging out %s" % (t.trapped.person_name if t.trapped != null else "someone")
			return prefix + ("carrying %s to safety" % t.label() if _patient == t else "going to help %s" % t.label())
		"build":
			if _short != "":
				return prefix + "waiting for %s for %s" % [_short, t.label()]
			return prefix + "building " + t.label()
		"chop":
			return prefix + "chopping " + t.label()
		"mine":
			return prefix + "mining " + t.label()
		"forage":
			return prefix + "picking " + t.label()
		"haul":
			return prefix + "hauling " + t.label()
		"firefight":
			return prefix + "putting out " + t.label()
		"fight":
			return prefix + "fighting " + t.label()
		"deliver":
			return prefix + "taking %s%s to the stockyard" % [(str(carry_n) + " ") if carry_n > 1 else "", carrying]
		"goto":
			return prefix + ("holding here" if _at(task.pos) else "going there")
		"flee":
			return "Fleeing from raiders!"
		"shelter":
			return "Sheltering in the castle (alarm)"
		"eat":
			return "Eating"
		"sleep":
			return "Sleeping" + (" in a bed" if _sleep_bed != null else "") if _asleep else "Going to sleep"
	return "Idle"


func damage(n: float) -> void:
	if downed:
		return
	hp -= n
	_hurt = 0.2
	if hp <= 0.0:
		hp = 0.0
		downed = true
		drafted = false
		dozing = 0.0
		sulking = 0.0
		_drop()
		queue.clear()
		order = {}
		_end_task()
		world.sound("lost")
		remember("hurt")
		for other in world.peasants:
			if other != self and other.position.distance_to(position) < 90.0:
				other.remember("saw_down")
		world.announce("%s is down!" % person_name)
	queue_redraw()


func _process(delta: float) -> void:
	if trapped_at != null:
		# Buried: nothing to do but wait (the rock hurts them now and then).
		visible = false
		return
	if guest:
		# A traveller only walks: to the stockyard to ask, or off east if sent away.
		_walking = false
		if _go(task.pos, delta) and leaving:
			queue_free()
		queue_redraw()
		return
	_cool = maxf(_cool - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	_arrow = maxf(_arrow - delta, 0.0)
	_boost = maxf(_boost - delta, 0.0)
	_walking = false
	_anim = ""
	hunger = minf(hunger + 100.0 / SbData.HUNGER_TIME * delta, 100.0)
	_update_mood(delta)
	if not _asleep:
		var tiring := SbData.NIGHT_TIRING if world.is_night() else 1.0
		tired = minf(tired + 100.0 / SbData.TIRED_TIME * tiring * delta, 100.0)
	if downed:
		if carried_by != null:
			if not is_instance_valid(carried_by) or carried_by.downed:
				carried_by = null
			else:
				# On someone's shoulders: they draw us.
				position = carried_by.position
				visible = false
				return
		visible = true
		# Lying hurt; gets better once no raider is near, faster in a bed.
		if world.nearest_raider(position, 80.0) == null:
			hp += (SbData.HEAL_IN_BED if bed != null else SbData.HEAL) * delta
			if hp >= max_hp * (0.9 if bed != null else 0.5):
				downed = false
				_safe = false
				if bed != null and is_instance_valid(bed):
					bed.sleepers.erase(self)
				bed = null
				world.announce("%s is back on their feet." % person_name)
		queue_redraw()
		return
	if order.is_empty() and not queue.is_empty() and task.get("kind", "") != "deliver":
		_next_order()
	if sulking > 0.0:
		# Had enough: sulking, no work. Orders, drafting, the bell and danger break it.
		sulking -= delta
		if order.is_empty() and not drafted and not world.alarm and world.nearest_raider(position, FLEE_FROM) == null and sulking > 0.0:
			if task.get("kind", "") != "sulk":
				_end_task()
				if carrying == "person":
					_drop()
				task = {"kind": "sulk"}
			_do_idle(delta)
			queue_redraw()
			return
		if sulking <= 0.0:
			remember("sulked")
		sulking = 0.0
		if task.get("kind", "") == "sulk":
			_end_task()
	elif mood < SbData.MOOD_BREAK and order.is_empty() and not drafted and not world.alarm:
		sulking = SbData.SULK_TIME
		world.announce("%s has had enough and sulks for a while." % person_name)
		return
	if dozing > 0.0:
		# Nodding off on the job: nothing gets done until it passes or a click wakes them.
		dozing -= delta
		if order.is_empty() and not drafted and not world.alarm and world.nearest_raider(position, FLEE_FROM) == null and tired < SbData.TIRED_NEED:
			queue_redraw()
			return
		dozing = 0.0
	elif _may_doze(delta):
		dozing = SbData.DOZE_TIME
		queue_redraw()
		return
	if not order.is_empty():
		task = order
	elif drafted:
		_drafted_think()
	elif world.alarm and not downed:
		_shelter()
	else:
		_check_flee()
		_check_needs()
		if not _task_valid():
			_choose()
	_do_task(delta)
	position.y = clampf(position.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
	# Sheltering inside the castle: out of sight (and out of reach).
	visible = not (task.get("kind", "") == "shelter" and _at(task.pos))
	queue_redraw()


## Drafted and without an order: go for a raider that comes near, else
## stand at the spot one was sent to.
func _drafted_think() -> void:
	var t = task.get("target")
	if task.get("kind", "") == "fight" and t != null and is_instance_valid(t) and t.is_open():
		return
	var r: Node2D = world.nearest_raider(position, DRAFT_ENGAGE)
	if r == null:
		r = world.nearest_raider(_hold, DRAFT_ENGAGE)
	if r != null:
		task = {"kind": "fight", "target": r, "forced": false}
		_claim_task()
	else:
		task = {"kind": "goto", "pos": _hold, "forced": false}


## The alarm bell: guards fight or go to their post; everyone else goes
## inside the gate and waits there (still putting out fires inside).
func _shelter() -> void:
	if task.get("kind", "") == "fight" and is_instance_valid(task.get("target")) and task.target.is_open():
		return
	if prio.get("fight", 0) > 0:
		var r: Node2D = world.nearest_raider(position, 120.0)
		if r != null:
			_end_task()
			task = {"kind": "fight", "target": r, "forced": false}
			_claim_task()
			return
		if task.get("kind", "") != "goto":
			_end_task()
			task = {"kind": "goto", "pos": world.guard_post + Vector2(float(hash(name) % 20) - 10.0, 0), "forced": false}
		return
	if task.get("kind", "") != "shelter":
		_end_task()
		if carrying == "person":
			_drop()
		task = {"kind": "shelter", "pos": world.shelter}


## Hungry or tired: stop working to eat or sleep (but not while fleeing).
func _check_needs() -> void:
	var k: String = task.get("kind", "")
	if k == "flee" or k == "eat" or k == "sleep" or carrying == "person":
		return
	if hunger >= SbData.HUNGER_NEED and world.stockyard.stock.food > 0:
		_end_task()
		task = {"kind": "eat"}
	elif tired >= SbData.TIRED_NEED or (_bedtime() and k != "firefight" and k != "rescue" and k != "fight"):
		_end_task()
		task = {"kind": "sleep"}


## Working by day while tired, one may nod off (lazy ones more often).
func _may_doze(delta: float) -> bool:
	# Only while somewhat tired: past TIRED_NEED they go to bed instead.
	if not order.is_empty() or drafted or world.is_night() or tired < SbData.DOZE_TIRED or tired >= SbData.TIRED_NEED or sulking > 0.0:
		return false
	var k: String = task.get("kind", "")
	if not (k in ["build", "chop", "mine", "forage", "craft"]) or carrying == "person":
		return false
	return randf() < SbData.DOZE_CHANCE * SbData.TRAITS[trait_key].get("doze", 1.0) * delta


## Night, and the Night work policy is off: time to sleep.
func _bedtime() -> bool:
	return world.is_night() and not world.night_work


func _check_flee() -> void:
	if prio.get("fight", 0) > 0 or task.get("kind", "") == "flee":
		return
	if world.nearest_raider(position, FLEE_FROM) != null:
		_end_task()
		task = {"kind": "flee"}


func _task_valid() -> bool:
	if task.is_empty():
		return false
	var k: String = task.kind
	if k == "idle":
		_idle_think -= get_process_delta_time()
		return _idle_think > 0.0
	if k == "flee":
		return world.nearest_raider(position, FLEE_FROM * 1.6) != null
	if k == "eat":
		return hunger > 5.0 and (world.stockyard.stock.food > 0 or _timer > 0.0)
	if k == "sleep":
		return tired > 0.0 or _bedtime()
	var t = task.get("target")
	if t != null and (not is_instance_valid(t) or not t.is_open()):
		return false
	return true


## Free will: the most important work there is. Lower priority numbers come
## first; with the same number, the work further left in the Work grid
## (SbData.WORK: fires, fight, rescue, build...) comes first, as in RimWorld;
## within one kind of work, the best target (mostly the nearest).
func _choose() -> void:
	_end_task()
	if carrying == "person" and _patient != null and is_instance_valid(_patient):
		# Still carrying someone hurt (after fleeing, say): finish that first.
		task = {"kind": "rescue", "target": _patient, "forced": false}
		_claim_task()
		return
	for p in [1, 2, 3]:
		for w in SbData.WORK:
			if prio[w] != p:
				continue
			var best: Dictionary = world.find_work(self, w)
			if best.is_empty():
				continue
			task = {"kind": best.kind, "target": best.target, "forced": false, "res": best.get("res", "")}
			_claim_task()
			return
	task = {"kind": "idle"}
	_idle_think = 1.0


func _claim_task() -> void:
	var t = task.get("target")
	if t != null and is_instance_valid(t):
		# Bringing material to a site is not building there.
		if task.get("kind", "") != "supply":
			t.claim(self)
		if task.get("kind", "") == "supply":
			t.incoming[task.res] += 1


func _end_task() -> void:
	var t = task.get("target")
	if t != null and is_instance_valid(t):
		t.release(self)
		if task.get("kind", "") == "supply":
			t.incoming[task.res] = maxi(t.incoming[task.res] - 1, 0)
	if _sleep_bed != null and is_instance_valid(_sleep_bed):
		_sleep_bed.sleepers.erase(self)
	_sleep_bed = null
	_asleep = false
	task = {}
	_timer = 0.0
	_short = ""


## The order is done: back to free will.
func _order_done(note := "") -> void:
	if note != "" and selected:
		world.announce(note)
	order = {}
	_end_task()


func _finish_unit() -> void:
	# Choosing for oneself: look around again after each piece of work.
	if not task.get("forced", false):
		_end_task()


func _do_task(delta: float) -> void:
	var forced: bool = task.get("forced", false)
	var t = task.get("target")
	if t != null and (not is_instance_valid(t) or not t.is_open()):
		if forced:
			_order_done("%s has finished the order." % person_name)
		else:
			_end_task()
		return
	match task.get("kind", ""):
		"rescue":
			if t.kind == "rock":
				_do_dig(t, delta)
			else:
				_do_rescue(t, delta)
		"build":
			_do_build(t, delta)
		"supply":
			_do_supply(t, delta)
		"craft":
			_do_craft(t, delta)
		"hunt":
			_do_hunt(t, delta)
		"chop":
			_do_gather(t, delta, "chop")
		"mine":
			_do_gather(t, delta, "mine")
		"forage":
			_do_gather(t, delta, "forage")
		"haul":
			_do_haul(t, delta)
		"firefight":
			_do_firefight(t, delta)
		"fight":
			_do_fight(t, delta)
		"shelter":
			_go(task.pos, delta, 1.2)
		"goto":
			if _go(task.pos, delta) and forced and (drafted or not queue.is_empty()):
				# Holding a spot ends when there is more to do after it. A
				# drafted peasant holds the new spot from now on.
				if drafted:
					_hold = task.pos
				_order_done()
		"deliver":
			_process_deliver(delta)
		"flee":
			var from: Node2D = world.nearest_raider(position, FLEE_FROM * 2.0)
			var away := 1.0 if from == null or from.position.x < position.x else -1.0
			_go(Vector2(clampf(position.x + away * 60.0, SbData.WEST_EDGE + 10, SbData.EAST_EDGE - 10), position.y), delta, 1.25)
		"idle":
			_do_idle(delta)
		"eat":
			_do_eat(delta)
		"sleep":
			_do_sleep(delta)


func _do_build(site: Node2D, delta: float) -> void:
	if site.done():
		if task.get("forced", false):
			_order_done()
		else:
			_end_task()
		return
	var need: String = site.next_material()
	if carrying != need and site.stock[need] > 0 and carrying == "":
		# Material brought by a hauler lies at the site: take it from there.
		if _go(site.pile_spot() + Vector2(4, 2), delta):
			if site.stock[need] > 0:
				site.stock[need] -= 1
				site.queue_redraw()
				carrying = need
		return
	if carrying != need:
		var yard: Node2D = world.stockyard
		if _go(yard.work_spot(self), delta):
			_put_away(yard)
			if yard.take(need):
				carrying = need
				_short = ""
			else:
				_short = need
				if not task.get("forced", false):
					_end_task()
		return
	if _go(site.work_spot(self), delta):
		_anim = "build"
		if int((_timer + delta) / 0.4) != int(_timer / 0.4):
			world.sound("hammer", position)
		_timer += delta * skill_mult("build")
		learn("build", delta)
		if _timer >= PLACE_TIME:
			_timer = 0.0
			site.add_block(carrying)
			carrying = ""
			_finish_unit()


## Digs at the rubble of a cave-in until the trapped one is free.
func _do_dig(rock: Node2D, delta: float) -> void:
	if carrying != "":
		_drop()
	if rock.trapped == null:
		if task.get("forced", false):
			_order_done()
		else:
			_end_task()
		return
	if _go(rock.work_spot(self), delta):
		_anim = "mine"
		if rock.dig(delta):
			if task.get("forced", false):
				_order_done()
			else:
				_end_task()


## Picks up a hurt peasant and carries them to a free bed in a Hut, or to
## the well if there is none.
func _do_rescue(patient: Node2D, delta: float) -> void:
	if _patient != patient:
		if carrying != "":
			_drop()
		if patient.carried_by != null and patient.carried_by != self:
			_end_task()
			return
		if _go(patient.position + Vector2(-6, 0), delta):
			patient.carried_by = self
			_patient = patient
			carrying = "person"
		return
	var hut: Node2D = world.free_bed()
	var spot: Vector2 = hut.bed_spot(hut.sleepers.size()) if hut != null else world.well.position + Vector2(-16, 6)
	if hut != null and patient.bed == null:
		# Hold the bed while carrying them there.
		hut.sleepers.append(patient)
		patient.bed = hut
	if patient.bed != null:
		spot = patient.bed.bed_spot(patient.bed.sleepers.find(patient))
	if _go(spot + Vector2(-6, 0), delta):
		patient.carried_by = null
		patient.position = spot
		patient._safe = true
		if patient.bed != null:
			world.announce("%s brought %s to a bed." % [person_name, patient.person_name])
		_patient = null
		carrying = ""
		if task.get("forced", false):
			_order_done()
		else:
			_end_task()


## Works at a workshop: fetch the input from the stockyard, make one at the
## bench, carry the output back. Ordered, one keeps on past the bill.
func _do_craft(shop: Node2D, delta: float) -> void:
	var r: Dictionary = shop.recipe()
	var yard: Node2D = world.stockyard
	if carrying == r.output:
		if _go(yard.work_spot(self), delta):
			yard.put(carrying, carry_n)
			carrying = ""
			_finish_unit()
		return
	if carrying != r.input:
		if carrying != "":
			_drop()
		if _go(yard.work_spot(self), delta):
			if yard.take(r.input):
				# Take the input for a few at once (as many as the bill still wants).
				var n := 1
				var want: int = shop.keep - yard.stock.get(r.output, 0)
				while n < MAX_LOAD and n < want and yard.take(r.input):
					n += 1
				carrying = r.input
				carry_n = n
				_made = 0
				_short = ""
			else:
				_short = r.input
				if not task.get("forced", false):
					_end_task()
		return
	if _go(shop.work_spot_craft(self), delta):
		_anim = "craft"
		_timer += delta * skill_mult("craft")
		learn("craft", delta)
		if _timer >= r.time:
			_timer = 0.0
			_made += 1
			if _made >= carry_n:
				carrying = r.output
				carry_n = _made
				_made = 0


## Creeps within bow range of the deer, aims, shoots. A miss scares it off;
## the hunter follows.
var _arrow := 0.0
var _arrow_to := Vector2.ZERO


func _do_hunt(prey: Node2D, delta: float) -> void:
	if carrying != "":
		_drop()
	var d := position.distance_to(prey.position)
	if d > BOW_RANGE * 0.85:
		# Creep closer, slowly at the end.
		_timer = 0.0
		_go(prey.position, delta, 0.6 if d < BOW_RANGE * 1.3 else 1.0)
		return
	_anim = "aim"
	scale.x = 1.0 if prey.position.x > position.x else -1.0
	_timer += delta * skill_mult("hunt")
	learn("hunt", delta)
	if _timer >= AIM_TIME:
		_timer = 0.0
		_arrow = 0.25
		_arrow_to = prey.position + Vector2(0, -6)
		world.sound("arrow", position)
		if randf() < HIT_BASE + HIT_PER_LEVEL * float(skill.hunt):
			var where: Vector2 = prey.position
			prey.shot()
			if not prey.is_open() and order.is_empty():
				# A kill: carry the meat home oneself.
				for it in world.items:
					if it.res == "food" and it.workers.is_empty() and it.position.distance_to(where) < 14.0:
						_end_task()
						task = {"kind": "haul", "target": it, "forced": false}
						_claim_task()
						break
		else:
			prey.scare(position)
			if not task.get("forced", false) and randf() < 0.4:
				# Gave up on this one for now.
				_end_task()


## Brings one load of material from the stockyard to a building site.
func _do_supply(site: Node2D, delta: float) -> void:
	var res: String = task.res
	if carrying != res:
		if carrying != "":
			_drop()
		var yard: Node2D = world.stockyard
		if _go(yard.work_spot(self), delta):
			if yard.take(res):
				carrying = res
			else:
				_end_task()
		return
	if _go(site.pile_spot() + Vector2(6, 4), delta):
		site.stock[res] += 1
		site.queue_redraw()
		carrying = ""
		_end_task()


func _do_gather(thing: Node2D, delta: float, how: String) -> void:
	if carrying != "":
		_drop()
	if _go(thing.work_spot(self), delta):
		_anim = how
		var amount := delta * skill_mult(how)
		learn(how, delta)
		var fell: bool = thing.call(how, amount)
		if fell:
			_finish_unit()


func _do_haul(item: Node2D, delta: float) -> void:
	if carrying != "" and carrying != item.res:
		_drop()
	if _go(item.work_spot(self), delta):
		var res: String = item.res
		# Already carrying some of the same: they come along too.
		var n := carry_n + 1 if carrying == res else 1
		# Take along others of the same kind lying close by that nobody has claimed.
		for other in world.items.duplicate():
			if n >= MAX_LOAD:
				break
			if other != item and other.res == res and other.workers.is_empty() and other.position.distance_to(item.position) < GATHER_RADIUS:
				world.remove_thing(other)
				n += 1
		world.remove_thing(item)
		carrying = res
		carry_n = n
		task = {"kind": "deliver", "forced": task.get("forced", false)}
		if not order.is_empty():
			order = {}
	return


func _do_firefight(fire: Node2D, delta: float) -> void:
	if carrying != "water":
		if carrying != "":
			_drop()
		if _go(world.well.work_spot(self), delta):
			_anim = "fill"
			_timer += delta
			if _timer >= FILL_TIME:
				_timer = 0.0
				carrying = "water"
		return
	if _go(fire.work_spot(self), delta):
		_anim = "throw"
		_timer += delta
		if _timer >= THROW_TIME:
			_timer = 0.0
			carrying = ""
			fire.douse()


func _do_fight(raider: Node2D, delta: float) -> void:
	if carrying != "":
		_drop()
	if position.distance_to(raider.position) > REACH:
		_go(raider.work_spot(self), delta, 1.1)
		return
	_anim = "fight"
	learn("fight", delta)
	if _cool <= 0.0:
		_cool = HIT_EVERY
		var base := 3.0 if job == "guard" else (2.0 if drafted else 1.5)
		raider.damage(base * skill_mult("fight"))


func _do_idle(delta: float) -> void:
	if carrying == "person" or carrying == "water":
		_drop()
	if _goods():
		# Put away what one carries before resting.
		var yard: Node2D = world.stockyard
		if _go(yard.work_spot(self), delta):
			_put_away(yard)
		return
	if child:
		# Children stay near a parent (or the stockyard).
		var near: Vector2 = world.stockyard.position + Vector2(10, 30)
		for par in parents:
			if is_instance_valid(par) and not par.downed and par.visible:
				near = par.position + Vector2(-10, 6)
				break
		if position.distance_to(near) > 16.0:
			_go(near, delta)
		return
	if job == "guard":
		_go(world.guard_post + Vector2(float(hash(name) % 24) - 12.0, float(hash(name) % 14)), delta)
		return
	if _wander_to == Vector2.INF or _go(_wander_to, delta, 0.5):
		if _wander_to != Vector2.INF and randf() < 0.98:
			return
		var home: Vector2 = world.stockyard.position
		_wander_to = Vector2(home.x + randf_range(-90, 90), randf_range(SbData.WALK_TOP + 8, SbData.WALK_BOTTOM))


func _process_deliver(delta: float) -> void:
	if not _goods():
		_drop()
		_end_task()
		return
	var yard: Node2D = world.stockyard
	if _go(yard.work_spot(self), delta):
		_put_away(yard)
		_end_task()


func _do_eat(delta: float) -> void:
	var yard: Node2D = world.stockyard
	if carrying == "water" or carrying == "person":
		_drop()
	if _goods():
		if _go(yard.work_spot(self), delta):
			_put_away(yard)
		return
	if _go(yard.position + Vector2(46 + float(hash(name) % 10), 8), delta):
		_anim = "eat"
		_timer += delta
		if _timer >= SbData.EAT_TIME:
			_timer = 0.0
			if yard.take("food"):
				hunger = maxf(hunger - 70.0, 0.0)
				remember("ate")
			_end_task()


## Sleeps in a free bed in a Hut, or on the ground where one stands.
func _do_sleep(delta: float) -> void:
	if not _asleep:
		if carrying != "":
			_drop()
		if _sleep_bed == null:
			# Take a free bed in a Hut (it is ours from now on), or sleep here.
			var hut: Node2D = world.free_bed()
			if hut == null:
				_asleep = true
				return
			hut.sleepers.append(self)
			_sleep_bed = hut
		if _go(_sleep_bed.bed_spot(_sleep_bed.sleepers.find(self)), delta):
			_asleep = true
		return
	var time := SbData.SLEEP_TIME_BED if _sleep_bed != null else SbData.SLEEP_TIME
	tired = maxf(tired - 100.0 / time * delta, 0.0)
	if tired <= 0.0 and not _bedtime():
		remember("bed" if _sleep_bed != null else "ground")
		_end_task()


## True if what one carries is goods that belong in the stockyard.
func _goods() -> bool:
	return carrying in ["wood", "stone", "food", "planks"]


## Puts what one carries into the stockyard if it is goods there; anything
## else (water, a hurt person) is put down instead.
func _put_away(yard: Node2D) -> void:
	if _goods():
		yard.put(carrying, carry_n)
		carrying = ""
	else:
		_drop()


## Puts what one carries down on the ground, for someone to haul later.
func _drop() -> void:
	if carrying == "person" and _patient != null and is_instance_valid(_patient):
		_patient.carried_by = null
		_patient.position = position + Vector2(4, 1)
		# The bed held for them is free again.
		if _patient.bed != null and is_instance_valid(_patient.bed):
			_patient.bed.sleepers.erase(_patient)
		_patient.bed = null
		_patient = null
	if carrying == "wood" or carrying == "stone" or carrying == "food" or carrying == "planks":
		for i in carry_n:
			world.spawn_item(carrying, position + Vector2(4 + i * 3, 1 + i))
	carrying = ""


func _walk_mult() -> float:
	return SbData.TRAITS[trait_key].get("speed", 1.0)


func _at(p: Vector2) -> bool:
	return position.distance_to(p) < 1.0


## Walks towards p across the ground band. Returns true once there. On a
## long way they keep to the dirt path, each in their own lane on it, and
## leave it near the end.
func _go(p: Vector2, delta: float, pace := 1.0) -> bool:
	p.y = clampf(p.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
	if _at(p):
		return true
	_walking = true
	var dx := p.x - position.x
	if absf(dx) > PATH_FROM:
		var lane := float(hash(name) % 7) - 3.0
		var vy := clampf((world.path_y(position.x) + lane - position.y) * 0.08, -0.8, 0.8)
		position += Vector2(signf(dx), vy).normalized() * SPEED * pace * _walk_mult() * delta
	else:
		position = position.move_toward(p, SPEED * pace * _walk_mult() * delta)
	if absf(p.x - position.x) > 0.5:
		scale.x = 1.0 if p.x > position.x else -1.0
	return _at(p)


func _draw() -> void:
	var tunic: Color = SbData.JOBS[job].tunic
	if _hurt > 0.0:
		tunic = SbData.WHITE
	if downed or _asleep:
		if bed != null or _sleep_bed != null:
			# In bed: a straw mattress and a blanket.
			draw_rect(Rect2(-8, -2, 16, 2), SbData.THATCH)
		draw_rect(Rect2(-6, -4, 10, 4), tunic)
		draw_rect(Rect2(4, -4, 4, 4), SbData.SKIN1)
		draw_rect(Rect2(-9, -3, 3, 2), SbData.INK)
		if bed != null or _sleep_bed != null:
			draw_rect(Rect2(-7, -4, 10, 3), SbData.TEAL)
		if _asleep:
			# Little z's drifting up.
			var zt := fmod(Time.get_ticks_msec() / 1000.0, 2.0)
			draw_rect(Rect2(6 + zt * 2.0, -9 - zt * 4.0, 3, 1), SbData.WHITE)
			draw_rect(Rect2(7 + zt * 2.0, -8 - zt * 4.0, 1, 1), SbData.WHITE)
			draw_rect(Rect2(6 + zt * 2.0, -7 - zt * 4.0, 3, 1), SbData.WHITE)
		_draw_marks(-8.0)
		return
	var t := Time.get_ticks_msec() / 1000.0
	var step := int(t / 0.14 + position.x) % 2 if _walking else -1
	if child:
		_draw_child(step, tunic)
		return
	draw_rect(Rect2(-2, -3, 2, 2 if step == 0 else 3), SbData.INK)
	draw_rect(Rect2(1, -3, 2, 2 if step == 1 else 3), SbData.INK)
	var bob := 0.0
	if _anim != "" and _anim != "fill":
		bob = -1.0 if int(t * 4.0) % 2 == 0 else 0.0
	draw_rect(Rect2(-3, bob - 13, 6, 10), tunic)
	# The head droops while dozing.
	draw_rect(Rect2(-2 + (1 if dozing > 0.0 else 0), bob - 17 + (2 if dozing > 0.0 else 0), 4, 4), SbData.SKIN1)
	# Read the job from the silhouette: what they wear and hold.
	match job:
		"guard":
			draw_rect(Rect2(-3, bob - 18, 6, 2), SbData.STONE3)
			draw_rect(Rect2(4, bob - 22, 1, 19), SbData.WOOD1)
			draw_rect(Rect2(4, bob - 24, 1, 2), SbData.STONE4)
		"woodcutter":
			if carrying == "":
				_draw_tool(bob, SbData.STONE3)
		"miner":
			draw_rect(Rect2(-3, bob - 18, 6, 1), SbData.WOOD2)
			if carrying == "":
				_draw_tool(bob, SbData.STONE2)
		"builder":
			draw_rect(Rect2(-3, bob - 7, 6, 1), SbData.WOOD3)
			if carrying == "":
				_draw_tool(bob, SbData.WOOD3)
		"forager":
			draw_rect(Rect2(-3, bob - 18, 6, 1), SbData.GRASS2)
		"crafter":
			draw_rect(Rect2(-3, bob - 9, 6, 3), SbData.WOOD3)
		"hunter":
			# A hood and a bow.
			draw_rect(Rect2(-3, bob - 18, 6, 2), SbData.GRASS1)
			if carrying == "":
				var bow_x := 4.0
				draw_rect(Rect2(bow_x, bob - 15, 1, 10), SbData.WOOD1)
				draw_rect(Rect2(bow_x + 1, bob - 16, 1, 1), SbData.WOOD1)
				draw_rect(Rect2(bow_x + 1, bob - 5, 1, 1), SbData.WOOD1)
				if _anim == "aim":
					draw_rect(Rect2(bow_x - 3, bob - 11, 6, 1), SbData.WOOD3)
		"hauler":
			draw_rect(Rect2(-4, bob - 18, 8, 1), SbData.THATCH)
			draw_rect(Rect2(-2, bob - 19, 4, 1), SbData.THATCH)
	if drafted and job != "guard":
		# A cudgel in hand.
		draw_rect(Rect2(4, bob - 15, 1, 9), SbData.WOOD0)
		draw_rect(Rect2(3, bob - 17, 3, 3), SbData.WOOD1)
	# What is carried, on the shoulder.
	match carrying:
		"wood":
			for i in carry_n:
				draw_rect(Rect2(-7, bob - 16 - i * 3, 13, 3), SbData.WOOD2)
				draw_rect(Rect2(-7, bob - 16 - i * 3, 13, 1), SbData.WOOD3)
		"stone":
			for i in carry_n:
				draw_rect(Rect2(-4, bob - 21 - i * 5, 8, 5), SbData.STONE3)
				draw_rect(Rect2(-4, bob - 21 - i * 5, 8, 1), SbData.STONE4)
		"planks":
			draw_rect(Rect2(-8, bob - 17, 15, 1), SbData.PLANK)
			draw_rect(Rect2(-7, bob - 16, 15, 1), SbData.WOOD3)
			draw_rect(Rect2(-8, bob - 15, 15, 1), SbData.PLANK)
		"food":
			draw_rect(Rect2(3, bob - 9, 5, 4), SbData.WOOD3)
			draw_rect(Rect2(4, bob - 10, 3, 1), SbData.RED1)
		"person":
			if _patient != null and is_instance_valid(_patient):
				draw_rect(Rect2(-6, bob - 17, 10, 3), SbData.JOBS[_patient.job].tunic)
				draw_rect(Rect2(4, bob - 18, 3, 3), SbData.SKIN1)
				draw_rect(Rect2(-8, bob - 16, 2, 2), SbData.INK)
		"water":
			draw_rect(Rect2(3, bob - 9, 4, 4), SbData.WOOD1)
			draw_rect(Rect2(3, bob - 9, 4, 1), SbData.SKY2)
	if _anim == "throw":
		draw_rect(Rect2(6, bob - 14, 3, 2), SbData.SKY3)
		draw_rect(Rect2(9, bob - 12, 2, 2), SbData.SKY2)
	if sulking > 0.0:
		# A little dark cloud over the head.
		draw_rect(Rect2(-4, bob - 28, 8, 3), SbData.STONE1)
		draw_rect(Rect2(-3, bob - 30, 5, 2), SbData.STONE1)
		draw_rect(Rect2(-2, bob - 25, 1, 2), SbData.SKY2)
		draw_rect(Rect2(2, bob - 25, 1, 2), SbData.SKY2)
	if dozing > 0.0:
		var zt := fmod(Time.get_ticks_msec() / 1000.0, 2.0)
		draw_rect(Rect2(4 + zt * 2.0, bob - 22 - zt * 4.0, 3, 1), SbData.WHITE)
		draw_rect(Rect2(5 + zt * 2.0, bob - 21 - zt * 4.0, 1, 1), SbData.WHITE)
		draw_rect(Rect2(4 + zt * 2.0, bob - 20 - zt * 4.0, 3, 1), SbData.WHITE)
	if _boost > 0.0 and int(Time.get_ticks_msec() / 200) % 3 == 0:
		draw_rect(Rect2(-5, bob - 15, 1, 1), SbData.GOLD)
		draw_rect(Rect2(5, bob - 10, 1, 1), SbData.GOLD)
	_draw_marks(bob - 24.0)
	if _arrow > 0.0:
		# The arrow in flight, drawn from the bow towards the target.
		var to := (_arrow_to - position) * Vector2(scale.x, 1.0)
		var at := Vector2(4, -12).lerp(to, 1.0 - _arrow / 0.25)
		draw_line(at, at - (to - Vector2(4, -12)).normalized() * 5.0, SbData.WOOD3, 1.0)


## A child: 10 high (art direction), drawn as its own small figure.
func _draw_child(step: int, tunic: Color) -> void:
	draw_rect(Rect2(-2, -2, 1, 2 if step != 0 else 1), SbData.INK)
	draw_rect(Rect2(1, -2, 1, 2 if step != 1 else 1), SbData.INK)
	draw_rect(Rect2(-2, -7, 4, 5), SbData.DAUB if not world.child_labour else tunic)
	draw_rect(Rect2(-1, -10, 3, 3), SbData.SKIN1)
	match carrying:
		"wood", "stone", "food", "planks":
			draw_rect(Rect2(2, -6, 3, 3), SbData.WOOD3 if carrying != "stone" else SbData.STONE3)
	_draw_marks(-16.0)


## A tool raised or swung while working.
func _draw_tool(bob: float, head: Color) -> void:
	var up := _anim != "" and int(Time.get_ticks_msec() / 250) % 2 == 0
	if up:
		draw_rect(Rect2(3, bob - 17, 1, 7), SbData.WOOD1)
		draw_rect(Rect2(3, bob - 18, 3, 2), head)
	else:
		draw_rect(Rect2(3, bob - 10, 6, 1), SbData.WOOD1)
		draw_rect(Rect2(8, bob - 11, 2, 3), head)


## Selection brackets, the order mark, and a health bar when hurt.
func _draw_marks(top: float) -> void:
	if selected:
		var c := SbData.GOLD
		var l := -7.0
		var r := 6.0
		var b := 1.0
		for corner in [Vector2(l, top + 4), Vector2(r, top + 4), Vector2(l, b), Vector2(r, b)]:
			draw_rect(Rect2(corner, Vector2(2, 1)), c)
		draw_rect(Rect2(l, top + 4, 1, 2), c)
		draw_rect(Rect2(r + 1, top + 4, 1, 2), c)
		draw_rect(Rect2(l, b - 1, 1, 2), c)
		draw_rect(Rect2(r + 1, b - 1, 1, 2), c)
	if drafted:
		# A small red shield over the head.
		draw_rect(Rect2(-2, top - 4, 5, 4), SbData.RED1)
		draw_rect(Rect2(-1, top, 3, 1), SbData.RED1)
		draw_rect(Rect2(0, top - 3, 1, 2), SbData.GOLD)
	elif not order.is_empty() or not queue.is_empty():
		draw_rect(Rect2(-1, top - 4, 2, 4), SbData.GOLD)
		draw_rect(Rect2(-1, top + 1, 2, 1), SbData.GOLD)
	if hp < max_hp:
		draw_rect(Rect2(-5, top + 2, 10, 1), SbData.RED0)
		draw_rect(Rect2(-5, top + 2, 10.0 * hp / max_hp, 1), SbData.GRASS3)
