extends SceneTree
## Plays the sandbox with real mouse and key events in a window, as a player
## would: click to select, Shift-click, drag a box, right-click to order,
## G, Space, R, Esc. In the cloud run it under xvfb:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s sandbox/tests/test_input.gd

var _world: Node2D
var _fails := 0


func _initialize() -> void:
	_world = load("res://sandbox/sandbox.tscn").instantiate()
	_world.auto_raids = false
	_world.calm = true
	root.add_child(_world)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


## The window pixel of a world point (the window is twice the 640x360 view).
func _screen(at: Vector2) -> Vector2:
	var cam: Camera2D = _world.camera
	return ((at - cam.position) * cam.zoom + Vector2(320, 180)) * 2.0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _move(at: Vector2) -> void:
	var p := _screen(at)
	Input.warp_mouse(p)
	var ev := InputEventMouseMotion.new()
	ev.position = p / 2.0
	ev.global_position = p / 2.0
	root.push_input(ev)
	await _frames(2)


func _button(at: Vector2, button: MouseButton, pressed: bool, shift := false) -> void:
	await _move(at)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.shift_pressed = shift
	ev.position = _screen(at) / 2.0
	ev.global_position = ev.position
	root.push_input(ev)
	await _frames(2)


func _click(at: Vector2, button := MOUSE_BUTTON_LEFT, shift := false) -> void:
	await _button(at, button, true, shift)
	await _button(at, button, false, shift)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)
		await _frames(2)


func _run() -> void:
	await _frames(10)
	var w := _world
	get_root().get_tree().paused = false
	# Freeze the world so peasants stand still where we click them.
	w.toggle_pause()
	var a: Node2D = w.peasants[0]
	var b: Node2D = w.peasants[1]
	var body := Vector2(0, -8)

	await _click(a.position + body)
	_check(w.selected == [a], "a left-click on a peasant selects them")
	await _click(b.position + body, MOUSE_BUTTON_LEFT, true)
	_check(w.selected.size() == 2 and w.selected.has(b), "Shift-click adds another")
	await _click(b.position + body, MOUSE_BUTTON_LEFT, true)
	_check(w.selected == [a], "Shift-click again takes them off")

	await _key(KEY_ESCAPE)
	_check(w.selected.is_empty(), "Esc deselects")

	# Double-click: everyone with the same job.
	await _move(a.position + body)
	var dbl := InputEventMouseButton.new()
	dbl.button_index = MOUSE_BUTTON_LEFT
	dbl.pressed = true
	dbl.double_click = true
	dbl.position = _screen(a.position + body) / 2.0
	dbl.global_position = dbl.position
	root.push_input(dbl)
	await _frames(2)
	var same: int = w.peasants.filter(func(p): return p.job == a.job).size()
	_check(w.selected.size() == same, "a double-click selects everyone with the same job (%d)" % same)

	# Ctrl+A: everyone.
	var ctrl_a := InputEventKey.new()
	ctrl_a.keycode = KEY_A
	ctrl_a.ctrl_pressed = true
	ctrl_a.pressed = true
	root.push_input(ctrl_a)
	await _frames(2)
	_check(w.selected.size() == w.peasants.size(), "Ctrl+A selects everyone")
	await _key(KEY_ESCAPE)

	# A box around everyone near the stockyard.
	var near: Array = w.peasants.filter(func(p): return absf(p.position.x - 190.0) < 60.0)
	await _button(Vector2(120, 2), MOUSE_BUTTON_LEFT, true)
	await _move(Vector2(250, 79))
	await _button(Vector2(250, 79), MOUSE_BUTTON_LEFT, false)
	_check(w.selected.size() >= near.size() and near.size() > 0, "dragging a box selects those inside (%d of %d)" % [w.selected.size(), near.size()])

	# Right-click a tree: an order to chop it.
	await _click(a.position + body)
	var tree: Node2D = w.trees.filter(func(t): return t.is_open())[0]
	w.camera.position.x = tree.position.x
	await _frames(2)
	await _click(tree.position + Vector2(0, -26), MOUSE_BUTTON_RIGHT)
	_check(a.order.get("kind", "") == "chop" and a.order.get("target") == tree, "right-clicking a tree orders the selected to chop it")

	await _key(KEY_R)
	_check(a.order.is_empty(), "R releases the order")

	await _key(KEY_G)
	_check(a.drafted, "G drafts the selected")
	await _key(KEY_G)
	_check(not a.drafted, "G again undrafts")

	await _key(KEY_SPACE)
	_check(not paused, "Space unpauses")
	await _key(KEY_SPACE)
	_check(paused, "Space pauses")

	await _key(KEY_W)
	_check(w.hud._work.visible, "W opens the Work overview")
	await _key(KEY_W)
	await _key(KEY_B)
	_check(w.hud._build.visible, "B opens the Build menu")
	await _key(KEY_B)

	paused = false
	print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
