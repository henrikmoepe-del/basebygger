extends SceneTree
## Checks the stores' limits: deliveries stop at the limit, a part whose
## materials do not fit cannot be ordered, and the stockhouse raises the limit.
## Run with:
##   godot --headless --path . -s tests/test_storage.gd -- --save=user://test_save.json

const CastleData = preload("res://scripts/castle_data.gd")

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ok := true
	gs.part_levels.stockhouse = 0
	gs.resources.wood = 90
	gs.add_income("wood", 30)
	print("stores hold %d; wood 90 + 30 delivered = %d, full: %s" % [gs.store_capacity(), gs.resources.wood, gs.store_full("wood")])
	ok = ok and gs.store_capacity() == CastleData.STORE_BASE and gs.resources.wood == 100 and gs.store_full("wood")

	gs.part_levels.tavern = 5
	print("tavern level 6 costs %s: %s" % [gs.part_cost("tavern"), gs.part_block_reason("tavern")])
	ok = ok and gs.part_block_reason("tavern").begins_with("Needs a bigger stockhouse")

	gs.part_levels.stockhouse = 6
	gs.add_income("wood", 30)
	print("with stockhouse level 6, stores hold %d, wood %d, tavern: '%s'" % [gs.store_capacity(), gs.resources.wood, gs.part_block_reason("tavern")])
	ok = ok and gs.store_capacity() > 1000 and gs.resources.wood == 130 and gs.part_block_reason("tavern") == ""

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
