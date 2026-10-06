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
const Bush := preload("res://sandbox/sb_bush.gd")
const Deer := preload("res://sandbox/sb_deer.gd")
## Where the wood begins; deer keep to it.
const WOOD_FROM := 400.0
const HERD := 4
const HERD_GROWS := 60.0
const Rock := preload("res://sandbox/sb_rock.gd")
const Item := preload("res://sandbox/sb_item.gd")
const Fire := preload("res://sandbox/sb_fire.gd")
const Raider := preload("res://sandbox/sb_raider.gd")
const Stockyard := preload("res://sandbox/sb_stockyard.gd")
const Well := preload("res://sandbox/sb_well.gd")
const Backdrop := preload("res://sandbox/sb_backdrop.gd")
const Hud := preload("res://sandbox/sb_hud.gd")
## The main game's sound effects, made in code (M mutes).
const Sfx := preload("res://scripts/sfx.gd")

const ZOOMS := [0.5, 1.0, 2.0, 3.0]

signal selection_changed
## A traveller waits at the stockyard to be taken in or sent away (null when gone).
signal traveller_changed
## A question for the player is up or gone (see `ask`).
signal question_changed
signal announced(text: String)

var peasants: Array = []
var sites: Array = []
var trees: Array = []
var rocks: Array = []
var bushes: Array = []
var deer: Array = []
var _herd_timer := 0.0
var deer_shot := 0
var items: Array = []
var fires: Array = []
var raiders: Array = []
var stockyard: Node2D
var well: Node2D
var guard_post := Vector2(-300, 40)
var selected: Array = []
## A building site picked with a left-click (its info shows in the HUD).
var picked_site: Node2D = null
## The building being placed from the Build menu, or "".
var placing := ""
var messages: Array = []
var raid_on := false
## Seconds since the first morning, and the Night work policy.
var time := 0.0
var night_work := false
## The Child labour policy (children haul and forage at half pace).
var child_labour := false
var _last_hour := 8.0
## The alarm bell: while rung, everyone left to themselves shelters inside
## the castle (guards go to their post).
var alarm := false
var shelter := Vector2(89, 6)
var _tint: CanvasModulate
var raids := 0
## Raids on a timetable (tests turn it off), and when the next one comes.
var auto_raids := true
## No random mishaps (cave-ins, dozing off, sulking): for tests that need
## things to go as planned; those mishaps are tested on their own.
var calm := false
var next_raid := 0.0
## The traveller asking to join, if any, and when the next one comes.
var traveller: Node2D = null
var next_traveller := 0.0
## The question the player is asked, or {}: "text", "options" (button
## labels) and "answer" (a Callable taking the chosen index).
var question := {}
## The mystical man: when he comes next, and the price still owed.
var next_stranger := 0.0
var stranger: Node2D = null
var _price_at := -1.0
## A strike: seconds left (0 = none), and how long the mood has been low.
var strike := 0.0
var _low_mood_for := 0.0
## A storm: seconds left (0 = none), when it comes today, the next lightning,
## and a flash on screen.
var storm := 0.0
var _storm_at := -1.0
var _lightning := 0.0
var _flash := 0.0
## The traitor (secret), and what went missing last night (for the morning clue).
var traitor: Node2D = null
var stolen_last_night := {}

var camera: Camera2D
var things: Node2D
var overlay: Node2D
var hud: CanvasLayer

var _lanterns: Array = []
var _drag_from := Vector2.INF
var _panning := false
var _pings: Array = []


func _ready() -> void:
	randomize()
	# Pausing stops the world (`things` and the clock), but not the camera,
	# the overlay, input or the HUD: orders can be given while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var back := Node2D.new()
	back.set_script(Backdrop)
	back.z_index = -10
	add_child(back)
	_tint = CanvasModulate.new()
	add_child(_tint)
	things = Node2D.new()
	things.y_sort_enabled = true
	things.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(things)
	overlay = Node2D.new()
	overlay.z_index = 10
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	camera = Camera2D.new()
	camera.position = Vector2(60, -20)
	add_child(camera)
	camera.make_current()
	next_raid = time_at(SbData.FIRST_RAID_DAY, SbData.RAID_HOUR)
	next_traveller = time_at(SbData.FIRST_TRAVELLER_DAY, SbData.TRAVELLER_HOUR)
	next_stranger = time_at(SbData.STRANGER_FIRST_DAY, SbData.STRANGER_HOUR)
	_build_map()
	add_child(Sfx.new())
	hud = CanvasLayer.new()
	hud.set_script(Hud)
	hud.world = self
	add_child(hud)
	announce("Welcome to the sandbox. Select peasants and right-click to give orders.")


