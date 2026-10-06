extends SceneTree
## Runs the sandbox for a long time with no player, now and then a raid or a
## fire, and prints what everyone is doing every game hour, plus warnings for
## anyone who stands idle a long time while there is work for them.
##   godot --headless --fixed-fps 60 --path . -s sandbox/tests/soak.gd -- --days=3

const SPEED := 8.0

var _world: Node2D
var _days := 3.0
var _idle := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			_days = float(arg.substr(7))
	_world = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(_world)
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = SPEED
	var w := _world
	var seconds := _days * 240.0
	var hour := 240.0 / 24.0
	var t := 0.0
	var next_report := 0.0
	var warned := {}
	while t < seconds:
		await process_frame
		var dt := SPEED / 60.0
		t += dt
		if is_equal_approx(fmod(t, 300.0), 0.0) or (fmod(t, 300.0) < dt and t > 1.0):
			# Raids come on their timetable; now and then a fire as well.
			if randf() < 0.5:
				w.start_fire()
		for p in w.peasants:
			var k: String = p.task.get("kind", "")
			if k == "idle" and not w.is_night() and p.job != "guard":
				_idle[p.person_name] = _idle.get(p.person_name, 0.0) + dt
				if _idle[p.person_name] > 30.0 and not warned.has(p.person_name):
					warned[p.person_name] = true
					print("WARN %s idle 30 s by day, job %s, stock %s" % [p.person_name, p.job, w.stockyard.stock])
			else:
				_idle[p.person_name] = 0.0
				warned.erase(p.person_name)
		if t >= next_report:
			next_report += hour * 3.0
			var line := "Day %d %02d:00 stock %s sites %s items %d |" % [w.day(), int(w.hour()), w.stockyard.stock, w.sites.map(func(s): return "%s %d/%d" % [s.title, s.placed, s.mats.size()]), w.items.size()]
			for p in w.peasants:
				line += " %s:%s%s" % [p.person_name.substr(0, 3), p.task.get("kind", "-"), "(down)" if p.downed else ""]
			print(line)
	print("raids: %d, deer shot: %d" % [w.raids, w.deer_shot])
	if not w.fires.is_empty():
		print("WARN fires still burning: ", w.fires.size())
	var counts := {}
	for it in w.items:
		var key := "%s at x~%d" % [it.res, int(it.position.x / 50.0) * 50]
		counts[key] = counts.get(key, 0) + 1
	print("ITEMS ", counts)
	for it in w.items.slice(0, 5):
		print("  item ", it.res, " ", it.position, " workers=", it.workers.map(func(p): return p.person_name))
	quit()
