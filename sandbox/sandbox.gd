extends Node2D
## The sandbox: a test map for a new way of working with peasants, kept
## apart from the main game (nothing in res://scripts is changed).
##
## - The ground is a band with depth (sb_data.gd): peasants walk along it
##   and towards or away from the viewer; who is in front is drawn in front.
## - Several building sites at once; each builder picks one by itself.
## - The new job system (sb_peasant.gd): jobs are presets of work
##   priorities; peasants choose work by themselves; the player can select
##   them and give orders that come first.
##
## Controls: left-click a peasant to select (Shift adds), drag a box to
## select several; right-click something to order the selected peasants to
## it; R releases their orders; Esc deselects. A/D or middle-drag pans, the
## wheel zooms. T starts a raid, F a fire, 1-5 set the job of the selected.

const SbData := preload("res://sandbox/sb_data.gd")
const Peasant := preload("res://sandbox/sb_peasant.gd")
const Site := preload("res://sandbox/sb_site.gd")
const TreeThing := preload("res://sandbox/sb_tree.gd")
const Rock := preload("res://sandbox/sb_rock.gd")
const Item := preload("res://sandbox/sb_item.gd")
const Fire := preload("res://sandbox/sb_fire.gd")
const Raider := preload("res://sandbox/sb_raider.gd")
const Stockyard := preload("res://sandbox/sb_stockyard.gd")
const Well := preload("res://sandbox/sb_well.gd")
const Backdrop := preload("res://sandbox/sb_backdrop.gd")
const Hud := preload("res://sandbox/sb_hud.gd")

const ZOOMS := [0.5, 1.0, 2.0, 3.0]

signal selection_changed
signal announced(text: String)

var peasants: Array = []
var sites: Array = []
var trees: Array = []
var rocks: Array = []
var items: Array = []
var fires: Array = []
var raiders: Array = []
var stockyard: Node2D
var well: Node2D
var guard_post := Vector2(-250, 30)
var selected: Array = []
## A building site picked with a left-click (its info shows in the HUD).
var picked_site: Node2D = null
## The building being placed from the Build menu, or "".
var placing := ""
var messages: Array = []
var raid_on := false
var raids := 0

var camera: Camera2D
var things: Node2D
var overlay: Node2D
var hud: CanvasLayer

var _drag_from := Vector2.INF
var _panning := false
var _pings: Array = []


func _ready() -> void:
	randomize()
	var back := Node2D.new()
	back.set_script(Backdrop)
	back.z_index = -10
	add_child(back)
	things = Node2D.new()
	things.y_sort_enabled = true
	add_child(things)
	overlay = Node2D.new()
	overlay.z_index = 10
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	camera = Camera2D.new()
	camera.position = Vector2(60, -20)
	add_child(camera)
	camera.make_current()
	_build_map()
	hud = CanvasLayer.new()
	hud.set_script(Hud)
	hud.world = self
	add_child(hud)
	announce("Welcome to the sandbox. Select peasants and right-click to give orders.")


func _build_map() -> void:
	stockyard = _add(Stockyard, Vector2(190, 10))
	stockyard.setup()
	stockyard.put("wood", 14)
	stockyard.put("stone", 18)
	well = _add(Well, Vector2(255, 8))
	well.setup()
	# Three building sites side by side, each its own job.
	for pair in [["hut", -170.0], ["wall", -60.0], ["tower", 60.0]]:
		add_site(pair[0], Vector2(pair[1], 4))
	# Rocks and a wood to the east, at different depths.
	for spot in [Vector2(320, 14), Vector2(352, 46), Vector2(300, 66)]:
		var r: Node2D = _add(Rock, spot)
		r.setup(12)
		rocks.append(r)
	for i in 9:
		var spot := Vector2(410 + i * 22 + (i % 2) * 6, 6 + float((i * 17) % 66))
		var t: Node2D = _add(TreeThing, spot)
		t.setup(3 + i % 3, 0.8 + 0.1 * float(i % 4))
		trees.append(t)
	# A few trees to the west too, where the raiders come from.
	for spot in [Vector2(-300, 8), Vector2(-330, 40)]:
		var t: Node2D = _add(TreeThing, spot)
		t.setup(4, 1.0)
		trees.append(t)
	var crew := [["builder", 3], ["woodcutter", 1], ["miner", 1], ["hauler", 1], ["guard", 1]]
	var n := 0
	for pair in crew:
		for i in pair[1]:
			var p: Node2D = _add(Peasant, Vector2(140 + n * 14, 20 + (n * 11) % 50))
			p.setup(SbData.NAMES[n], pair[0])
			peasants.append(p)
			n += 1


func _add(script: Script, at: Vector2) -> Node2D:
	var node := Node2D.new()
	node.set_script(script)
	node.world = self
	node.position = at
	things.add_child(node)
	return node


