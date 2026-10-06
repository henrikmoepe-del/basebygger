extends SceneTree
## Logic test for the sandbox's job system. Headless, fixed time steps:
##   godot --headless --fixed-fps 60 --path . -s sandbox/tests/test_sandbox.gd
## Checks: builders spread over several sites by themselves; an order sends
## builders to one site and ends when it is done; Release gives them back to
## free will; an ordered peasant chops a tree; a fire is put out; a raid ends;
## nobody ever leaves the ground band.

const SbData := preload("res://sandbox/sb_data.gd")
const SPEED := 8.0

var _world: Node2D
var _fails := 0
var _off_band := 0


func _initialize() -> void:
	_world = load("res://sandbox/sandbox.tscn").instantiate()
	_world.auto_raids = false
	_world.calm = true
	root.add_child(_world)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


## Runs the world for this many game seconds, or until done() is true.
func _wait(seconds: float, done := Callable()) -> bool:
	var frames := int(seconds * 60.0 / SPEED)
	for i in frames:
		await process_frame
		for p in _world.peasants:
			if p.position.y < SbData.WALK_TOP - 0.01 or p.position.y > SbData.WALK_BOTTOM + 0.01:
				_off_band += 1
		if done.is_valid() and done.call():
			return true
	return false


func _free_x(building: String) -> float:
	var x := -340.0
	while x < 560.0 and not _world.site_fits(building, x):
		x += 5.0
	return x


func _dump() -> void:
	for p in _world.peasants:
		print("  ", p.person_name, " ", p.job, " pos=", p.position.round(), " task=", p.task.get("kind", ""), " order=", p.order.get("kind", ""), " drafted=", p.drafted, " downed=", p.downed, " safe=", p._safe, " asleep=", p._asleep, " hunger=", int(p.hunger), " tired=", int(p.tired))


