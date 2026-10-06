extends SceneTree
## Takes real screenshots of the sandbox (opens a window; in a container with
## no screen, run it under xvfb-run with --rendering-driver opengl3).
##   godot --path . -s sandbox/tests/shots.gd -- --plan=<name> --out=<folder>
## Each plan runs the map for a while, does what it says, and saves pictures.

const PLANS := {
	# The map as it starts, then after a minute of free will.
	"start": {"steps": [[0.5, "shot"], [60.0, "shot"]]},
	# Three builders ordered to the Tower while the rest choose for themselves.
	"orders": {"steps": [[3.0, "select_builders"], [0.2, "order_tower"], [0.5, "shot"], [20.0, "shot"]]},
	# A raid: the guard fights, the others flee; then two are ordered to help.
	"raid": {"steps": [[5.0, "raid"], [9.0, "shot"], [0.1, "select_two"], [0.1, "order_raider"], [3.0, "shot"]]},
	# A fire in the stockyard: peasants run buckets from the well.
	"fire": {"steps": [[5.0, "fire"], [6.0, "shot"]]},
	# Box selection and a hold-here order.
	# The Work overview.
	"work": {"steps": [[1.0, "work"], [0.3, "shot"]]},
	# Placing a new building, and a picked site marked urgent.
	"build": {"steps": [[1.0, "place"], [0.2, "shot"], [0.1, "placed"], [15.0, "shot"]]},
	# Queued orders (Shift + right-click): numbered dotted lines.
	"queue": {"steps": [[1.0, "queue"], [1.5, "shot"]]},
	# Three builders drafted and sent to meet a raid.
	"draft": {"steps": [[2.0, "draft"], [0.1, "raid"], [11.0, "shot"], [4.0, "shot"]]},
	# Two peasants go down; others carry them to the beds of the finished Hut.
	"rescue": {"steps": [[1.0, "hurt"], [5.0, "shot"], [10.0, "shot"]]},
	"box": {"steps": [[2.0, "box"], [0.1, "goto"], [0.4, "shot"]]},
}

var _world: Node2D
var _out := "user://sandbox_shots"
var _plan := "start"
var _n := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--plan="):
			_plan = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(_out)
	_world = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(_world)
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 4.0
	for step in PLANS[_plan].steps:
		await create_timer(step[0] / 4.0, true, false, true).timeout
		await _do(step[1])
	quit()


func _do(what: String) -> void:
	var w := _world
	match what:
		"shot":
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var path := "%s/%s_%d.png" % [_out, _plan, _n]
			img.save_png(path)
			print("saved ", path)
			_n += 1
		"select_builders":
			w.select(w.peasants.filter(func(p): return p.job == "builder"))
		"order_tower":
			w.give_order(w.sites[2].position + Vector2(0, -10))
		"raid":
			w.start_raid()
			w.camera.position = Vector2(-150, -20)
		"select_two":
			w.select([w.peasants[0], w.peasants[5]])
		"order_raider":
			if not w.raiders.is_empty():
				w.give_order(w.raiders[0].position + Vector2(0, -8))
		"fire":
			w.start_fire(w.stockyard)
			w.camera.position = Vector2(200, -20)
		"box":
			var inside: Array = []
			for p in w.peasants:
				if p.position.x < 200:
					inside.append(p)
			w.select(inside)
		"goto":
			w.give_order(Vector2(0, 40))
		"place":
			w.placing = "hut"
			w.camera.position = Vector2(330, -20)
			Input.warp_mouse(Vector2(520, 190) * 2.0)
		"placed":
			var site: Node2D = w.add_site("hut", Vector2(380, 4))
			w.placing = ""
			w.pick_site(site)
			site.urgent = true
		"queue":
			w.camera.position = Vector2(330, -20)
			var h: Node2D = w.peasants[5]
			w.select([h])
			w.give_order(w.trees[2].position + Vector2(0, -4))
			w.give_order(w.rocks[1].position + Vector2(0, -4), true)
			w.give_order(Vector2(260, 60), true)
		"draft":
			w.select(w.peasants.filter(func(p): return p.job == "builder"))
			w.toggle_draft_selected()
			w.give_order(Vector2(-220, 40))
		"hurt":
			var hut: Node2D = w.sites[0]
			while not hut.done():
				hut.add_block(hut.next_material())
			w.peasants[3].position = Vector2(-120, 50)
			w.peasants[4].position = Vector2(-100, 30)
			w.peasants[3].damage(100.0)
			w.peasants[4].damage(100.0)
			w.camera.position = Vector2(-60, -20)
		"work":
			w.peasants[3].cycle_prio("haul")
			w.hud.toggle_work()
