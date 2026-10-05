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
	gs.part_levels.stockhouse = 10
	gs.keep_picks = []
	for type: String in gs.resources:
		gs.resources[type] = 100000
	gs.castle_changed.emit()
	var ok := true
	var room_before: int = gs.max_peasants()
	var cost_before: Dictionary = gs.part_cost("walls")
	print("first keep: %d bedchambers, %d storerooms, %d armouries" % [gs.room_count("beds"), gs.room_count("store"), gs.room_count("armoury")])
	ok = ok and gs.room_count("beds") == 1 and gs.room_count("store") == 1 and gs.room_count("armoury") == 1
	ok = ok and gs.needs_room_choice("keep") and not gs.needs_room_choice("walls")

	ok = ok and gs.order_part("keep", ["armoury", "store"])
	print("ordered: picks %s, armouries while building %d" % [gs.keep_picks, gs.room_count("armoury")])
	ok = ok and gs.keep_picks == [["armoury", "store"]] and gs.room_count("armoury") == 1
	gs.dev_skip(1.0)
	print("built: keep level %d, armouries %d, storerooms %d, soldiers hit x%.2f" % [
		gs.part_levels.keep, gs.room_count("armoury"), gs.room_count("store"), gs.armoury_mult()])
	ok = ok and gs.part_levels.keep == 2 and gs.room_count("armoury") == 2 and gs.room_count("store") == 2
	ok = ok and is_equal_approx(gs.armoury_mult(), 1.0 + 2 * CastleData.ROOMS.armoury.effects.soldier_might)
	print("walls cost %s before, %s with one more storeroom" % [cost_before, gs.part_cost("walls")])
	ok = ok and gs.part_cost("walls").stone < cost_before.stone

	# A storey ordered without a choice, or with a room that is not on offer, becomes bedchambers.
	ok = ok and gs.order_part("keep", ["kitchen", "lord"])
	gs.dev_skip(1.0)
	print("no valid choice: picks %s, room for %d peasants (was %d)" % [gs.keep_picks, gs.max_peasants(), room_before])
	ok = ok and gs.keep_picks[1] == CastleData.KEEP_DEFAULT_ROOMS
	ok = ok and gs.max_peasants() == room_before + 2 * int(CastleData.ROOMS.beds.effects.peasant_room)

	# The keep's summary adds the rooms up.
	var summary: PackedStringArray = gs.keep_summary()
	print("summary: %s" % [summary])
	ok = ok and "Bedchamber x3: room for 6 more peasants" in summary
	ok = ok and "Armoury x2: soldiers hit 20% harder; -2 happiness" in summary
	ok = ok and "Storeroom x2: building costs 6% less; raids 4% bigger" in summary

	# Drawbacks: the rooms' happiness counts, and raids grow with storerooms.
	var parts: Array = gs.happiness_parts().filter(func(part: Array) -> bool: return part[0] == "Rooms of the keep")
	print("happiness from the rooms: %s" % [parts])
	ok = ok and parts.size() == 1 and is_equal_approx(parts[0][1], -2.0)


	# The rooms survive saving and loading.
	gs.save_game()
	gs.keep_picks = []
	gs.load_game()
	print("after loading: picks %s" % [gs.keep_picks])
	ok = ok and gs.keep_picks == [["armoury", "store"], ["beds", "beds"]]
	# Two more storerooms make the raids bigger.
	var raid_before: float = gs.effect_total("raid_size")
	ok = ok and gs.order_part("keep", ["store", "store"])
	gs.dev_skip(1.0)
	print("raids grow by %d%% before two more storerooms, %d%% after" % [roundi(raid_before * 100), roundi(gs.effect_total("raid_size") * 100)])
	ok = ok and gs.effect_total("raid_size") > raid_before

	# Leave no save behind: the other tests start from a new game.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