func add_site(building: String, at: Vector2) -> Node2D:
	var b: Dictionary = SbData.BUILDINGS[building]
	var site: Node2D = _add(Site, at)
	site.setup(b.title, b.style, b.cols, b.courses)
	sites.append(site)
	return site


## True if a building of this kind fits with its middle at x: not over
## another building, the stockyard or the well, and inside the map.
func site_fits(building: String, x: float) -> bool:
	var half: float = SbData.BUILDINGS[building].cols * 5.0 + 4.0
	if x - half < SbData.WEST_EDGE + 10.0 or x + half > SbData.EAST_EDGE - 10.0:
		return false
	for s in sites:
		if absf(s.position.x - x) < half + s.width() / 2.0 + 4.0:
			return false
	for t in [stockyard, well]:
		if absf(t.position.x - x) < half + 36.0:
			return false
	# Not over trees or rocks standing at the back of the ground.
	for t in trees + rocks:
		if t.is_open() and t.position.y < 24.0 and absf(t.position.x - x) < half + 6.0:
			return false
	return true


## Cancels a site: what was laid falls down as loose blocks to haul back.
func cancel_site(site: Node2D) -> void:
	for i in mini(site.placed, 8):
		spawn_item(site.laid[i], site.position + Vector2(randf_range(-site.width() / 2.0, site.width() / 2.0), randf_range(6, 14)))
	for res in site.stock:
		for i in site.stock[res]:
			spawn_item(res, site.pile_spot() + Vector2(randf_range(-6, 6), randf_range(0, 6)))
	announce("The %s is cancelled." % site.title)
	if picked_site == site:
		pick_site(null)
	remove_thing(site)


func pick_site(site: Node2D) -> void:
	if picked_site != null and is_instance_valid(picked_site):
		picked_site.selected = false
		picked_site.queue_redraw()
	picked_site = site
	if site != null:
		site.selected = true
		site.queue_redraw()
	selection_changed.emit()