## Seconds since the first morning at which a day and hour come.
func time_at(day_: int, hour_: float) -> float:
	return ((float(day_ - 1) * 24.0 + hour_ - 8.0) / 24.0) * SbData.DAY_LENGTH


func _build_map() -> void:
	stockyard = _add(Stockyard, Vector2(190, 10))
	stockyard.setup()
	stockyard.put("wood", 14)
	stockyard.put("stone", 18)
	stockyard.put("food", 10)
	stockyard.put("planks", 2)
	well = _add(Well, Vector2(255, 8))
	well.setup()
	# Lanterns at the stockyard and the well, lit at dusk.
	_lanterns.append(preload("res://sandbox/sb_light.gd").add(stockyard, Vector2(-20, -24), 60.0, 0.8))
	_lanterns.append(preload("res://sandbox/sb_light.gd").add(well, Vector2(0, -18), 40.0, 0.6))
	# Three building sites side by side, each its own job.
	for pair in [["hut", -170.0], ["wall", -60.0], ["tower", 60.0]]:
		add_site(pair[0], Vector2(pair[1], 4))
	# A sawmill already stands east of the well.
	var mill: Node2D = add_site("sawmill", Vector2(305, 4))
	mill.finish_now()
	# Rocks and a wood to the east, at different depths.
	for spot in [Vector2(372, 18), Vector2(352, 48), Vector2(300, 66)]:
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
	# Berry bushes in the meadow in front of the village.
	for spot in [Vector2(230, 60), Vector2(262, 72), Vector2(150, 74), Vector2(110, 62), Vector2(296, 58)]:
		var b: Node2D = _add(Bush, spot)
		b.setup(3)
		bushes.append(b)
	for i in 3:
		_add_deer(Vector2(470 + i * 40, 20 + i * 18))
	var crew := [["builder", 3], ["woodcutter", 1], ["miner", 1], ["hauler", 1], ["guard", 1], ["forager", 1], ["crafter", 1], ["hunter", 1]]
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
	site.workshop = b.get("workshop", "")
	if site.workshop != "":
		site.keep = SbData.WORKSHOPS[site.workshop].keep
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


func _add_deer(at: Vector2) -> void:
	var d: Node2D = _add(Deer, at)
	d.setup()
	deer.append(d)


## Asks the player something: buttons for the options, and `answer` is
## called with the index chosen.
func ask(text: String, options: Array, answer: Callable) -> void:
	question = {"text": text, "options": options, "answer": answer}
	question_changed.emit()


func answer_question(i: int) -> void:
	if question.is_empty():
		return
	var q := question
	question = {}
	question_changed.emit()
	q.answer.call(i)


## The mystical man: a hooded stranger at the edge of the wood offers a gift.
func arrive_stranger() -> void:
	var gift: String = SbData.GIFTS.keys().pick_random()
	stranger = Node2D.new()
	stranger.set_script(preload("res://sandbox/sb_stranger.gd"))
	stranger.position = Vector2(WOOD_FROM - 20.0, 22)
	things.add_child(stranger)
	announce("A hooded stranger waits at the edge of the wood.")
	ask("A hooded man offers %s. \"Only a small favour in return, later.\"" % SbData.GIFTS[gift], ["Take the gift", "Send him away"], func(i: int) -> void:
		if i == 0:
			_take_gift(gift)
		else:
			announce("The hooded man bows and is gone.")
		stranger.queue_free()
		stranger = null)


