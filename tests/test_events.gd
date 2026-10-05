extends SceneTree
## Starts the badger event, and checks that it slows the food site, that
## clicking it away pays its reward, that it is saved, and that it ends by
## itself when its time runs out.
## Run with:
##   godot --headless --path . -s tests/test_events.gd -- --save=user://test_save.json

const EventData = preload("res://scripts/event_data.gd")

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ok := true
	gs.day = 1
	gs.events.clear()
	print("day 1, an event that may start: '%s'" % gs.pick_event())
	ok = ok and gs.pick_event() == ""
	gs.day = 5
	ok = ok and gs.pick_event() == "badger"

	var rate_before: float = gs.site_rate("food")
	ok = ok and gs.start_event("badger") and not gs.start_event("badger")
	print("food site: %.2f a second, %.2f with a badger" % [rate_before, gs.site_rate("food")])
	ok = ok and gs.site_rate("food") < rate_before

	var food: int = gs.resources.food
	gs.end_event("badger", "clicked")
	print("clicked away: food %d -> %d, events %s" % [food, gs.resources.food, gs.events])
	ok = ok and gs.resources.food == food + EventData.EVENTS.badger.reward.food and gs.events.is_empty()
	ok = ok and is_equal_approx(gs.site_rate("food"), rate_before)

	# Saved and loaded with the time it has left.
	gs.start_event("badger")
	gs.events.badger = 30.0
	gs.save_game()
	gs.events.clear()
	gs.load_game()
	print("after loading: %s" % [gs.events])
	var last: Dictionary = gs.messages.back()
	print("last message in the log: day %d, %s" % [last.day, last.text])
	ok = ok and last.text == EventData.EVENTS.badger.start_text
	ok = ok and gs.events.has("badger") and is_equal_approx(gs.events.badger, 30.0)

	# It runs out by itself (the time is spent in the game's own clock).
	var t := 0.0
	while gs.events.has("badger") and t < 60.0:
		await process_frame
		t += root.get_process_delta_time()
		Engine.time_scale = 10.0
	Engine.time_scale = 1.0
	print("ran out by itself: %s" % [not gs.events.has("badger")])
	ok = ok and not gs.events.has("badger")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
