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
	# Day 5: any chance event allowed then (the badger, a drought, a trader...).
	var picked: String = gs.pick_event()
	print("day 5, picked: '%s'" % picked)
	ok = ok and picked != "" and gs.event_allowed(picked) and gs.EventData.EVENTS[picked].has("weight")

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

	# A trader: no trade without the price, a trade with it.
	gs.part_levels.stockhouse = 5
	gs.events.clear()
	var started: bool = gs.start_event("trader")
	ok = ok and started
	var offer: Dictionary = gs.event_offer("trader")
	for type: String in offer.give:
		gs.resources[type] = 0
	var got: String = offer.get.keys()[0]
	var before: int = gs.resources[got]
	print("trader offers %s for %s; clicked while poor: %s" % [offer.give, offer.get, gs.click_event("trader")])
	ok = ok and gs.events.has("trader")
	for type: String in offer.give:
		gs.resources[type] = offer.give[type]
	ok = ok and gs.click_event("trader") and not gs.events.has("trader")
	print("clicked with the price: %s %d -> %d" % [got, before, gs.resources[got]])
	ok = ok and gs.resources[got] == before + offer.get[got]

	# A fire that burns out takes a quarter of the wood; one clicked out takes nothing.
	gs.resources.wood = 100
	gs.start_event("fire")
	gs.end_event("fire", "ran_out")
	print("fire burned out: wood 100 -> %d" % gs.resources.wood)
	ok = ok and gs.resources.wood == 75
	gs.start_event("fire")
	ok = ok and gs.click_event("fire") and gs.resources.wood == 75

	# An accident only while building; it hurts a builder until it ends.
	print("accident allowed with nothing being built: %s" % gs.event_allowed("accident"))
	ok = ok and not gs.event_allowed("accident")
	gs.job_part = "walls"
	var builder: Dictionary = gs.people.filter(func(p: Dictionary) -> bool: return p.job == "build")[0]
	ok = ok and gs.event_allowed("accident") and gs.start_event("accident")
	var hurt: Dictionary = gs.person(int(gs.event_info.accident.person))
	print("%s is hurt: %s" % [gs.person_title(hurt), hurt.hurt])
	ok = ok and hurt.job == "build" and hurt.hurt
	gs.end_event("accident", "ran_out")
	print("after it: hurt %s, last message: %s" % [hurt.hurt, gs.messages.back().text])
	ok = ok and not hurt.hurt and gs.messages.back().text.ends_with("is well again")
	gs.job_part = ""

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
