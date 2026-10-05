extends SceneTree
## Puts two bakers in a bakery and checks that they take grain and firewood
## from the stockyard and bring back more food than they took. The sawmill
## runs on the same workshop code (see test_sawmill.gd).
## Run with:
##   godot --headless --path . -s tests/test_workshops.gd -- --save=user://test_save.json

const WorkshopData = preload("res://scripts/workshop_data.gd")

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ok := true
	gs.no_nights = true
	print("bakers before the bakery: %s" % gs.job_unlocked("baker"))
	ok = ok and not gs.job_unlocked("baker")
	gs.part_levels.bakery = 1
	gs.part_levels.stockhouse = 3
	gs.castle_changed.emit()
	gs.resources.food = 60
	gs.resources.wood = 60
	# Nobody else at work, so only the bakers move food and wood.
	gs.jobs = gs.NO_JOBS.duplicate()
	gs.trained = gs.NO_JOBS.duplicate()
	gs.peasants += 3
	gs.peasants_changed.emit()
	ok = ok and gs.assign("baker", 1) and gs.assign("baker", 1) and not gs.assign("baker", 1)
	print("room for %d bakers, %d at work" % [gs.job_limit("baker"), gs.jobs.baker])
	var baked := [0]
	gs.income_delivered.connect(func(type: String, amount: int) -> void:
		if type == "food":
			baked[0] += amount)
	Engine.time_scale = 10.0
	var t := 0.0
	while t < 120.0:
		await process_frame
		t += root.get_process_delta_time()
		gs.day_time = 10.0
	Engine.time_scale = 1.0
	var recipe: Dictionary = WorkshopData.WORKSHOPS.baker
	var batches: int = baked[0] / recipe.makes
	print("in 2 min: %d food baked (%d batches), food 60 -> %d, wood 60 -> %d" % [baked[0], batches, gs.resources.food, gs.resources.wood])
	ok = ok and batches > 0 and gs.resources.wood <= 60 - batches * recipe.inputs.wood
	ok = ok and gs.resources.food > 60

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
