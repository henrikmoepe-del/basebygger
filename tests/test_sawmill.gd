extends SceneTree
## Builds a sawmill, puts two peasants on the saw, and checks that logs turn
## into planks and that later levels ask for planks.
## Run with:
##   godot --headless --path . -s tests/test_sawmill.gd -- --save=user://test_save.json

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await process_frame
		t += root.get_process_delta_time()
		gs.day_time = 10.0


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	Engine.time_scale = 20.0
	gs.part_levels.walls = 2
	gs.peasants += 6
	gs.jobs.build += 3
	gs.resources.wood = 500
	gs.resources.stone = 500
	gs.resources.food = 100000
	gs.castle_changed.emit()
	gs.peasants_changed.emit()
	print("job exists before the sawmill: ", gs.job_unlocked("sawyer"))
	var ordered: bool = gs.order_part("sawmill")
	var t := 0.0
	while gs.part_levels.sawmill == 0 and t < 1200.0:
		await process_frame
		t += root.get_process_delta_time()
		gs.day_time = 10.0
	print("sawmill ordered %s, built in %.1f min, job exists now: %s, room for %d sawyers" % [
		ordered, t / 60.0, gs.job_unlocked("sawyer"), gs.job_limit("sawyer")])
	gs.assign("sawyer", 1)
	gs.assign("sawyer", 1)
	var wood_before: int = gs.resources.wood
	await _wait(180.0)
	print("after 3 min with %d sawyers: planks %d, wood went from %d to %d" % [
		gs.jobs.sawyer, gs.resources.planks, wood_before, gs.resources.wood])
	print("walls level 3 costs ", gs.part_cost("walls"))
	print("court level 1 costs ", gs.part_cost("court"))
	gs.part_levels.court = 1
	print("court level 2 costs ", gs.part_cost("court"))
	print("houses level 1 costs ", gs.part_cost("houses"))
	var ok: bool = gs.part_levels.sawmill == 1 and gs.resources.planks > 0 and gs.part_cost("walls").has("planks") and not gs.part_cost("houses").has("planks")
	print("ALL OK" if ok else "SOMETHING FAILED")
	Engine.time_scale = 1.0
	quit()
