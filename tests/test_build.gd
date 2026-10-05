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
				if w.visible and w.position.y < -0.5 and not _supported(flats, w.position):
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
	# "-- --from=keep:6,walls:3 --parts=keep,keep" builds just those, from those levels.
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="):
			for pair in arg.trim_prefix("--from=").split(","):
				gs.part_levels[pair.get_slice(":", 0)] = int(pair.get_slice(":", 1))
			gs.castle_changed.emit()
		elif arg.begins_with("--parts="):
			only = arg.trim_prefix("--parts=")
	if only != "":
		gs.peasants += 12
		gs.jobs.build += 5
		gs.peasants_changed.emit()
		for part in only.split(","):
			all_ok = await _build(part, 6000.0) and all_ok
		print("ALL OK" if all_ok else "SOMETHING FAILED")
		Engine.time_scale = 1.0
		quit()
		return
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
	# Leisure: nobody without work should stand about doing nothing.
	gs.part_levels.tavern = 1
	gs.day_time = 10.0
	var seen := {}
	var still := {}
	var longest := 0.0
	var t := 0.0
	while t < 240.0:
		await process_frame
		var step := root.get_process_delta_time()
		t += step
		gs.day_time = 10.0
		for w in workers.get_children():
			if not w.has_method("at_leisure") or not w.at_leisure():
				continue
			seen[w._leisure] = seen.get(w._leisure, 0) + 1
			var busy: bool = w._leisure in [2, 3, 4] or not w.visible
			var last: Array = still.get(w, [w.position, 0.0])
			if busy or not w.position.is_equal_approx(last[0]):
				still[w] = [w.position, 0.0]
			else:
				still[w] = [last[0], last[1] + step]
				longest = maxf(longest, last[1] + step)
	print("leisure frames by kind (0 none, 1 stroll, 2 visit, 3 host, 4 tavern): ", seen)
	print("longest anyone at leisure stood doing nothing: %.1f s" % longest)
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
