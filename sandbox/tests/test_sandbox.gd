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


func _run() -> void:
	Engine.time_scale = SPEED
	var w := _world
	w.stockyard.put("stone", 60)
	w.stockyard.put("wood", 30)

	# 1. Free will: the builders spread over the sites.
	await _wait(90.0)
	var started: int = w.sites.filter(func(s): return s.placed > 0).size()
	_check(started >= 2, "builders spread over sites by themselves (%d sites started)" % started)

	var supplied := await _wait(60.0, func(): return w.sites.any(func(s): return s.stock.stone + s.stock.wood > 0))
	_check(supplied, "the hauler brings material to a building site")

	# 2. Order three builders to the Tower.
	var builders: Array = w.peasants.filter(func(p): return p.job == "builder")
	var tower: Node2D = w.sites[2]
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
	_check(moved_on and not tree2.is_open(), "after chopping the whole tree the hauler goes on to the queued order")
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
	await _wait(10.0)
	_check(drafted.all(func(p): return p.position.distance_to(Vector2(-200, 40)) < 20.0 and p.order.is_empty()), "drafted peasants go where sent and hold there")
	w.start_raid(3)
	var engaged := await _wait(40.0, func(): return drafted.any(func(p): return p.task.get("kind", "") == "fight"))
	_check(engaged, "drafted peasants fight raiders who come near")
	await _wait(25.0)
	var fighting_auto: int = w.peasants.filter(func(p): return p.task.get("kind", "") == "fight" and p.prio.fight == 0 and not p.drafted and not p.task.get("forced", false)).size()
	_check(fighting_auto == 0, "peasants who are not guards do not fight by themselves")
	var over := await _wait(200.0, func(): return not w.raid_on)
	_check(over, "the raid ends")
	w.select(drafted.filter(func(p): return not p.downed))
	w.toggle_draft_selected()
	await _wait(3.0)
	_check(drafted.all(func(p): return not p.drafted), "undrafting gives them back to work")

	# 7. Placing a building: not over another one; a new one gets built.
	_check(not w.site_fits("hut", w.sites[0].position.x), "a building cannot be placed over another")
	_check(not w.site_fits("hut", w.stockyard.position.x), "a building cannot be placed over the stockyard")
	var x := -260.0
	_check(w.site_fits("shed", x), "a shed fits west of the Hut")
	var shed: Node2D = w.add_site("shed", Vector2(x, 4))
	shed.urgent = true
	var built := await _wait(200.0, func(): return shed.done())
	_check(built, "a newly placed urgent shed is built by the builders on their own")
	w.cancel_site(w.sites[1])
	await _wait(1.0)
	_check(w.sites.size() == 3, "a site can be cancelled")

	# 8. Skills grow by doing the work.
	var miner: Node2D = w.peasants.filter(func(p): return p.job == "miner")[0]
	var before: int = miner.skill.mine
	miner.learn("mine", 1000.0)
	_check(miner.skill.mine == before + 1, "practice raises a skill a level")
	_check(miner.skill_mult("mine") > miner.skill_mult("build") or miner.skill.mine <= miner.skill.build, "a higher skill works faster")

	_check(_off_band == 0, "nobody leaves the ground band (%d frames off it)" % _off_band)
	print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
