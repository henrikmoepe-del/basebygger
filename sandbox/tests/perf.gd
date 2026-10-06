extends SceneTree
## Times the sandbox with more peasants: how long a frame of the world takes.
##   godot --headless --fixed-fps 60 --path . -s sandbox/tests/perf.gd -- --peasants=40

var _world: Node2D
var _count := 40


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--peasants="):
			_count = int(arg.substr(11))
	_world = load("res://sandbox/sandbox.tscn").instantiate()
	_world.auto_raids = false
	root.add_child(_world)
	_run.call_deferred()


func _run() -> void:
	var w := _world
	var jobs := ["builder", "woodcutter", "miner", "forager", "hunter", "crafter", "hauler", "guard"]
	var i: int = w.peasants.size()
	while w.peasants.size() < _count:
		var p: Node2D = w._add(w.Peasant, Vector2(randf_range(-200, 300), randf_range(10, 70)))
		p.setup("P%d" % i, jobs[i % jobs.size()])
		w.peasants.append(p)
		i += 1
	w.stockyard.put("wood", 200)
	w.stockyard.put("stone", 200)
	Engine.time_scale = 4.0
	for f in 120:
		await process_frame
	var start := Time.get_ticks_usec()
	var frames := 600
	for f in frames:
		await process_frame
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / frames
	print("%d peasants: %.2f ms a frame (%.0f fps headless)" % [w.peasants.size(), ms, 1000.0 / ms])
	quit()
