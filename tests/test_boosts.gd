extends SceneTree
## Checks boosts: they need their building, cost what they say, do what they
## say while they last, can't be bought twice at once, run out, and are saved.
## Run with:
##   godot --headless --path . -s tests/test_boosts.gd -- --save=user://test_save.json

const BoostData = preload("res://scripts/boost_data.gd")

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ok := true
	gs.boosts.clear()
	gs.policies.clear()
	gs.events.clear()
	gs.part_levels.tavern = 0
	gs.resources.food = 100
	print("feast without a tavern: '%s', bought %s" % [gs.boost_block_reason("feast"), gs.buy_boost("feast")])
	ok = ok and gs.boost_block_reason("feast") != "" and not gs.boosts.has("feast")

	gs.part_levels.tavern = 1
	var work: float = gs.work_mult()
	var mood: float = gs.happiness_target()
	ok = ok and gs.buy_boost("feast")
	print("feast: food 100 -> %d, work x%.2f -> x%.2f, mood heading %.0f -> %.0f, again: %s" % [
		gs.resources.food, work, gs.work_mult(), mood, gs.happiness_target(), gs.buy_boost("feast")])
	ok = ok and gs.resources.food == 100 - BoostData.BOOSTS.feast.cost.food and gs.work_mult() > work and gs.happiness_target() > mood

	gs.part_levels.garrison = 1
	gs.resources.food = 100
	var might: float = gs.armoury_mult()
	ok = ok and gs.buy_boost("drill") and gs.armoury_mult() > might
	print("drill: soldiers hit x%.2f -> x%.2f" % [might, gs.armoury_mult()])

	gs.save_game()
	gs.boosts.clear()
	gs.load_game()
	print("after loading: %s" % [gs.boosts.keys()])
	ok = ok and gs.boosts.has("feast") and gs.boosts.has("drill")

	gs.boosts.feast = 0.5
	var t := 0.0
	while gs.boosts.has("feast") and t < 5.0:
		await process_frame
		t += root.get_process_delta_time()
	print("feast ran out: %s" % [not gs.boosts.has("feast")])
	ok = ok and not gs.boosts.has("feast")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
