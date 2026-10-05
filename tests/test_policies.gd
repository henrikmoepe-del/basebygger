extends SceneTree
## Turns policies on and off, and checks that they change how much food is
## eaten and how fast everyone works, and that they are saved.
## Run with:
##   godot --headless --path . -s tests/test_policies.gd -- --save=user://test_save.json

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ok := true
	gs.policies.clear()
	gs.peasants = 20
	var food: int = gs.food_needed()
	var work: float = gs.work_mult()

	gs.toggle_policy("rations")
	print("smaller rations: food %d -> %d, work x%.2f -> x%.2f" % [food, gs.food_needed(), work, gs.work_mult()])
	ok = ok and gs.food_needed() < food and gs.work_mult() < work

	gs.toggle_policy("rations")
	gs.toggle_policy("long_days")
	print("long days: food %d -> %d, work x%.2f -> x%.2f" % [food, gs.food_needed(), work, gs.work_mult()])
	ok = ok and gs.food_needed() > food and gs.work_mult() > work

	gs.toggle_policy("rations")
	gs.toggle_policy("no_such_policy")
	gs.save_game()
	gs.policies.clear()
	gs.load_game()
	print("after loading: %s" % [gs.policies])
	ok = ok and gs.policies == ["long_days", "rations"]

	gs.toggle_policy("long_days")
	gs.toggle_policy("rations")
	print("all off again: food %d, work x%.2f" % [gs.food_needed(), gs.work_mult()])
	ok = ok and gs.food_needed() == food and is_equal_approx(gs.work_mult(), work)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