func _take_gift(gift: String) -> void:
	match gift:
		"food":
			stockyard.put("food", 25)
		"planks":
			stockyard.put("planks", 15)
		"skill":
			var adults: Array = peasants.filter(func(p): return not p.child)
			var p: Node2D = adults.pick_random()
			# Their own trade's skill (a guard's is fighting).
			var own: Array = SbData.JOBS[p.job].work.keys().filter(func(k): return SbData.SKILLED.has(k) and SbData.JOBS[p.job].work[k] == 1)
			var w: String = own.front() if not own.is_empty() else "fight"
			p.skill[w] = mini(p.skill[w] + 3, SbData.SKILL_MAX)
			announce("%s wakes up knowing far more about %s." % [p.person_name, SbData.WORK_NAMES[w].to_lower()])
	announce("The gift is yours. The hooded man smiles.")
	_price_at = time + SbData.STRANGER_PRICE_AFTER


## The price of the gift comes due.
func pay_price() -> void:
	var price: String = SbData.PRICES.keys().pick_random()
	match price:
		"sick":
			var p: Node2D = peasants.filter(func(o): return not o.downed).pick_random()
			if p != null:
				p.hp = 1.0
				p.remember("hurt")
				announce(SbData.PRICES.sick % p.person_name)
		"fire":
			var hosts: Array = sites.filter(func(s): return s.placed > 0)
			var host: Node2D = hosts.pick_random() if not hosts.is_empty() else stockyard
			start_fire(host, SbData.PRICES.fire % host.label())
		"dreams":
			for p in peasants:
				p.remember("dreams")
			announce(SbData.PRICES.dreams)


## A traveller walks in from the east and waits at the stockyard.
func arrive_traveller() -> void:
	var used := peasants.map(func(p): return p.person_name)
	var free: Array = SbData.NAMES.filter(func(n): return not used.has(n))
	var name_: String = free.pick_random() if not free.is_empty() else "Stranger %d" % (peasants.size() + 1)
	var t: Node2D = _add(Peasant, Vector2(SbData.EAST_EDGE - 10, 40))
	t.setup(name_, "hauler")
	t.guest = true
	t.task = {"kind": "goto", "pos": stockyard.position + Vector2(30, 24), "forced": true}
	t.order = t.task
	traveller = t
	announce("A traveller, %s (%s), asks to join the village." % [name_, t.trait_name()])
	traveller_changed.emit()
	ask("%s (%s: %s) asks to join." % [name_, t.trait_name(), SbData.TRAITS[t.trait_key].text], ["Take them in", "Send them away"], func(i: int) -> void: answer_traveller(i == 0))


## Takes the traveller in (a Hauler to start with) or sends them away.
func answer_traveller(take: bool) -> void:
	if traveller == null:
		return
	if not question.is_empty() and question.text.begins_with(traveller.person_name):
		question = {}
		question_changed.emit()
	var t := traveller
	traveller = null
	if take:
		t.guest = false
		t.release_order()
		peasants.append(t)
		announce("%s joins the village." % t.person_name)
	else:
		t.leaving = true
		t.set_order({"kind": "goto", "pos": Vector2(SbData.EAST_EDGE + 30, 40)})
		announce("%s goes on their way." % t.person_name)
	traveller_changed.emit()


