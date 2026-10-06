extends CanvasLayer
## The sandbox's interface: resources and test buttons on top, a bar with
## every peasant (click to select, like RimWorld's colonist bar), and a
## panel for the selected: what each is doing, their job, their work
## priorities (click to change), and Release.

const SbData := preload("res://sandbox/sb_data.gd")
const UiTheme := preload("res://scripts/ui_theme.gd")
const SPEEDS := [1.0, 2.0, 4.0]

var world: Node2D

var _root: Control
var _res_label: Label
var _raid_label: Label
var _speed_button: Button
var _bar: HBoxContainer
var _panel: PanelContainer
var _rows: VBoxContainer
var _jobs: HBoxContainer
var _grid: HBoxContainer
var _log: VBoxContainer
var _refresh := 0.0


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build()
	add_child(_root)
	_make_top()
	_make_bar()
	_make_panel()
	_make_log()
	var help := Label.new()
	help.text = "Left-click: select (Shift adds)  Drag: box  Right-click: order  R: release  1-5: job  A/D: pan"
	help.add_theme_font_size_override("font_size", 8)
	help.add_theme_color_override("font_color", UiTheme.PARCHMENT_DIM)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(4, 348)
	_root.add_child(help)
	world.selection_changed.connect(_rebuild_panel)
	world.announced.connect(func(_t): _show_log())
	_rebuild_panel()


func _make_top() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(640, 18)
	_root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_right", 2)
	top.add_child(pad)
	pad.add_child(row)
	var title := Label.new()
	title.text = "SANDBOX"
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(title)
	_res_label = Label.new()
	row.add_child(_res_label)
	_raid_label = Label.new()
	_raid_label.add_theme_color_override("font_color", UiTheme.BAD)
	_raid_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_raid_label)
	for spec in [["Raid (T)", func(): world.start_raid()], ["Fire (F)", func(): world.start_fire()]]:
		var b := _button(spec[0], spec[1])
		row.add_child(b)
	_speed_button = _button("Speed 1x", _cycle_speed)
	row.add_child(_speed_button)


func _make_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.position = Vector2(4, 22)
	_bar.add_theme_constant_override("separation", 2)
	_root.add_child(_bar)
	for p in world.peasants:
		var b := _button(p.person_name, _bar_click.bind(p))
		UiTheme.make_compact(b)
		b.add_theme_font_size_override("font_size", 9)
		b.custom_minimum_size = Vector2(44, 0)
		_bar.add_child(b)


func _make_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(4, 252)
	_root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	box.add_child(_rows)
	_jobs = HBoxContainer.new()
	_jobs.add_theme_constant_override("separation", 2)
	box.add_child(_jobs)
	for job in SbData.JOB_ORDER:
		var b := _button(SbData.JOBS[job].name, func(): world.set_job_selected(job))
		UiTheme.make_compact(b)
		b.add_theme_font_size_override("font_size", 9)
		b.tooltip_text = _job_tip(job)
		b.set_meta("job", job)
		_jobs.add_child(b)
	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", 2)
	box.add_child(_grid)
	for w in SbData.WORK:
		var b := _button("", _cycle_prio.bind(w))
		UiTheme.make_compact(b)
		b.add_theme_font_size_override("font_size", 9)
		b.tooltip_text = "Priority for %s work: 1 first, 3 last, - never. Click to change." % SbData.WORK_NAMES[w]
		b.set_meta("work", w)
		_grid.add_child(b)
	var release := _button("Release (R)", func(): world.release_selected())
	UiTheme.make_compact(release)
	release.add_theme_font_size_override("font_size", 9)
	release.tooltip_text = "Drop their orders: they go back to choosing work themselves."
	_grid.add_child(release)


func _make_log() -> void:
	_log = VBoxContainer.new()
	_log.position = Vector2(400, 290)
	_log.custom_minimum_size = Vector2(236, 0)
	_log.add_theme_constant_override("separation", 0)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_log)


