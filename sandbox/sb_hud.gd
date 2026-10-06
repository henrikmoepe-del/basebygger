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
var _clock: Label
var _night_button: Button
var _bar: HBoxContainer
var _panel: PanelContainer
var _rows: VBoxContainer
var _jobs: HBoxContainer
var _grid: HBoxContainer
var _log: VBoxContainer
var _work: PanelContainer
var _draft_button: Button
var _card: PanelContainer
var _card_body: Control
var _build: PanelContainer
var _site_panel: PanelContainer
var _site_label: Label
var _urgent_button: Button
var _work_grid: GridContainer
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
	_make_work()
	_make_build()
	_make_site_panel()
	_make_card()
	var help := Label.new()
	help.text = "Left-click: select (Shift adds)  Drag: box  Right-click: order  R: release  1-6: job  G: draft  W: work  B: build"
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
	_clock = Label.new()
	_clock.add_theme_color_override("font_color", UiTheme.PARCHMENT_DIM)
	row.add_child(_clock)
	_raid_label = Label.new()
	_raid_label.add_theme_color_override("font_color", UiTheme.BAD)
	_raid_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_raid_label)
	for spec in [["Build (B)", toggle_build], ["Work (W)", toggle_work]]:
		var b := _button(spec[0], spec[1])
		row.add_child(b)
	_night_button = _button("Night work: no", func(): world.set_night_work(not world.night_work))
	_night_button.tooltip_text = "A policy. Off: everyone sleeps at night. On: they work through the night, 15% slower in the dark, and tire faster."
	row.add_child(_night_button)
	# Test tools, small, on the right under the top bar.
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 2)
	tools.position = Vector2(470, 22)
	_root.add_child(tools)
	for spec in [["Raid (T)", func(): world.start_raid()], ["Fire (F)", func(): world.start_fire()]]:
		var b := _button(spec[0], spec[1])
		_compact(b)
		tools.add_child(b)
	_speed_button = _button("Speed 1x", _cycle_speed)
	_compact(_speed_button)
	tools.add_child(_speed_button)


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
	_draft_button = _button("Draft (G)", func(): world.toggle_draft_selected())
	_compact(_draft_button)
	_draft_button.tooltip_text = "Drafted: they stop working, stand where you send them and fight raiders who come near."
	_grid.add_child(_draft_button)
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


## The Work overview: every peasant in a row, their job and a priority per
## kind of work. Click a job to change it, click a priority to cycle it.
func _make_work() -> void:
	_work = PanelContainer.new()
	_work.visible = false
	_work.position = Vector2(150, 48)
	_root.add_child(_work)
	var box := VBoxContainer.new()
	_work.add_child(box)
	var title := Label.new()
	title.text = "Work: priority 1 first, 3 last, - never.  ·n = skill (grows by doing)"
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(title)
	_work_grid = GridContainer.new()
	_work_grid.columns = 2 + SbData.WORK.size()
	_work_grid.add_theme_constant_override("h_separation", 2)
	_work_grid.add_theme_constant_override("v_separation", 1)
	box.add_child(_work_grid)


## The Build menu: pick a building, then left-click where it goes along the
## back of the ground (Shift-click to place several, right-click to stop).
func _make_build() -> void:
	_build = PanelContainer.new()
	_build.visible = false
	_build.position = Vector2(300, 48)
	_root.add_child(_build)
	var box := VBoxContainer.new()
	_build.add_child(box)
	for key in SbData.BUILD_ORDER:
		var b: Dictionary = SbData.BUILDINGS[key]
		var count := {}
		for m in b.courses:
			count[m] = count.get(m, 0) + b.cols
		var parts: Array = []
		for m in count:
			parts.append("%d %s" % [count[m], m])
		var button := _button("%s (%s)" % [b.title, ", ".join(parts)], _start_placing.bind(key))
		_compact(button)
		box.add_child(button)


func toggle_build() -> void:
	_build.visible = not _build.visible


