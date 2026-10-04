extends SceneTree

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await process_frame
		t += root.get_process_delta_time()


func _build(part: String, limit: float) -> bool:
	for type in gs.resources:
		gs.resources[type] = 100000
	if not gs.order_part(part):
		print("FAIL could not order ", part, ": ", gs.part_block_reason(part))
		return false
	var level: int = gs.part_levels[part]
	var pieces: int = gs.job_size()
	var t := 0.0
	var max_up := 0.0
	var workers := current_scene.get_node("Workers")
	var castle := current_scene.get_node("Castle")
	var air := 0
	while gs.part_levels[part] == level and t < limit:
		await process_frame
		t += root.get_process_delta_time()
		# Keep it daytime, so the timing is of the work alone.
		gs.day_time = 10.0
		var flats: Array = castle.floors()
		for w in workers.get_children():
			if w.get("job") == "build":
				max_up = minf(max_up, w.position.y)
				if w.position.y < -0.5 and not _supported(flats, w.position):
					air += 1
					if air <= 3:
						print("     in the air: ", w.position, " state ", w._state, " placed ", gs.job_placed, "/", gs.job_size())
	if air > 0:
		print("     %d frames with a builder in the air" % air)
	var ok: bool = gs.part_levels[part] == level + 1
	print("%s %s -> level %d in %.1f min game time, %d pieces, builders climbed to y=%.0f" % [
		"ok  " if ok else "FAIL", part, gs.part_levels[part], t / 60.0, pieces, max_up])
	if not ok:
		print("     stuck at claimed %d hauled %d formed %d lifted %d taken %d placed %d" % [
			gs.job_claimed, gs.job_hauled, gs.job_formed, gs.job_lifted, gs.job_taken, gs.job_placed])
		for w in workers.get_children():
			if w.get("job") == "build":
				print("     builder state %d at %s" % [w._state, w.position])
	return ok


func _supported(flats: Array, at: Vector2) -> bool:
	for flat in flats:
		if at.x >= flat.x0 - 2.0 and at.x <= flat.x1 + 2.0 and absf(at.y - flat.y) <= 16.0:
			return true
		for stair in flat.stairs:
			if absf(stair - at.x) < 0.5 and at.y >= flat.y - 0.5:
				return true
	return false


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	Engine.time_scale = 30.0
	var all_ok := true
	# Gatherers alone for a while: do the stores fill?
	await _wait(120.0)
	print("after 2 min of gathering: ", gs.resources)
	gs.peasants += 2
	gs.jobs.build += 2
	gs.peasants_changed.emit()
	all_ok = await _build("walls", 6000.0) and all_ok
	gs.peasants += 12
	gs.jobs.build += 5
	gs.peasants_changed.emit()
	for part in ["towers", "keep", "gate", "court", "garrison", "watchtower", "houses", "walls", "towers", "towers", "keep"]:
		all_ok = await _build(part, 6000.0) and all_ok
	gs.jobs.soldier = 2
	gs.peasants_changed.emit()
	await _wait(40.0)
	var workers := current_scene.get_node("Workers")
	for w in workers.get_children():
		if w.get("job") == "soldier":
			print("  soldier at (%.0f, %.0f) visible=%s z=%d" % [w.position.x, w.position.y, w.visible, w.z_index])
	# Night: everyone who sleeps should end up inside.
	gs.day_time = gs.DAY_LENGTH * gs.night_start() + 1.0
	await _wait(28.0)
	var awake := 0
	for w in workers.get_children():
		if w.has_method("_sleeps") and w._sleeps() and w.visible:
			awake += 1
			print("  still out at night: ", w.get("job"), " ", w.position)
	print("night: is_night=%s, %d sleepers still outside" % [gs.is_night(), awake])
	print("ALL OK" if all_ok and awake == 0 else "SOMETHING FAILED")
	Engine.time_scale = 1.0
	quit()