func spawn_item(res: String, at: Vector2) -> Node2D:
	at.y = clampf(at.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
	var it: Node2D = _add(Item, at)
	it.setup(res)
	items.append(it)
	return it


func remove_thing(t: Node2D) -> void:
	for list in [items, fires, raiders, peasants, trees, rocks, bushes, deer, sites]:
		list.erase(t)
	selected.erase(t)
	for p in peasants:
		p.forget(t)
	t.queue_free()
	if t.kind == "raider" and raid_on and raiders.is_empty():
		raid_on = false
		sound("won")
		announce("The raid is over.")
		for p in peasants:
			p.remember("raid_won")
			p.rethink()


## Plays one of the main game's sounds, if where it happens is on screen.
func sound(name_: String, at := Vector2.INF) -> void:
	if at != Vector2.INF:
		var half := get_viewport_rect().size / 2.0 / camera.zoom
		if absf(at.x - camera.position.x) > half.x + 20.0 or absf(at.y - camera.position.y) > half.y + 40.0:
			return
	get_tree().call_group("sfx", "play", name_)


## What is under the mouse: the first thing whose shape is there, open or not.
func thing_at(at: Vector2) -> Node2D:
	for list in [raiders, fires, deer, items, bushes, rocks, trees, sites]:
		for t in list:
			if t.hit(at):
				return t
	if stockyard.hit(at):
		return stockyard
	if well.hit(at):
		return well
	return null


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
		"forage":
			list = bushes
		"hunt":
			list = deer
		"craft":
			# Workshops whose bill wants more, with input in the stockyard.
			list = sites.filter(func(s): return s.is_workshop() and _bill_wants(s) and (stockyard.stock.get(s.recipe().input, 0) > 0 or p.carrying == s.recipe().input))
		"haul":
			list = items
		"rescue":
			# The hurt, not yet carried and with no raider standing over them,
			# and anyone trapped in a cave-in (several can dig at once).
			list = peasants.filter(func(o): return o != p and o.is_open() and o.carried_by == null and nearest_raider(o.position, 50.0) == null)
			for r in rocks:
				if r.trapped != null and r.trapped != p:
					list.append(r)
	for t in list:
		var digging: bool = work == "rescue" and t.kind == "rock"
		if not digging and (t.forbidden or not t.is_open() or t.workers.size() >= t.capacity()):
			continue
		if digging and t.workers.size() >= 3:
			continue
		if work == "mine" and (t.trapped != null or t.stone <= 0):
			continue
		if (work == "chop" or work == "mine" or work == "forage") and loose_near(t.position) >= LOOSE_LIMIT:
			# Enough lies here already: haul it first.
			continue
		if work == "hunt" and items.filter(func(it): return it.res == "food" and it.position.x > WOOD_FROM - 40.0).size() >= LOOSE_LIMIT:
			# Bring the meat home before shooting more.
			continue
		var score := p.position.distance_to(t.position)
		if work == "build":
			if t.done():
				continue
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
			if site.forbidden:
				continue
			for res in ["stone", "wood", "planks"]:
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


const LOOSE_LIMIT := 4


## True if the workshop's bill wants more made: fewer than `keep` in the
## stockyard, counting what crafters are making right now.
func _bill_wants(shop: Node2D) -> bool:
	var r: Dictionary = shop.recipe()
	return stockyard.stock.get(r.output, 0) + shop.workers.size() < shop.keep


## Changes a workshop's bill by `by` (never below 0).
func change_bill(shop: Node2D, by: int) -> void:
	shop.keep = maxi(shop.keep + by, 0)
	shop.queue_redraw()


## How many loose things lie within 40 of this point.
func loose_near(at: Vector2) -> int:
	var n := 0
	for it in items:
		if it.position.distance_to(at) < 40.0:
			n += 1
	return n


## The middle of the dirt path at x (it winds gently, see sb_backdrop.gd).
func path_y(x: float) -> float:
	return 38.5 + 6.0 * sin(x / 90.0)


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
		if p.downed or not p.visible:
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


func start_storm() -> void:
	storm = SbData.STORM_TIME
	_lightning = SbData.LIGHTNING_EVERY * 0.5
	announce("A storm rolls in: rain, wind and lightning.")


func _update_storm(delta: float) -> void:
	_flash = maxf(_flash - delta * 3.0, 0.0)
	if _storm_at >= 0.0 and time >= _storm_at:
		_storm_at = -1.0
		start_storm()
	if storm <= 0.0:
		return
	storm -= delta
	if storm <= 0.0:
		storm = 0.0
		announce("The storm passes.")
		return
	_lightning -= delta
	if _lightning <= 0.0:
		_lightning = SbData.LIGHTNING_EVERY * randf_range(0.6, 1.4)
		_strike_lightning()


## A flash; maybe a fire on a building, or a tree knocked down.
func _strike_lightning() -> void:
	_flash = 1.0
	sound("lost")
	var roll := randf()
	if roll < 0.25:
		var hosts: Array = sites.filter(func(s): return s.placed > 0 and not fires.any(func(f): return f.host == s))
		if not hosts.is_empty():
			var host: Node2D = hosts.pick_random()
			start_fire(host, "Lightning strikes %s: fire!" % host.label())
	elif roll < 0.5:
		var standing: Array = trees.filter(func(t): return t.wood > 0)
		if not standing.is_empty():
			var t: Node2D = standing.pick_random()
			var logs: int = t.wood
			for i in logs:
				spawn_item("wood", t.position + Vector2(-10 + i * 7, randf_range(3, 9)))
			t.wood = 0
			t._regrow = t.REGROW_TIME
			t.queue_redraw()
			announce("Lightning brings down a tree: %d logs to collect." % logs)


## Low spirits for long enough make the village strike.
func _check_strike(delta: float) -> void:
	if strike > 0.0:
		strike -= delta
		if strike <= 0.0:
			strike = 0.0
			announce("The strike is over; the village goes back to work.")
		return
	var adults: Array = peasants.filter(func(p): return not p.child)
	if adults.is_empty() or calm:
		return
	var avg: float = adults.reduce(func(sum, p): return sum + p.mood, 0.0) / float(adults.size())
	_low_mood_for = _low_mood_for + delta if avg < SbData.STRIKE_MOOD else 0.0
	if _low_mood_for >= SbData.STRIKE_AFTER and question.is_empty():
		_low_mood_for = 0.0
		start_strike()


## The villagers lay down their tools; the player may hold a feast.
func start_strike() -> void:
	strike = SbData.STRIKE_TIME
	sound("lost")
	announce("The villagers lay down their tools: a strike!")
	for p in peasants:
		p.rethink()
	var can_feast: bool = stockyard.stock.food >= SbData.FEAST_FOOD
	var options := ["Hold a feast (%d food)" % SbData.FEAST_FOOD if can_feast else "No food for a feast", "Wait it out"]
	ask("The villagers lay down their tools. They are tired of this life.", options, func(i: int) -> void:
		if i == 0 and stockyard.stock.food >= SbData.FEAST_FOOD:
			stockyard.stock.food -= SbData.FEAST_FOOD
			stockyard.queue_redraw()
			for p in peasants:
				p.remember("feast")
			strike = 0.0
			announce("A feast! Spirits lift and the work goes on."))


## In the morning, the stockyard shows what went missing in the night.
func _morning_clue() -> void:
	for res in stolen_last_night:
		announce("Some %s is missing from the stockyard this morning (%d)." % [res, stolen_last_night[res]])
	stolen_last_night.clear()


## Called by the traitor when they get away with goods.
func goods_stolen(res: String, n: int) -> void:
	stolen_last_night[res] = stolen_last_night.get(res, 0) + n


## Someone saw the traitor sneaking off with goods.
func catch_traitor(by: Node2D) -> void:
	var t := traitor
	if t == null:
		return
	traitor = null
	var what := "%d %s" % [t.carry_n, t.carrying]
	t.release_order()
	t._end_task()
	t._put_back = true
	announce("%s catches %s sneaking off with %s!" % [by.person_name, t.person_name, what])
	ask("%s caught %s sneaking off with %s. The traitor hangs their head." % [by.person_name, t.person_name, what], ["Banish them", "Forgive them"], func(i: int) -> void:
		if i == 0:
			peasants.erase(t)
			selected.erase(t)
			t.guest = true
			t.leaving = true
			t.task = {"kind": "goto", "pos": Vector2(SbData.EAST_EDGE + 30, 40), "forced": true}
			announce("%s is banished from the village." % t.person_name)
			traveller_changed.emit()
		else:
			announce("%s is forgiven, and swears it will not happen again." % t.person_name))


## A werewolf comes out of the wood (at night).
func start_werewolf() -> Node2D:
	var wolf: Node2D = _add(Raider, Vector2(SbData.EAST_EDGE - 5, 30))
	wolf.setup(true)
	raiders.append(wolf)
	raid_on = true
	sound("lost")
	announce("A howl from the wood: a werewolf is coming!")
	for p in peasants:
		p.rethink()
	return wolf


func start_fire(host: Node2D = null, message := "") -> void:
	if host == null:
		var hosts: Array = [stockyard]
		for s in sites:
			if s.placed > 0:
				hosts.append(s)
		host = hosts.pick_random()
	var f: Node2D = _add(Fire, host.position + Vector2(randf_range(-8, 8), 3))
	f.setup(host)
	fires.append(f)
	announce(message if message != "" else "Fire at %s!" % host.label())
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
	_redraw_peasants()
	selection_changed.emit()


## Peasants draw their own marks; while paused they don't redraw by themselves.
func _redraw_peasants() -> void:
	for p in peasants:
		p.queue_redraw()


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
	for r in rocks:
		if r.trapped != null and r.hit(at):
			return {"kind": "rescue", "target": r}
	for s in sites:
		if s.is_workshop() and s.hit(at):
			return {"kind": "craft", "target": s}
	for list_kind in [[deer, "hunt"], [raiders, "fight"], [fires, "firefight"], [items, "haul"], [trees, "chop"], [rocks, "mine"], [bushes, "forage"], [sites, "build"]]:
		for t in list_kind[0]:
			if t.is_open() and t.hit(at):
				return {"kind": list_kind[1], "target": t}
	at.y = clampf(at.y, SbData.WALK_TOP, SbData.WALK_BOTTOM)
	return {"kind": "goto", "target": null, "pos": at}


## Forbids or allows the thing under the mouse (X).
func toggle_forbid(at: Vector2) -> void:
	var o := order_at(at)
	var t = o.get("target")
	if t == null or t.kind == "raider" or t.kind == "fire" or t.kind == "peasant":
		return
	t.forbidden = not t.forbidden
	announce("%s is %s." % [t.label().capitalize(), "forbidden" if t.forbidden else "allowed again"])


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
	_redraw_peasants()
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
	_redraw_peasants()
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
			if mb.pressed and mb.double_click:
				# Double-click: everyone with the same job.
				var q := peasant_at(at)
				if q != null:
					select(peasants.filter(func(o): return o.job == q.job and not o.downed))
				_drag_from = Vector2.INF
				return
			if mb.pressed:
				_drag_from = at
			elif _drag_from != Vector2.INF:
				var rect := Rect2(_drag_from, at - _drag_from).abs()
				if rect.size.length() < 4.0:
					var p := peasant_at(at)
					if p != null and p.dozing > 0.0:
						# A click on someone dozing wakes them (and selects them).
						p.wake()
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
			KEY_SPACE:
				toggle_pause()
			KEY_L:
				set_alarm(not alarm)
			KEY_J:
				hud.toggle_log()
			KEY_X:
				toggle_forbid(get_global_mouse_position())
			KEY_A when (event as InputEventKey).ctrl_pressed:
				select(peasants.filter(func(o): return not o.downed))
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
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				set_job_selected(SbData.JOB_ORDER[(event as InputEventKey).keycode - KEY_1])


## The hour of the day, 0-24 (the first day starts at 08:00).
func hour() -> float:
	return fmod(time / SbData.DAY_LENGTH * 24.0 + 8.0, 24.0)


func day() -> int:
	return int((time / SbData.DAY_LENGTH * 24.0 + 8.0) / 24.0) + 1


func is_night() -> bool:
	var h := hour()
	return h >= SbData.NIGHT_FROM or h < SbData.NIGHT_TO


func set_alarm(on: bool) -> void:
	alarm = on
	announce("The alarm bell rings: everyone into the castle!" if on else "All clear: back to work.")
	for p in peasants:
		p.rethink()


func set_child_labour(on: bool) -> void:
	child_labour = on
	for p in peasants:
		if p.child:
			p._set_child_prio()
			p.rethink()
	announce("Child labour: " + ("children haul and pick berries at half pace." if on else "children play."))


## At dawn, maybe a child is born to a couple (while the Huts have room).
func _maybe_birth() -> void:
	if calm:
		return
	var huts := sites.filter(func(s): return s.has_beds()).size()
	var kids := peasants.filter(func(p): return p.child).size()
	if kids >= huts or randf() >= SbData.BIRTH_CHANCE:
		return
	birth()


## A child is born to two grown-ups (picked at random).
func birth() -> Node2D:
	var adults: Array = peasants.filter(func(p): return not p.child and not p.downed)
	if adults.size() < 2:
		return null
	adults.shuffle()
	var used := peasants.map(func(p): return p.person_name)
	var free: Array = SbData.NAMES.filter(func(n): return not used.has(n))
	var name_: String = free.pick_random() if not free.is_empty() else "Child %d" % (peasants.size() + 1)
	var kid: Node2D = _add(Peasant, adults[0].position + Vector2(-8, 4))
	kid.setup(name_, "hauler")
	kid.make_child([adults[0], adults[1]])
	peasants.append(kid)
	for p in peasants:
		p.remember("new_child")
	announce("A child, %s, is born to %s and %s." % [name_, adults[0].person_name, adults[1].person_name])
	traveller_changed.emit()
	return kid


func set_night_work(on: bool) -> void:
	night_work = on
	announce("Night work: " + ("everyone works through the night." if on else "everyone sleeps at night."))
	for p in peasants:
		p.rethink()


## How dark it is: 0 by day, 1 deep in the night, with an hour of dusk and dawn.
func darkness() -> float:
	var h := hour()
	if h >= SbData.NIGHT_FROM or h < SbData.NIGHT_TO:
		return 1.0
	if h >= SbData.NIGHT_FROM - 1.5:
		return (h - (SbData.NIGHT_FROM - 1.5)) / 1.5
	if h < SbData.NIGHT_TO + 1.5:
		return 1.0 - (h - SbData.NIGHT_TO) / 1.5
	return 0.0


## Panning, the order pings and the overlay: these go on while paused.
func _camera_and_overlay(delta: float) -> void:
	var pan := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A) and not Input.is_key_pressed(KEY_CTRL):
		pan -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan += 1.0
	camera.position.x = clampf(camera.position.x + pan * 220.0 * delta / camera.zoom.x, SbData.WEST_EDGE, SbData.EAST_EDGE)
	for ping in _pings:
		ping.t -= delta
	_pings = _pings.filter(func(pg): return pg.t > 0.0)
	overlay.queue_redraw()


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused


