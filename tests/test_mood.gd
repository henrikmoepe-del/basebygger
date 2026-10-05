extends SceneTree
## Checks happiness: what raises and lowers it, that it drifts towards its
## target, that it speeds up or slows down work, and that the happy and
## unhappy events only happen when they should.
## Run with:
##   godot --headless --path . -s tests/test_mood.gd -- --save=user://test_save.json

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ok := true
	gs.day = 5
	gs.fed = true
	gs.policies.clear()
	gs.events.clear()
	for part in ["well", "tavern", "quarry", "houses"]:
		gs.part_levels[part] = 0
	gs.peasants = 3
	var target: float = gs.happiness_target()
	print("fed, no well or tavern: heading for %.1f, parts %s" % [target, gs.happiness_parts()])
	gs.part_levels.well = 2
	gs.part_levels.tavern = 2
	print("with a well and a tavern: heading for %.1f" % gs.happiness_target())
	ok = ok and gs.happiness_target() > target
	target = gs.happiness_target()
	gs.toggle_policy("rations")
	print("with smaller rations: heading for %.1f" % gs.happiness_target())
	ok = ok and gs.happiness_target() < target
	gs.toggle_policy("rations")
	gs.fed = false
	print("hungry: heading for %.1f" % gs.happiness_target())
	ok = ok and gs.happiness_target() < target
	gs.fed = true

	# It drifts, it does not jump.
	gs.happiness = 50.0
	var t := 0.0
	while t < 4.0:
		await process_frame
		t += root.get_process_delta_time()
	print("after 4 s: %.1f (target %.1f)" % [gs.happiness, gs.happiness_target()])
	ok = ok and gs.happiness > 50.0 and gs.happiness < gs.happiness_target()

	gs.happiness = 90.0
	print("happy: work x%.2f, merry allowed %s, strike allowed %s" % [gs.work_mult(), gs.event_allowed("merry"), gs.event_allowed("strike")])
	ok = ok and gs.morale_bonus() > 0.0 and gs.event_allowed("merry") and not gs.event_allowed("strike")
	gs.happiness = 10.0
	print("unhappy: work x%.2f, merry allowed %s, strike allowed %s" % [gs.work_mult(), gs.event_allowed("merry"), gs.event_allowed("strike")])
	ok = ok and gs.morale_bonus() < 0.0 and not gs.event_allowed("merry") and gs.event_allowed("strike")
	ok = ok and gs.pick_event() in ["strike", "badger"]

	gs.save_game()
	gs.happiness = 50.0
	gs.load_game()
	print("after loading: %.1f" % gs.happiness)
	ok = ok and is_equal_approx(gs.happiness, 10.0)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
