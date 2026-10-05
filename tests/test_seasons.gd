extends SceneTree
## Walks through a year: checks the season of each day, that a new season is
## announced, that seasons change what grows, and that season events only
## come in their season.
## Run with:
##   godot --headless --path . -s tests/test_seasons.gd -- --save=user://test_save.json

const SeasonData = preload("res://scripts/season_data.gd")

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ok := true
	gs.events.clear()
	gs.policies.clear()
	var days := SeasonData.DAYS_PER_SEASON
	var seen := []
	for day in [1, days, days + 1, 2 * days + 1, 3 * days + 1, 4 * days + 1]:
		gs.day = day
		seen.append("%d:%s" % [day, gs.season().id])
	print("seasons by day: %s" % [seen])
	ok = ok and seen == ["1:spring", "%d:spring" % days, "%d:summer" % (days + 1), "%d:autumn" % (2 * days + 1),
		"%d:winter" % (3 * days + 1), "%d:spring" % (4 * days + 1)]

	gs.day = 2 * days + 1
	var autumn_food: float = gs.site_rate("food")
	gs.day = 3 * days + 1
	print("food grows %.2f a second in autumn, %.2f in winter; harvest allowed in winter: %s, cold snap: %s" % [
		autumn_food, gs.site_rate("food"), gs.event_allowed("harvest"), gs.event_allowed("cold_snap")])
	ok = ok and autumn_food > gs.site_rate("food") and not gs.event_allowed("harvest") and gs.event_allowed("cold_snap")

	# The last day of winter turns into spring, and it is announced.
	gs.day = 4 * days
	gs.day_time = gs.DAY_LENGTH - 0.01
	var heard := []
	gs.announced.connect(func(text: String) -> void: heard.append(text))
	await process_frame
	await process_frame
	print("day %d, %s; heard %s" % [gs.day, gs.season().id, heard])
	ok = ok and gs.season().id == "spring" and heard.any(func(text: String) -> bool: return text.begins_with("Spring has come"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