func _process(delta: float) -> void:
	_camera_and_overlay(delta)
	if get_tree().paused:
		return
	time += delta
	for l in _lanterns:
		l.visible = darkness() > 0.05
	_check_strike(delta)
	_update_storm(delta)
	if traitor != null and traitor.task.get("kind", "") == "steal" and traitor._goods():
		for p in peasants:
			if p != traitor and not p.downed and p.visible and (p.job == "guard" or p.drafted) and p.position.distance_to(traitor.position) < SbData.CATCH_RANGE:
				catch_traitor(p)
				break
	# Dawn: maybe a birth. Children grow up.
	var h := hour()
	if _last_hour < SbData.NIGHT_TO and h >= SbData.NIGHT_TO:
		_maybe_birth()
		_morning_clue()
		if not calm and day() >= SbData.STORM_FIRST_DAY and randf() < SbData.STORM_CHANCE:
			_storm_at = time + randf_range(0.1, 0.5) * SbData.DAY_LENGTH
		if traitor == null and not calm and day() >= SbData.TRAITOR_DAY and randf() < 0.5:
			var suspects: Array = peasants.filter(func(p): return not p.child and p.job != "guard")
			if not suspects.is_empty():
				traitor = suspects.pick_random()
	if auto_raids and _last_hour < SbData.NIGHT_FROM + 1.0 and h >= SbData.NIGHT_FROM + 1.0 and day() >= SbData.WOLF_FIRST_DAY and randf() < SbData.WOLF_CHANCE:
		start_werewolf()
	_last_hour = h
	for p in peasants:
		if p.child and time - p.born >= SbData.CHILD_DAYS * SbData.DAY_LENGTH:
			p.grow_up()
			traveller_changed.emit()
	if auto_raids and time >= next_traveller:
		next_traveller += SbData.TRAVELLER_EVERY * SbData.DAY_LENGTH
		if traveller == null and question.is_empty():
			arrive_traveller()
	if auto_raids and time >= next_stranger:
		next_stranger += SbData.STRANGER_EVERY * SbData.DAY_LENGTH
		if question.is_empty():
			arrive_stranger()
	if _price_at >= 0.0 and time >= _price_at:
		_price_at = -1.0
		pay_price()
	if auto_raids and time >= next_raid:
		next_raid += SbData.RAID_EVERY * SbData.DAY_LENGTH
		start_raid(SbData.RAID_BASE + raids)
	# The herd grows back slowly, from the east edge of the wood.
	if deer.size() < HERD:
		_herd_timer += delta
		if _herd_timer >= HERD_GROWS:
			_herd_timer = 0.0
			_add_deer(Vector2(SbData.EAST_EDGE - 10, randf_range(10, 70)))
	var tint := Color.WHITE.lerp(SbData.NIGHT_TINT, darkness())
	if storm > 0.0:
		tint *= SbData.STORM_TINT
	if _flash > 0.0:
		tint = tint.lerp(Color(1.6, 1.6, 1.8), _flash)
	_tint.color = tint



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
	if storm > 0.0:
		_draw_rain()
	# Forbidden things: a red cross over them.
	for list in [trees, rocks, bushes, items, sites]:
		for t in list:
			if t.forbidden:
				var c: Vector2 = t.position + Vector2(0, -14)
				overlay.draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), SbData.RED1, 2.0)
				overlay.draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), SbData.RED1, 2.0)
	if placing != "":
		_draw_ghost(get_global_mouse_position())
	else:
		_draw_hint(get_global_mouse_position())
	for ping in _pings:
		var r: float = 3.0 + (0.6 - ping.t) * 14.0
		overlay.draw_arc(ping.pos, r, 0, TAU, 12, Color(SbData.GOLD, ping.t / 0.6), 1.0)


