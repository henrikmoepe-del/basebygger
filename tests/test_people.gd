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
	var ok: bool = gs.grown_ups().size() == gs.peasants
	for job: String in gs.jobs:
		var trained: int = gs.people.filter(func(p: Dictionary) -> bool: return p.job == job and p.trained).size()
		ok = ok and _count(job) == gs.jobs[job] and trained == gs.trained[job]
	print("%s %s: %d grown-ups for %d peasants" % ["ok  " if ok else "FAIL", what, gs.grown_ups().size(), gs.peasants])
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

	# Children: none without the policy; with it, couples have them.
	gs.policies.clear()
	gs.part_levels.houses = 6
	gs._births()
	ok = ok and gs.children().is_empty()
	gs.toggle_policy("children")
	for i in 30:
		gs._births()
	var young: Array = gs.children()
	print("with the policy, after 30 dawns' chances: %d children" % young.size())
	ok = ok and not young.is_empty() and _check("children are not peasants")
	var child: Dictionary = young[0]
	var parent: Dictionary = gs.person(int(child.parents[0]))
	print("%s, child of %s (raising: %s)" % [gs.person_title(child), parent.name, parent.raising])
	ok = ok and parent.raising
	var peasants: int = gs.peasants
	gs.toggle_policy("children")
	gs.day += gs.PeopleData.CHILD_DAYS
	gs._grow_up()
	print("after %d days: %d children left, peasants %d -> %d, %s is a child: %s" % [
		gs.PeopleData.CHILD_DAYS, gs.children().size(), peasants, gs.peasants, child.name, child.child])
	ok = ok and gs.children().is_empty() and gs.peasants == peasants + young.size() and not child.child
	ok = ok and not parent.raising and _check("the children grown up")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("ALL OK" if ok else "SOMETHING FAILED")
	quit()