func spawn_item(res: String, at: Vector2) -> Node2D:
	at.y = clampf(at.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
	var it: Node2D = _add(Item, at)
	it.setup(res)
	items.append(it)
	return it


func remove_thing(t: Node2D) -> void:
	for list in [items, fires, raiders, peasants, trees, rocks, sites]:
		list.erase(t)
	selected.erase(t)
	for p in peasants:
		p.forget(t)
	t.queue_free()
	if t.kind == "raider" and raid_on and raiders.is_empty():
		raid_on = false
		announce("The raid is over.")
		for p in peasants:
			p.rethink()


func announce(text: String) -> void:
	messages.append(text)
	if messages.size() > 30:
		messages.pop_front()
	announced.emit(text)


# --- Work for peasants -----------------------------------------------------

## The best thing of this work type for the peasant to do by itself, as
## {"kind", "target", "score"} (lower score = better), or {} if none.
func find_work(p: Node2D, work: String) -> Dictionary:
	var best: Node2D = null
	var best_score := INF
	var supply := ""
	var list: Array = []
	match work:
		"firefight":
			list = fires
		"fight":
			list = raiders
		"build":
			list = sites
		"chop":
			list = trees
		"mine":
			list = rocks
		"haul":
			list = items
		"rescue":
			# The hurt, not yet carried and with no raider standing over them.
			list = peasants.filter(func(o): return o != p and o.is_open() and o.carried_by == null and nearest_raider(o.position, 50.0) == null)
	for t in list:
		if not t.is_open() or t.workers.size() >= t.capacity():
			continue
		var score := p.position.distance_to(t.position)
		if work == "build":
			var need: String = t.next_material()
			if p.carrying != need and stockyard.stock.get(need, 0) <= 0 and t.stock[need] <= 0:
				continue
			# Spread out: a site with fewer builders on it is better; an
			# urgent one comes first.
			score += 80.0 * t.workers.size()
			if t.urgent:
				score -= 1000.0
		if score < best_score:
			best_score = score
			best = t
	if work == "haul":
		# Hauling also means bringing building material to the sites.
		for site in sites:
			if site.done():
				continue
			for res in ["stone", "wood"]:
				if site.wanted(res) <= 0 or stockyard.stock[res] <= 0:
					continue
				var score := p.position.distance_to(stockyard.position) + stockyard.position.distance_to(site.position) * 0.5
				if site.urgent:
					score -= 1000.0
				if score < best_score:
					best_score = score
					best = site
					supply = res
	if best == null:
		return {}
	if supply != "":
		return {"kind": "supply", "target": best, "score": best_score, "res": supply}
	return {"kind": work, "target": best, "score": best_score}


## A finished Hut with a free bed, or null.
func free_bed() -> Node2D:
	for s in sites:
		if s.has_beds() and s.sleepers.size() < SbData.HUT_BEDS:
			return s
	return null


func nearest_peasant(at: Vector2, within: float) -> Node2D:
	var best: Node2D = null
	var d := within
	for p in peasants:
		if p.downed:
			continue
		var pd := at.distance_to(p.position)
		if pd < d:
			d = pd
			best = p
	return best


func nearest_raider(at: Vector2, within: float) -> Node2D:
	var best: Node2D = null
	var d := within
	for r in raiders:
		var rd := at.distance_to(r.position)
		if rd < d:
			d = rd
			best = r
	return best


# --- Events for testing ----------------------------------------------------

func start_raid(count := 4) -> void:
	raids += 1
	raid_on = true
	for i in count:
		var r: Node2D = _add(Raider, Vector2(SbData.WEST_EDGE - 10 - i * 14, 12 + (i * 17) % 60))
		r.setup()
		raiders.append(r)
	announce("Raiders are coming from the west!")
	for p in peasants:
		p.rethink()


func start_fire(host: Node2D = null) -> void:
	if host == null:
		var hosts: Array = [stockyard]
		for s in sites:
			if s.placed > 0:
				hosts.append(s)
		host = hosts.pick_random()
	var f: Node2D = _add(Fire, host.position + Vector2(randf_range(-8, 8), 3))
	f.setup(host)
	fires.append(f)
	announce("Fire at %s!" % host.label())
	for p in peasants:
		p.rethink()


# --- Selection and orders --------------------------------------------------

func select(list: Array, add := false) -> void:
	if not add:
		for p in selected:
			if is_instance_valid(p):
				p.selected = false
		selected.clear()
	for p in list:
		if not selected.has(p):
			selected.append(p)
			p.selected = true
	if not list.is_empty() and picked_site != null:
		pick_site(null)
	selection_changed.emit()


func _site_at(at: Vector2) -> Node2D:
	for s in sites:
		if s.hit(at):
			return s
	return null


func peasant_at(at: Vector2) -> Node2D:
	# The one in front wins when several overlap.
	var best: Node2D = null
	for p in peasants:
		if p.hit(at) and (best == null or p.position.y > best.position.y):
			best = p
	return best


## What a right-click at this point means: an order for the selected.
func order_at(at: Vector2) -> Dictionary:
	for p in peasants:
		if p.is_open() and p.hit(at):
			return {"kind": "rescue", "target": p}
	for list_kind in [[raiders, "fight"], [fires, "firefight"], [items, "haul"], [trees, "chop"], [rocks, "mine"], [sites, "build"]]:
		for t in list_kind[0]:
			if t.is_open() and t.hit(at):
				return {"kind": list_kind[1], "target": t}
	at.y = clampf(at.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
	return {"kind": "goto", "target": null, "pos": at}


func give_order(at: Vector2, add := false) -> void:
	if selected.is_empty():
		return
	var o := order_at(at)
	var i := 0
	for p in selected:
		if p.downed:
			continue
		var mine := o.duplicate()
		if mine.kind == "goto":
			# Spread a group out around the point instead of on one spot.
			mine.pos = o.pos + Vector2(float(i % 3) * 10.0 - 10.0, float(i / 3) * 8.0)
		elif mine.kind == "haul" and i > 0:
			# One item per peasant: the others take the nearest other ones.
			var other := _free_item_near(o.target.position, p)
			if other == null:
				continue
			mine.target = other
		p.set_order(mine, add)
		i += 1
	_pings.append({"pos": at, "t": 0.6})
	selection_changed.emit()


## Orders the selected peasants to work on this thing (as a right-click on it).
func order_peasants_to(t: Node2D) -> void:
	give_order(t.position + Vector2(0, -4))


func _free_item_near(at: Vector2, p: Node2D) -> Node2D:
	var best: Node2D = null
	var d := 60.0
	for it in items:
		if not it.workers.is_empty() and not it.workers.has(p):
			continue
		var id: float = at.distance_to(it.position)
		if id < d:
			d = id
			best = it
	return best


func release_selected() -> void:
	for p in selected:
		p.release_order()
	selection_changed.emit()


## Drafts the selected, or undrafts them if they all are already.
func toggle_draft_selected() -> void:
	var all_drafted := selected.all(func(p): return p.drafted)
	for p in selected:
		if not p.downed:
			p.set_drafted(not all_drafted)
	selection_changed.emit()


func set_job_selected(job: String) -> void:
	for p in selected:
		p.set_job(job)
	selection_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	var at := get_global_mouse_position()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if placing != "" and mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and site_fits(placing, roundf(at.x)):
				add_site(placing, Vector2(roundf(at.x), 4))
				announce("A %s is planned." % SbData.BUILDINGS[placing].title)
				if not mb.shift_pressed:
					placing = ""
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				placing = ""
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_from = at
			elif _drag_from != Vector2.INF:
				var rect := Rect2(_drag_from, at - _drag_from).abs()
				if rect.size.length() < 4.0:
					var p := peasant_at(at)
					if p != null and mb.shift_pressed and selected.has(p):
						p.selected = false
						selected.erase(p)
						selection_changed.emit()
					else:
						select([p] if p != null else [], mb.shift_pressed)
						if p == null:
							pick_site(_site_at(at))
				else:
					var inside: Array = []
					for p in peasants:
						if rect.grow(4.0).has_point(p.position):
							inside.append(p)
					select(inside, mb.shift_pressed)
				_drag_from = Vector2.INF
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			give_order(at, mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mb.pressed:
			# Whole steps only, so the pixels stay even.
			var i := ZOOMS.find(camera.zoom.x)
			i = clampi(i + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)
			camera.zoom = Vector2.ONE * ZOOMS[i]
	elif event is InputEventMouseMotion and _panning:
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_R:
				release_selected()
			KEY_G:
				toggle_draft_selected()
			KEY_ESCAPE:
				placing = ""
				select([])
				pick_site(null)
			KEY_B:
				hud.toggle_build()
			KEY_T:
				start_raid()
			KEY_F:
				start_fire()
			KEY_W:
				hud.toggle_work()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				set_job_selected(SbData.JOB_ORDER[(event as InputEventKey).keycode - KEY_1])


func _process(delta: float) -> void:
	var pan := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		pan -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan += 1.0
	camera.position.x = clampf(camera.position.x + pan * 220.0 * delta / camera.zoom.x, SbData.WEST_EDGE, SbData.EAST_EDGE)
	for ping in _pings:
		ping.t -= delta
	_pings = _pings.filter(func(pg): return pg.t > 0.0)
	overlay.queue_redraw()


## Drawn on top of the world: the selection box, lines from the selected to
## what they are doing, and a ping where an order was given.
func _draw_overlay() -> void:
	if _drag_from != Vector2.INF:
		var rect := Rect2(_drag_from, get_global_mouse_position() - _drag_from).abs()
		if rect.size.length() >= 4.0:
			overlay.draw_rect(rect, Color(SbData.GOLD, 0.15))
			overlay.draw_rect(rect, SbData.GOLD, false, 1.0)
	for p in selected:
		if not is_instance_valid(p):
			continue
		var to := Vector2.INF
		var t = p.task.get("target")
		if t != null and is_instance_valid(t):
			to = t.position
		elif p.task.get("kind", "") == "goto":
			to = p.task.pos
		if to != Vector2.INF:
			var c := SbData.GOLD if p.task.get("forced", false) else Color(SbData.WHITE, 0.5)
			_dotted(p.position + Vector2(0, -6), to, c)
			overlay.draw_rect(Rect2(to - Vector2(1, 1), Vector2(3, 3)), c)
		# Queued orders: a dotted line on to each, with its number.
		var from: Vector2 = to if to != Vector2.INF else p.position
		var n := 2
		for o in p.queue:
			var qt = o.get("target")
			var qto: Vector2 = o.pos if o.kind == "goto" else (qt.position if qt != null and is_instance_valid(qt) else Vector2.INF)
			if qto == Vector2.INF:
				continue
			_dotted(from, qto, Color(SbData.GOLD, 0.7))
			overlay.draw_string(ThemeDB.fallback_font, qto + Vector2(2, -2), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SbData.GOLD)
			from = qto
			n += 1
	if placing != "":
		_draw_ghost(get_global_mouse_position())
	for ping in _pings:
		var r: float = 3.0 + (0.6 - ping.t) * 14.0
		overlay.draw_arc(ping.pos, r, 0, TAU, 12, Color(SbData.GOLD, ping.t / 0.6), 1.0)


## The building being placed, as a see-through outline under the mouse:
## gold where it fits, red where it does not.
func _draw_ghost(at: Vector2) -> void:
	var b: Dictionary = SbData.BUILDINGS[placing]
	var x := roundf(at.x)
	var w: float = b.cols * 10.0
	var h: float = b.courses.size() * 6.0
	var c := SbData.GOLD if site_fits(placing, x) else SbData.RED1
	overlay.draw_rect(Rect2(x - w / 2.0, 4.0 - h, w, h), Color(c, 0.25))
	overlay.draw_rect(Rect2(x - w / 2.0, 4.0 - h, w, h), c, false, 1.0)
	overlay.draw_string(ThemeDB.fallback_font, Vector2(x - w / 2.0, 4.0 - h - 3.0), b.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)


func _dotted(a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(a.distance_to(b) / 4.0)
	for i in n:
		if i % 2 == 0:
			overlay.draw_rect(Rect2(a.lerp(b, float(i) / float(maxi(n, 1))), Vector2(1, 1)), c)