const ORDER_WORDS := {
	"fight": "Fight %s", "firefight": "Put out %s", "haul": "Haul %s", "chop": "Chop %s",
	"mine": "Mine %s", "forage": "Pick %s", "build": "Build %s", "rescue": "Rescue %s",
	"craft": "Work at %s", "hunt": "Hunt %s",
}


## Rain over the visible part of the world: short slanted streaks.
func _draw_rain() -> void:
	var half := get_viewport_rect().size / 2.0 / camera.zoom
	var t := Time.get_ticks_msec() / 1000.0
	var c := Color(SbData.SKY3, 0.45)
	for i in 140:
		var x := camera.position.x - half.x + fmod(float(i) * 37.7 + t * 40.0, half.x * 2.0)
		var y := camera.position.y - half.y + fmod(float(i) * 23.3 + t * 260.0, half.y * 2.0)
		overlay.draw_line(Vector2(x, y), Vector2(x - 2, y + 6), c, 1.0)


## Under the mouse: with peasants selected, what a right-click would order;
## over a peasant, their name, job and what they are doing.
func _draw_hint(at: Vector2) -> void:
	var text := ""
	var p := peasant_at(at)
	if p != null and not (p.is_open() and not selected.is_empty()):
		text = "%s, %s: %s" % [p.person_name, p.job_name(), p.activity().to_lower()]
	elif selected.is_empty():
		var t := thing_at(at)
		if t != null:
			text = t.describe()
	else:
		var o := order_at(at)
		if o.kind == "goto":
			text = "Go here" + (" and hold" if selected.any(func(s): return s.drafted) else "")
		else:
			text = ORDER_WORDS[o.kind] % o.target.label()
		if Input.is_key_pressed(KEY_SHIFT):
			text += " (after the rest)"
	if text == "":
		return
	var font := ThemeDB.fallback_font
	var size := 8
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at + Vector2(8, -6) / camera.zoom
	overlay.draw_set_transform(pos, 0.0, Vector2.ONE / camera.zoom)
	overlay.draw_rect(Rect2(-2, -8, w + 4, 11), Color(SbData.INK, 0.8))
	overlay.draw_string(font, Vector2(0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SbData.WHITE)
	overlay.draw_set_transform(Vector2.ZERO)


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