func _button(text: String, call: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(call)
	return b


func _job_tip(job: String) -> String:
	var parts: Array = []
	for w in SbData.WORK:
		var v: int = SbData.JOBS[job].work.get(w, 0)
		if v > 0:
			parts.append("%s %d" % [SbData.WORK_NAMES[w], v])
	return "%s: %s" % [SbData.JOBS[job].name, ", ".join(parts)]


func _bar_click(p: Node2D) -> void:
	world.select([p], Input.is_key_pressed(KEY_SHIFT))


func _cycle_prio(w: String) -> void:
	if world.selected.is_empty():
		return
	var first: Node2D = world.selected[0]
	first.cycle_prio(w)
	for p in world.selected:
		if p != first:
			p.prio[w] = first.prio[w]
			p.rethink()
	_rebuild_panel()


func _cycle_speed() -> void:
	var i := SPEEDS.find(Engine.time_scale)
	Engine.time_scale = SPEEDS[(i + 1) % SPEEDS.size()]
	_speed_button.text = "Speed %dx" % int(Engine.time_scale)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.2
	_res_label.text = "Wood %d   Stone %d" % [world.stockyard.stock.wood, world.stockyard.stock.stone]
	_raid_label.text = "RAID! %d raiders" % world.raiders.size() if world.raid_on else ""
	if world.fires.size() > 0:
		_raid_label.text += ("   " if world.raid_on else "") + "FIRE!"
	for i in _bar.get_child_count():
		var b := _bar.get_child(i) as Button
		var p: Node2D = world.peasants[i] if i < world.peasants.size() else null
		if p == null:
			continue
		var c := UiTheme.GOLD if p.selected else (UiTheme.BAD if p.downed else UiTheme.PARCHMENT)
		b.add_theme_color_override("font_color", c)
		b.tooltip_text = "%s, %s: %s" % [p.person_name, p.job_name(), p.activity()]
	_update_rows()


func _rebuild_panel() -> void:
	_panel.visible = not world.selected.is_empty()
	if not _panel.visible:
		return
	for c in _rows.get_children():
		c.queue_free()
	var shown := mini(world.selected.size(), 5)
	for i in shown:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 9)
		_rows.add_child(l)
	if world.selected.size() > shown:
		var more := Label.new()
		more.add_theme_font_size_override("font_size", 9)
		more.text = "and %d more" % (world.selected.size() - shown)
		_rows.add_child(more)
	var first: Node2D = world.selected[0]
	for b in _jobs.get_children():
		var all_same: bool = world.selected.all(func(p): return p.job == b.get_meta("job"))
		b.add_theme_color_override("font_color", UiTheme.GOLD if all_same else UiTheme.PARCHMENT)
	for b in _grid.get_children():
		if not b.has_meta("work"):
			continue
		var w: String = b.get_meta("work")
		var v: int = first.prio[w]
		b.text = "%s %s" % [SbData.WORK_NAMES[w], str(v) if v > 0 else "-"]
		b.add_theme_color_override("font_color", UiTheme.GOLD if v == 1 else (UiTheme.PARCHMENT if v > 0 else UiTheme.PARCHMENT_DIM))
	_update_rows()


func _update_rows() -> void:
	if not _panel.visible:
		return
	var labels := _rows.get_children()
	for i in mini(labels.size(), world.selected.size()):
		var p: Node2D = world.selected[i]
		var l := labels[i] as Label
		if l == null or not is_instance_valid(p) or (i == 5):
			continue
		l.text = "%s (%s): %s" % [p.person_name, p.job_name(), p.activity()]
		l.add_theme_color_override("font_color", UiTheme.GOLD if not p.order.is_empty() else UiTheme.PARCHMENT)


func _show_log() -> void:
	for c in _log.get_children():
		c.queue_free()
	var last: Array = world.messages.slice(maxi(world.messages.size() - 4, 0))
	for text in last:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 9)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(236, 0)
		_log.add_child(l)
