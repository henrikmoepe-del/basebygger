extends SceneTree
## Raises the keep a storey with chosen rooms, and checks that the rooms are
## remembered, count only once the storey stands, and do what they say.
## Run with:
##   godot --headless --path . -s tests/test_rooms.gd -- --save=user://test_save.json

const CastleData = preload("res://scripts/castle_data.gd")

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	gs.part_levels.walls = 2
	gs.part_levels.keep = 1
	gs.keep_picks = []
	for type: String in gs.resources:
		gs.resources[type] = 100000
	gs.castle_changed.emit()
	var ok := true
	var room_before: int = gs.max_peasants()
	var cost_before: Dictionary = gs.part_cost("walls")
	print("first keep: %d bedchambers, %d storerooms, %d armouries" % [gs.room_count("beds"), gs.room_count("store"), gs.room_count("armoury")])
	ok = ok and gs.room_count("beds") == 5 and gs.room_count("store") == 1 and gs.room_count("armoury") == 1
	ok = ok and gs.needs_room_choice("keep") and not gs.needs_room_choice("walls")

	ok = ok and gs.order_part("keep", ["armoury", "store"])
	print("ordered: picks %s, armouries while building %d" % [gs.keep_picks, gs.room_count("armoury")])
	ok = ok and gs.keep_picks == [["armoury", "store"]] and gs.room_count("armoury") == 1
	gs.dev_skip(1.0)
	print("built: keep level %d, armouries %d, storerooms %d, soldiers hit x%.2f" % [
		gs.part_levels.keep, gs.room_count("armoury"), gs.room_count("store"), gs.armoury_mult()])
	ok = ok and gs.part_levels.keep == 2 and gs.room_count("armoury") == 2 and gs.room_count("store") == 2
	ok = ok and is_equal_approx(gs.armoury_mult(), 1.0 + 2 * CastleData.ARMOURY_MIGHT)
	print("walls cost %s before, %s with one more storeroom" % [cost_before, gs.part_cost("walls")])
	ok = ok and gs.part_cost("walls").stone < cost_before.stone

	# A storey ordered without a choice, or with a room that is not on offer, becomes bedchambers.
	ok = ok and gs.order_part("keep", ["kitchen", "lord"])
	gs.dev_skip(1.0)
	print("no valid choice: picks %s, room for %d peasants (was %d)" % [gs.keep_picks, gs.max_peasants(), room_before])
	ok = ok and gs.keep_picks[1] == CastleData.KEEP_DEFAULT_ROOMS
	ok = ok and gs.max_peasants() == room_before + 2 * CastleData.BEDCHAMBER_PEASANTS

	# The rooms survive saving and loading.
	gs.save_game()
	gs.keep_picks = []
	gs.load_game()
	print("after loading: picks %s" % [gs.keep_picks])
	ok = ok and gs.keep_picks == [["armoury", "store"], ["beds", "beds"]]
	# Leave no save behind: the other tests start from a new game.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