func _run() -> void:
	Engine.time_scale = SPEED
	var w := _world
	w.stockyard.put("stone", 60)
	w.stockyard.put("wood", 30)
	# Nights are tested on their own (11); until then nobody goes to bed.
	w.night_work = true

	# 1. Free will: the builders spread over the sites.
	await _wait(90.0)
	var started: int = w.sites.filter(func(s): return s.placed > 0).size()
	_check(started >= 2, "builders spread over sites by themselves (%d sites started)" % started)

	var supplied := await _wait(90.0, func(): return w.peasants.any(func(p): return p.task.get("kind", "") == "supply"))
	_check(supplied, "the hauler brings material to a building site")
	if not supplied:
		_dump()
		print("  stock ", w.stockyard.stock, " wanted ", w.sites.map(func(s): return [s.title, s.wanted("stone"), s.wanted("wood"), s.wanted("planks"), s.stock, s.incoming]))

	var stone_in: int = w.stockyard.stock.stone
	var lying_id: int = w.spawn_item("stone", Vector2(150, 50)).get_instance_id()
	var hauled := await _wait(60.0, func(): return not is_instance_id_valid(lying_id) or instance_from_id(lying_id).is_queued_for_deletion())
	_check(hauled, "a loose stone is picked up by someone by themselves")

	# 1b. The sawmill's bill: the crafter saws planks until there are `keep`.
	var mill: Node2D = w.sites.filter(func(s): return s.is_workshop())[0]
	mill.keep = 6
	var sawn := await _wait(120.0, func(): return w.stockyard.stock.planks >= 6)
	_check(sawn, "the crafter saws planks until the bill's 6 are in stock (%d)" % w.stockyard.stock.planks)
	if not sawn:
		_dump()
		print("  stock ", w.stockyard.stock, " mill workers ", mill.workers.size(), " keep ", mill.keep, " find ", w.find_work(w.peasants[8], "craft"))
	var crafter: Node2D = w.peasants.filter(func(p): return p.job == "crafter")[0]
	w.stockyard.stock.planks = mill.keep
	_check(w.find_work(crafter, "craft").is_empty(), "with the bill met there is no craft work")
	# One short, with nobody at the bench yet (a crafter at work counts as one on its way).
	crafter._end_task()
	for p in mill.workers.duplicate():
		p._end_task()
	w.stockyard.stock.planks = mill.keep - 1
	w.stockyard.stock.wood = maxi(w.stockyard.stock.wood, 3)
	_check(not w.find_work(crafter, "craft").is_empty(), "one short of the bill there is")
	mill.keep = 12

	# 2. Order three builders to the Tower.
	var builders: Array = w.peasants.filter(func(p): return p.job == "builder")
	# A fresh site of its own, so it is not finished already.
	var tower: Node2D = w.add_site("tower", Vector2(_free_x("tower"), 4))
	w.select(builders)
	w.give_order(tower.position + Vector2(0, -10))
	await _wait(1.0)
	var on_tower: int = builders.filter(func(p): return p.task.get("target") == tower and p.task.get("forced", false)).size()
	_check(on_tower == 3, "an order sends all three builders to the Tower (%d)" % on_tower)
	var finished := await _wait(400.0, func(): return tower.done())
	_check(finished, "the ordered builders finish the Tower (%d / %d)" % [tower.placed, tower.mats.size()])
	await _wait(2.0)
	var still: int = builders.filter(func(p): return not p.order.is_empty()).size()
	_check(still == 0, "orders end when the Tower is done (%d still ordered)" % still)

	# 3. Release: an order to stand somewhere, then released.
	var b: Node2D = builders[0]
	w.select([b])
	w.give_order(Vector2(0, 50))
	await _wait(1.0)
	_check(b.task.get("kind", "") == "goto", "a right-click on the ground is a go-there order")
	w.release_selected()
	await _wait(1.0)
	_check(b.order.is_empty() and not b.task.get("forced", false), "Release gives the peasant back to free will")

	# 4. Order the hauler to chop a tree.
	var hauler: Node2D = w.peasants.filter(func(p): return p.job == "hauler")[0]
	var tree: Node2D = w.trees[0]
	var logs_before: int = w.items.size()
	w.select([hauler])
	w.order_peasants_to(tree)
	var chopped := await _wait(60.0, func(): return tree.wood < tree._full)
	_check(chopped, "the hauler chops the tree when ordered")
	_check(w.items.size() > logs_before or w.stockyard.stock.wood > 0, "a log falls")
	w.release_selected()

	# 4b. Queued orders: chop a tree, then go and stand by the well.
	var tree2: Node2D = w.trees[1]
	w.select([hauler])
	w.give_order(tree2.position + Vector2(0, -4))
	w.give_order(w.well.position + Vector2(0, 20), true)
	_check(hauler.queue.size() == 1, "Shift + right-click queues an order after the first")
	var moved_on := await _wait(120.0, func(): return hauler.task.get("kind", "") == "goto")
	_check(moved_on and not tree2.is_open(), "after chopping the whole tree the hauler goes on to the queued order (task %s, order %s, queue %d, wood left %d)" % [hauler.task.get("kind", ""), hauler.order.get("kind", ""), hauler.queue.size(), tree2.wood])
	w.release_selected()

	# 5. A fire in the stockyard is put out.
	w.start_fire(w.stockyard)
	var out := await _wait(90.0, func(): return w.fires.is_empty())
	_check(out, "a fire in the stockyard is put out by the peasants")

	# 6. A raid. Two builders are drafted and sent west to meet it.
	var drafted: Array = builders.slice(0, 2)
	w.select(drafted)
	w.toggle_draft_selected()
	_check(drafted.all(func(p): return p.drafted and p.task.get("kind", "") != "build"), "drafting stops their work")
	w.give_order(Vector2(-200, 40))
	await _wait(25.0)
	_check(drafted.all(func(p): return p.position.distance_to(Vector2(-200, 40)) < 20.0 and p.order.is_empty()), "drafted peasants go where sent and hold there")
	w.start_raid(3)
	var engaged := await _wait(40.0, func(): return drafted.any(func(p): return p.task.get("kind", "") == "fight"))
	_check(engaged, "drafted peasants fight raiders who come near")
	await _wait(25.0)
	var fighting_auto: int = w.peasants.filter(func(p): return p.task.get("kind", "") == "fight" and p.prio.fight == 0 and not p.drafted and not p.task.get("forced", false)).size()
	_check(fighting_auto == 0, "peasants who are not guards do not fight by themselves")
	var over := await _wait(200.0, func(): return not w.raid_on)
	_check(over, "the raid ends")
	w.select(drafted.filter(func(p): return p.drafted))
	w.toggle_draft_selected()
	await _wait(3.0)
	_check(drafted.all(func(p): return not p.drafted), "undrafting gives them back to work")

	# 7. Placing a building: not over another one; a new one gets built.
	_check(not w.site_fits("hut", w.sites[0].position.x), "a building cannot be placed over another")
	_check(not w.site_fits("hut", w.stockyard.position.x), "a building cannot be placed over the stockyard")
	var x := _free_x("shed")
	_check(x < 560.0, "a free spot for a shed is found (x %d)" % x)
	var shed: Node2D = w.add_site("shed", Vector2(x, 4))
	shed.urgent = true
	var built := await _wait(200.0, func(): return shed.done())
	_check(built, "a newly placed urgent shed is built by the builders on their own")
	var count: int = w.sites.size()
	w.cancel_site(w.sites[1])
	await _wait(1.0)
	_check(w.sites.size() == count - 1, "a site can be cancelled")

	# 8. Skills grow by doing the work.
	var miner: Node2D = w.peasants.filter(func(p): return p.job == "miner")[0]
	var before: int = miner.skill.mine
	miner.learn("mine", 1000.0)
	_check(miner.skill.mine == before + 1, "practice raises a skill a level")
	_check(miner.skill_mult("mine") > miner.skill_mult("build") or miner.skill.mine <= miner.skill.build, "a higher skill works faster")

	# 9. Rescue: a hurt peasant is carried to a bed in the finished Hut.
	var hut: Node2D = w.sites[0]
	while not hut.done():
		hut.add_block(hut.next_material())
	var hurt: Node2D = w.peasants.filter(func(p): return p.job == "woodcutter")[0]
	hurt.damage(100.0)
	_check(hurt.downed, "a peasant can go down")
	var safe := await _wait(60.0, func(): return hurt._safe)
	_check(safe, "someone carries the hurt peasant to safety by themselves")
	if not safe:
		_dump()
		print("  hurt ", hurt.person_name, " carried=", hurt.carried_by, " bed=", hurt.bed, " hut sleepers=", hut.sleepers)
	_check(hut.sleepers.size() > 0, "the hurt lie in the Hut's beds (%d of 2)" % hut.sleepers.size())
	var up := await _wait(120.0, func(): return not hurt.downed and hut.sleepers.is_empty())
	_check(up, "they get better and get up again, and the beds are free")

	# 10. Needs: a hungry peasant eats, a tired one sleeps, then back to work.
	var eater: Node2D = w.peasants.filter(func(p): return p.job == "miner")[0]
	w.stockyard.put("food", 5)
	eater.hunger = 90.0
	var ate := await _wait(40.0, func(): return eater.hunger < 40.0)
	_check(ate, "a hungry peasant goes and eats")
	var sleeper: Node2D = w.peasants.filter(func(p): return p.job == "forager")[0]
	sleeper.tired = 95.0
	var slept := await _wait(30.0, func(): return sleeper._asleep)
	_check(slept, "a tired peasant goes to sleep")
	var rested := await _wait(60.0, func(): return sleeper.tired <= 0.0 and not sleeper._asleep)
	_check(rested, "and wakes up rested")
	var foraged := await _wait(60.0, func(): return w.bushes.any(func(b): return b.berries < b._full))
	_check(foraged, "the forager picks berries")

	# 11. Night: with Night work off, peasants left to themselves sleep.
	w.set_night_work(false)
	w.time = (21.5 - 8.0) / 24.0 * SbData.DAY_LENGTH
	await _wait(20.0)
	var free_ones: Array = w.peasants.filter(func(p): return not p.downed and not p.drafted and p.order.is_empty())
	var sleeping: int = free_ones.filter(func(p): return p.task.get("kind", "") == "sleep").size()
	_check(sleeping == free_ones.size(), "at night everyone left to themselves goes to sleep (%d of %d)" % [sleeping, free_ones.size()])
	w.set_night_work(true)
	await _wait(25.0)
	var working: int = free_ones.filter(func(p): return p.task.get("kind", "") != "sleep" or p.tired >= SbData.TIRED_NEED).size()
	_check(working == free_ones.size(), "with Night work on they get up and work (%d of %d)" % [working, free_ones.size()])
	# Night work stays on for the tests after this one (as it was before).

	# 12. The alarm bell: all but the guard go inside the gate.
	w.set_alarm(true)
	await _wait(30.0)
	var inside: Array = w.peasants.filter(func(p): return not p.downed and p.job != "guard" and p.order.is_empty() and not p.drafted)
	var sheltered: int = inside.filter(func(p): return p.task.get("kind", "") == "shelter" and not p.visible).size()
	_check(sheltered == inside.size(), "with the bell rung everyone shelters inside the gate (%d of %d)" % [sheltered, inside.size()])
	w.set_alarm(false)
	await _wait(2.0)
	_check(inside.all(func(p): return p.task.get("kind", "") != "shelter" and (p.visible or p.downed)), "after the all clear they come out and go back to work")

	# 13. Forbidding: a forbidden tree is not chopped by free will.
	for t in w.trees:
		t.forbidden = t != w.trees[4]
	var allowed: Node2D = w.trees[4]
	await _wait(40.0)
	var chopped_forbidden: bool = w.trees.any(func(t): return t.forbidden and t.workers.size() > 0)
	_check(not chopped_forbidden, "nobody chops a forbidden tree by themselves")
	for t in w.trees:
		t.forbidden = false

	# 14. Hunting: the hunter shoots a deer, which leaves meat.
	var shot_before: int = w.deer_shot
	var hunted := await _wait(400.0, func(): return w.deer_shot > shot_before)
	_check(hunted, "the hunter shoots a deer by themselves")
	if not hunted:
		_dump()
		print("  deer ", w.deer.map(func(d): return d.position.round()), " meat lying ", w.items.filter(func(it): return it.res == "food").size())
	var meat: int = w.items.filter(func(it): return it.res == "food").size()
	_check(meat >= 1 or w.stockyard.stock.food > 0, "the deer leaves meat")

	# 15. A raider with a torch sets a building alight on the way.
	var lit := false
	for attempt in 3:
		w.start_raid(4)
		lit = await _wait(60.0, func(): return not w.fires.is_empty())
		if lit:
			break
		await _wait(120.0, func(): return not w.raid_on)
	_check(lit, "raiders set a building on fire as they pass")
	await _wait(200.0, func(): return not w.raid_on and w.fires.is_empty())

	# 16. Dozing: a dozing peasant stops; a click wakes them with a boost.
	var napper: Node2D = w.peasants.filter(func(p): return p.job == "builder" and not p.downed)[0]
	napper.tired = 50.0
	napper.mood = 60.0
	napper.dozing = 20.0
	var spot: Vector2 = napper.position
	await _wait(3.0)
	_check(napper.position.distance_to(spot) < 0.5, "a dozing peasant does nothing")
	w.select([])
	napper.wake()
	_check(napper.dozing <= 0.0 and napper._boost > 0.0, "a click wakes them, with a burst of effort")
	_check(napper.skill_mult("build") > 0.0, "traits and boosts keep work going")

	# 17. A rescuer given another order puts the hurt one down, not in the stockyard.
	var patient: Node2D = w.peasants.filter(func(p): return p.job == "miner")[0]
	var rescuer: Node2D = w.peasants.filter(func(p): return p.job == "hauler")[0]
	rescuer.release_order()
	patient.damage(100.0)
	w.select([rescuer])
	w.give_order(patient.position + Vector2(0, -2))
	var picked := await _wait(60.0, func(): return rescuer.carrying == "person")
	_check(picked, "an ordered rescuer picks up the hurt peasant")
	var site2: Node2D = w.sites.filter(func(s): return not s.done())[0]
	w.give_order(site2.position + Vector2(0, -6))
	await _wait(30.0)
	_check(not w.stockyard.stock.has("person") and patient.carried_by != rescuer, "given another order, they put the hurt one down (not in the stockyard)")
	w.release_selected()

	# 18. Mood: very low mood makes a free peasant sulk, then they feel better.
	var glum: Node2D = w.peasants.filter(func(p): return p.job == "woodcutter")[0]
	glum.release_order()
	w.calm = false
	glum.mood = 5.0
	var sulks := await _wait(5.0, func(): return glum.sulking > 0.0)
	_check(sulks, "a peasant whose mood falls very low sulks")
	var over_sulk := await _wait(60.0, func(): return glum.sulking <= 0.0)
	_check(over_sulk and glum.memories.has("sulked"), "after sulking they let off steam (a good thought)")
	glum.mood = 90.0
	w.calm = true
	_check(glum.skill_mult("chop") > 0.0, "high mood keeps work going")

	# 19. A traveller asks to join; taken in, they work; another is sent away.
	var before_n: int = w.peasants.size()
	w.arrive_traveller()
	var guest: Node2D = w.traveller
	_check(not w.question.is_empty(), "the player is asked about the traveller")
	await _wait(30.0)
	_check(guest.position.distance_to(w.stockyard.position) < 60.0 and guest.task.get("kind", "") == "goto", "a traveller walks to the stockyard and waits")
	w.answer_question(0)
	await _wait(10.0)
	_check(w.peasants.size() == before_n + 1 and not guest.guest, "taken in, they join the village")
	_check(guest.task.get("kind", "") != "goto", "and get to work by themselves")
	w.arrive_traveller()
	var other_id: int = w.traveller.get_instance_id()
	w.answer_traveller(false)
	var gone := await _wait(60.0, func(): return not is_instance_id_valid(other_id))
	_check(gone and w.peasants.size() == before_n + 1, "sent away, they leave")

	# 20. Children: one is born, does no work, works with Child labour, grows up.
	var kid: Node2D = w.birth()
	_check(kid != null and kid.child and kid.parents.size() == 2, "a child is born to two parents")
	await _wait(10.0)
	_check(kid.prio.values().all(func(v): return v == 0), "a child does no work")
	w.set_child_labour(true)
	_check(kid.prio.haul == 1, "with Child labour on, the child hauls")
	_check(w.peasants.filter(func(p): return not p.child)[0].thoughts().any(func(t): return t[0] == "Children made to work"), "and the grown-ups mind it")
	w.set_child_labour(false)
	kid.born -= SbData.CHILD_DAYS * SbData.DAY_LENGTH
	await _wait(1.0)
	_check(not kid.child and kid.job == "hauler", "after 3 days the child grows up and works")

	# 21. The hooded man: take his gift, and the price comes later.
	var food_before: int = w.stockyard.stock.food
	var planks_before: int = w.stockyard.stock.planks
	w.arrive_stranger()
	_check(not w.question.is_empty() and w.stranger != null, "the hooded man offers a gift")
	w.answer_question(0)
	_check(w.stranger == null and w._price_at > 0.0, "taking it, a price is owed")
	var messages_before: int = w.messages.size()
	await _wait(SbData.STRANGER_PRICE_AFTER + 5.0)
	_check(w._price_at < 0.0, "the price comes due later")

	# 22. A cave-in: the miner is trapped; others dig them out by themselves.
	var digger_rock: Node2D = w.rocks[0]
	digger_rock.stone = maxi(digger_rock.stone, 3)
	var trapped_miner: Node2D = w.peasants.filter(func(p): return p.job == "miner")[0]
	trapped_miner.release_order()
	digger_rock.claim(trapped_miner)
	digger_rock._cave_in()
	_check(trapped_miner.trapped_at == digger_rock and not trapped_miner.visible, "a cave-in traps the miner")
	var freed := await _wait(90.0, func(): return trapped_miner.trapped_at == null)
	_check(freed and trapped_miner.visible, "the others dig them out by themselves")
	if not freed:
		_dump()
		print("  rock dug ", digger_rock.dug, " workers ", digger_rock.workers.map(func(p): return p.person_name), " hour ", w.hour(), " fires ", w.fires.size(), " raid ", w.raid_on)

	# 23. Pause: the world stops; orders given while paused are carried out after.
	var walker: Node2D = w.peasants.filter(func(p): return p.job == "builder" and not p.downed)[0]
	w.toggle_pause()
	var at_pause: Vector2 = walker.position
	var clock: float = w.time
	w.select([walker])
	w.give_order(Vector2(walker.position.x + 60.0, 50))
	await _wait(5.0)
	_check(walker.position == at_pause and w.time == clock, "paused, nothing moves and the clock stops")
	_check(walker.order.get("kind", "") == "goto", "an order can be given while paused")
	w.toggle_pause()
	await _wait(5.0)
	_check(walker.position != at_pause, "unpaused, the order is carried out")
	w.release_selected()

	_check(_off_band == 0, "nobody leaves the ground band (%d frames off it)" % _off_band)
	print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
