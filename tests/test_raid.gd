extends SceneTree
## Runs two raids without a window: one against a defended castle, which
## should be beaten in the world, and one against an undefended castle, which
## should reach the castle and start the 3D fight for the gate.
## Run with:
##   godot --headless --path . -s tests/test_raid.gd -- --save=user://test_save.json

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _raid(limit: float) -> float:
	gs.day = gs.next_raid_day()
	var t := 0.0
	var faced: int = gs.raids_faced
	while gs.raids_faced == faced and t < limit:
		await process_frame
		t += root.get_process_delta_time()
		gs.day_time = 10.0
	return t


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	Engine.time_scale = 10.0
	for part in ["walls", "towers", "garrison", "palisade", "watchtower"]:
		gs.part_levels[part] = 2
	gs.resources.food = 100000
	gs.peasants += 6
	gs.jobs.soldier = 6
	gs.castle_changed.emit()
	gs.peasants_changed.emit()
	await process_frame
	# Let the soldiers reach their peacetime posts first.
	var t := 0.0
	while t < 60.0:
		await process_frame
		t += root.get_process_delta_time()
		gs.day_time = 10.0

	var size: int = gs.raid_size()
	var took: float = await _raid(600.0)
	var workers := current_scene.get_node("Workers")
	for w in workers.get_children():
		if w.get("job") == "soldier":
			print("  soldier %s at (%.0f, %.0f)" % ["spearman" if w.melee else "archer", w.position.x, w.position.y])
	var beaten: bool = gs.raids_won == 1 and not gs.siege_active
	print("%s defended castle: %d raiders, over in %.0f s, raids won %d, siege %s" % [
		"ok  " if beaten else "FAIL", size, took, gs.raids_won, gs.siege_active])

	# Now with nobody to defend it.
	gs.jobs.soldier = 0
	gs.part_levels.palisade = 0
	gs.castle_changed.emit()
	gs.peasants_changed.emit()
	await process_frame
	took = await _raid(600.0)
	# (The 3D fight for the gate is switched off: the raid just ends, unbeaten.)
	var reached: bool = gs.raids_faced == 2 and gs.raids_won == 1 and not gs.raid_incoming
	print("%s undefended castle: reached the castle after %.0f s, raids faced %d, won %d" % [
		"ok  " if reached else "FAIL", took, gs.raids_faced, gs.raids_won])
	print("ALL OK" if beaten and reached else "SOMETHING FAILED")
	Engine.time_scale = 1.0
	quit()