func _start_placing(key: String) -> void:
	world.placing = key
	_build.visible = false


## What a picked building site shows: progress, and buttons to make it
## urgent (builders go there first) or cancel it.
func _make_site_panel() -> void:
	_site_panel = PanelContainer.new()
	_site_panel.visible = false
	_site_panel.position = Vector2(4, 300)
	_root.add_child(_site_panel)
	var box := VBoxContainer.new()
	_site_panel.add_child(box)
	_site_label = Label.new()
	_site_label.add_theme_font_size_override("font_size", 9)
	box.add_child(_site_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	_urgent_button = _button("Urgent", _toggle_urgent)
	_compact(_urgent_button)
	_urgent_button.tooltip_text = "Builders choosing for themselves go to an urgent site first."
	row.add_child(_urgent_button)
	var cancel := _button("Cancel", func(): world.cancel_site(world.picked_site))
	_compact(cancel)
	cancel.tooltip_text = "Remove the site. What was laid falls down to be hauled back."
	row.add_child(cancel)


## The card for one selected peasant: health, hunger and rest as bars, and
## their skills. Drawn by hand on a small Control.
func _make_card() -> void:
	_card = PanelContainer.new()
	_card.visible = false
	_card.position = Vector2(4, 150)
	_root.add_child(_card)
	_card_body = Control.new()
	_card_body.custom_minimum_size = Vector2(120, 92)
	_card_body.draw.connect(_draw_card)
	_card.add_child(_card_body)


func _draw_card() -> void:
	if world.selected.size() != 1:
		return
	var p: Node2D = world.selected[0]
	if not is_instance_valid(p):
		return
	var font := ThemeDB.fallback_font
	var c := _card_body
	c.draw_string(font, Vector2(0, 9), "%s, %s" % [p.person_name, p.job_name()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.GOLD)
	var bars := [["Health", p.hp / p.max_hp, SbData.GRASS3], ["Fed", 1.0 - p.hunger / 100.0, SbData.GOLD], ["Rested", 1.0 - p.tired / 100.0, SbData.SKY2]]
	var y := 14.0
	for bar in bars:
		c.draw_string(font, Vector2(0, y + 7), bar[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.PARCHMENT)
		c.draw_rect(Rect2(40, y + 1, 78, 6), SbData.INK)
		c.draw_rect(Rect2(40, y + 1, 78.0 * clampf(bar[1], 0.0, 1.0), 6), bar[2])
		y += 10.0
	y += 3.0
	for w in SbData.SKILLED:
		var lvl: int = p.skill[w]
		var need: float = SbData.SKILL_BASE + SbData.SKILL_PER_LEVEL * lvl
		c.draw_string(font, Vector2(0, y + 7), SbData.WORK_NAMES[w], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.PARCHMENT)
		for i in SbData.SKILL_MAX:
			var on := i < lvl
			c.draw_rect(Rect2(40 + i * 7, y + 2, 6, 5), UiTheme.GOLD if on else SbData.STONE0)
		# Practice towards the next level, as a thin line under it.
		if lvl < SbData.SKILL_MAX:
			c.draw_rect(Rect2(40 + lvl * 7, y + 7, 6.0 * p.practice[w] / need, 1), UiTheme.GOLD)
		y += 9.0


func _toggle_urgent() -> void:
	var site: Node2D = world.picked_site
	if site != null:
		site.urgent = not site.urgent
		site.queue_redraw()


func toggle_work() -> void:
	_work.visible = not _work.visible
	if _work.visible:
		_rebuild_work()


func _rebuild_work() -> void:
	for c in _work_grid.get_children():
		c.queue_free()
	for head in ["", "Job"]:
		_work_grid.add_child(_small_label(head))
	for w in SbData.WORK:
		_work_grid.add_child(_small_label(SbData.WORK_NAMES[w]))
	for p in world.peasants:
		var name_button := _button(p.person_name, func(): world.select([p]))
		_compact(name_button)
		_work_grid.add_child(name_button)
		var job_button := _button(p.job_name(), _next_job.bind(p))
		_compact(job_button)
		job_button.tooltip_text = "Click for the next job. A job sets all the priorities."
		_work_grid.add_child(job_button)
		for w in SbData.WORK:
			var v: int = p.prio[w]
			var text := str(v) if v > 0 else "-"
			if p.skill.has(w):
				text += " ·%d" % p.skill[w]
			var cell := _button(text, _cycle_one.bind(p, w))
			_compact(cell)
			cell.custom_minimum_size = Vector2(34, 0)
			cell.tooltip_text = "Priority %s%s. Click to change the priority." % [str(v) if v > 0 else "never", (", skill %d (works at %d%%)" % [p.skill[w], roundi(p.skill_mult(w) * 100.0)]) if p.skill.has(w) else ""]
			cell.add_theme_color_override("font_color", UiTheme.GOLD if v == 1 else (UiTheme.PARCHMENT if v > 0 else UiTheme.PARCHMENT_DIM))
			_work_grid.add_child(cell)


func _next_job(p: Node2D) -> void:
	var i := SbData.JOB_ORDER.find(p.job)
	p.set_job(SbData.JOB_ORDER[(i + 1) % SbData.JOB_ORDER.size()])
	_rebuild_work()
	_rebuild_panel()


func _cycle_one(p: Node2D, w: String) -> void:
	p.cycle_prio(w)
	_rebuild_work()
	_rebuild_panel()


func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _compact(b: Button) -> void:
	UiTheme.make_compact(b)
	b.add_theme_font_size_override("font_size", 9)


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
	var h: float = world.hour()
	_clock.text = "Day %d %02d:%02d%s" % [world.day(), int(h), int(fmod(h, 1.0) * 60.0), " night" if world.is_night() else ""]
	_night_button.text = "Night work: " + ("yes" if world.night_work else "no")
	_res_label.text = "Wood %d   Stone %d   Food %d" % [world.stockyard.stock.wood, world.stockyard.stock.stone, world.stockyard.stock.food]
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
	_update_site()
	_card.visible = world.selected.size() == 1
	if _card.visible:
		_card_body.queue_redraw()


func _update_site() -> void:
	var site: Node2D = world.picked_site
	_site_panel.visible = site != null and is_instance_valid(site)
	if not _site_panel.visible:
		return
	_site_label.text = site.progress_text()
	_urgent_button.text = "Urgent: yes" if site.urgent else "Urgent: no"
	_urgent_button.add_theme_color_override("font_color", UiTheme.GOLD if site.urgent else UiTheme.PARCHMENT)


func _rebuild_panel() -> void:
	_update_site()
	if _work != null and _work.visible:
		_rebuild_work.call_deferred()
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
	var all_drafted: bool = world.selected.all(func(p): return p.drafted)
	_draft_button.text = "Undraft (G)" if all_drafted else "Draft (G)"
	_draft_button.add_theme_color_override("font_color", UiTheme.BAD if all_drafted else UiTheme.PARCHMENT)
	for b in _jobs.get_children():
		var all_same: bool = world.selected.all(func(p): return p.job == b.get_meta("job"))
		b.add_theme_color_override("font_color", UiTheme.GOLD if all_same else UiTheme.PARCHMENT)
	for b in _grid.get_children():
		if not b.has_meta("work"):
			continue
		b.disabled = all_drafted
		var w: String = b.get_meta("work")
		var v: int = first.prio[w]
		b.text = "%s %s" % [SbData.WORK_NAMES[w], str(v) if v > 0 else "-"]
		if first.skill.has(w) and world.selected.size() == 1:
			b.text += " ·%d" % first.skill[w]
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
		l.text = "%s (%s): %s%s" % [p.person_name, p.job_name(), p.activity(), p.needs_text()]
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
