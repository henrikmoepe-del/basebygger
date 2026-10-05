extends SceneTree
## Checks that every peasant is a person with a name and a trait, that the
## people follow hiring, jobs and training, that a peasant keeps who they are
## when their job changes, and that the people are saved.
## Run with:
##   godot --headless --path . -s tests/test_people.gd -- --save=user://test_save.json

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _count(job: String) -> int:
	return gs.people.filter(func(p: Dictionary) -> bool: return p.job == job).size()


func _check(what: String) -> bool:
	var ok: bool = gs.people.size() == gs.peasants
	for job: String in gs.jobs:
		var trained: int = gs.people.filter(func(p: Dictionary) -> bool: return p.job == job and p.trained).size()
		ok = ok and _count(job) == gs.jobs[job] and trained == gs.trained[job]
	print("%s %s: %d people for %d peasants" % ["ok  " if ok else "FAIL", what, gs.people.size(), gs.peasants])
	return ok


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ok := _check("new game")
	for someone: Dictionary in gs.people:
		print("  %s, %s" % [gs.person_title(someone), someone.job if someone.job != "" else "idle"])

	gs.peasants += 3
	gs.peasants_changed.emit()
	ok = _check("three more peasants") and ok
	var workers := current_scene.get_node("Workers")
	await process_frame
	var idle_one: Dictionary = gs.people.filter(func(p: Dictionary) -> bool: return p.job == "")[0]
	ok = gs.assign("hunter", 1) and ok
	ok = _check("one sent to find food") and ok
	await process_frame
	var hunters: Array = workers.get_children().filter(func(w: Node) -> bool: return w.get("job") == "hunter")
	print("the new hunter is %s (was idle: %s)" % [hunters[0].person.name, idle_one.name])
	ok = ok and hunters.size() == 1 and hunters[0].person.id == idle_one.id

	gs.trained.hunter = 1
	gs.peasants_changed.emit()
	ok = _check("the hunter trained") and ok
	gs.peasants -= 1
	gs.peasants_changed.emit()
	ok = _check("one peasant fewer") and ok

	var names: Array = gs.people.map(func(p: Dictionary) -> String: return p.name)
	gs.save_game()
	gs.people.clear()
	gs.load_game()
	var loaded: Array = gs.people.map(func(p: Dictionary) -> String: return p.name)
	print("names saved %s, loaded %s" % [names, loaded])
	ok = ok and names == loaded and _check("after loading")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
