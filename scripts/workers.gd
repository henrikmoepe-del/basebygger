extends Node2D
## Keeps one walking peasant on screen for every peasant in GameState, each
## running the script for their job, and draws the stockyard: a shed with a
## store for each resource beside it (STORES), so what is in stock can be
## seen. Each store is a stack that grows with the amount, under a number. Peasants ask
## this node where things are (gather spots, guard posts, beds).
## This node and the castle share the same origin: the castle's ground-centre.

const CastleData = preload("res://scripts/castle_data.gd")
const Worker = preload("res://scripts/worker.gd")
const Gatherer = preload("res://scripts/gatherer.gd")
const Builder = preload("res://scripts/builder.gd")
const Forester = preload("res://scripts/forester.gd")
const Cook = preload("res://scripts/cook.gd")
const Soldier = preload("res://scripts/soldier.gd")
const Cow = preload("res://scripts/cow.gd")
## Which script runs each job ("" = idle).
const BUMP_TIME := 0.15
## The stores of the stockyard. "x" is where the stack starts, east of the
## shed's middle (stock_x); "piece" is the size of one log, block, sack or
## ingot; "per_row" how many lie side by side; "rows" how high the stack can
## get. The stack holds STACK_GROWTH x the square root of the amount, so it
## grows quickly at first and never stops being readable.
const STORES := {
	"iron": {"x": -72.0, "piece": Vector2(4, 2), "per_row": 3, "rows": 6, "color": Color(0.36, 0.38, 0.46)},
	"stone": {"x": -52.0, "piece": Vector2(5, 4), "per_row": 6, "rows": 9, "color": Color(0.66, 0.66, 0.70)},
	"wood": {"x": 20.0, "piece": Vector2(7, 3), "per_row": 5, "rows": 12, "color": Color(0.52, 0.36, 0.22)},
	"food": {"x": 66.0, "piece": Vector2(4, 5), "per_row": 5, "rows": 5, "color": Color(0.82, 0.74, 0.52)},
}
const STACK_GROWTH := 1.5
const POST := Color(0.33, 0.21, 0.13)
const NUMBER := Color(0.20, 0.17, 0.15)
const SKIN := Color(0.93, 0.76, 0.62)
const FLOAT_TIME := 1.2
const MAX_FLOATS := 12
## Idle peasants stroll on floors no further than this from the castle's middle.
const STROLL_REACH := 440.0
const FLOAT_COLORS := {
	"wood": Color(0.40, 0.26, 0.15), "stone": Color(0.36, 0.38, 0.46),
	"food": Color(0.70, 0.20, 0.25), "iron": Color(0.20, 0.22, 0.30),
}
const JOB_SCRIPTS := {
	"": Worker, "wood": Gatherer, "stone": Gatherer, "hunter": Gatherer, "iron": Gatherer,
	"build": Builder, "forester": Forester, "cook": Cook, "soldier": Soldier,
}

@export var grove: Node2D
@export var rock: Node2D
@export var wilds: Node2D
@export var mine: Node2D
@export var castle: Node2D
@export var stock_x := 550.0

## Numbers floating up from the stockhouse as loads arrive:
## each is {"text": String, "color": Color, "age": float, "x": float}.
var _floats: Array[Dictionary] = []
var _font: Font = ThemeDB.fallback_font
## Seconds left of the stockhouse's little bump when a load arrives.
var _bump := 0.0
## Draws peasants who are on the stairs inside a building, where they pass a window.
var _inside_view := Node2D.new()


func _ready() -> void:
	# Over the courtyard buildings, under everyone who is outside.
	_inside_view.z_index = castle.FRONT_Z
	_inside_view.draw.connect(_draw_inside)
	add_child(_inside_view)
	GameState.castle_changed.connect(_sync)
	GameState.peasants_changed.connect(_sync)
	GameState.income_delivered.connect(_on_income_delivered)
	GameState.resources_changed.connect(queue_redraw)
	_sync()


func _draw() -> void:
	for type: String in STORES:
		# Iron only has a place once there is a mine.
		if type != "iron" or GameState.part_levels.mine > 0:
			_draw_store(type)
	# The shed, for tools and everything small. It swells for a moment each
	# time a load comes in.
	var swell := 2.0 * maxf(_bump, 0.0) / BUMP_TIME
	draw_rect(Rect2(stock_x - 14 - swell, -18 - swell, 28 + swell * 2, 18 + swell), Color(0.48, 0.32, 0.20))
	draw_rect(Rect2(stock_x - 17 - swell, -24 - swell, 34 + swell * 2, 7), Color(0.33, 0.21, 0.13))
	draw_rect(Rect2(stock_x - 4, -11, 8, 11), Color(0.20, 0.13, 0.08))
	for number in _floats:
		var fade: float = 1.0 - number.age / FLOAT_TIME
		draw_string(_font, Vector2(number.x, -28.0 - number.age * 14.0), number.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(number.color, fade))
	if GameState.jobs.cook > 0:
		# The cooking pot over a fire.
		var x := kitchen_x()
		draw_rect(Rect2(x - 4, -8, 8, 5), Color(0.22, 0.23, 0.27))
		draw_rect(Rect2(x - 3, -3, 6, 3), Color(0.95, 0.55, 0.15))


func _process(delta: float) -> void:
	_inside_view.queue_redraw()
	if _bump > 0.0:
		_bump -= delta
		queue_redraw()
	if _floats.is_empty():
		return
	for number in _floats:
		number.age += delta
	_floats = _floats.filter(func(number: Dictionary) -> bool: return number.age < FLOAT_TIME)
	queue_redraw()


func _on_income_delivered(type: String, amount: int) -> void:
	if amount <= 0 or _floats.size() >= MAX_FLOATS:
		return
	_bump = BUMP_TIME
	_floats.append({"text": "+%d" % amount, "color": FLOAT_COLORS[type], "age": 0.0, "x": store_x(type) + randf_range(-10.0, 4.0)})
	queue_redraw()


## One store: two posts that mark its place, the stack between them, and the
## amount written above. Food is kept dry under a little roof.
func _draw_store(type: String) -> void:
	var store: Dictionary = STORES[type]
	var piece: Vector2 = store.piece
	var left: float = stock_x + store.x
	var width: float = store.per_row * (piece.x + 1.0)
	var full: float = store.rows * piece.y
	var amount: int = GameState.resources[type]
	var pieces := mini(int(sqrt(amount) * STACK_GROWTH), store.per_row * store.rows)
	draw_rect(Rect2(left - 2, -full - 2, 1, full + 2), POST)
	draw_rect(Rect2(left + width, -full - 2, 1, full + 2), POST)
	for i in pieces:
		var row: int = i / store.per_row
		var column: int = i % store.per_row
		var color: Color = store.color if (row + column) % 2 == 0 else store.color.darkened(0.12)
		draw_rect(Rect2(left + column * (piece.x + 1.0), -(row + 1) * piece.y, piece.x, piece.y - 1.0), color)
	if type == "food":
		draw_rect(Rect2(left - 4, -full - 6, width + 7, 4), CastleData.THATCH)
	var text := str(amount)
	var text_width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(_font, Vector2(left + (width - text_width) / 2.0, -full - 9.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, NUMBER)


## Peasants climbing the stairs inside a building show through its windows:
## the part of each that is behind a window is drawn there.
func _draw_inside() -> void:
	var windows: Array[Rect2] = castle.windows()
	for worker in get_children():
		if not worker.has_method("is_inside") or not worker.is_inside() or worker.position.y > -0.5:
			continue
		var at: Vector2 = worker.position
		for window in windows:
			if absf(window.get_center().x - at.x) > 12.0:
				continue
			var body := Rect2(at.x - 3, at.y - 12, 6, 10).intersection(window)
			if body.has_area():
				_inside_view.draw_rect(body, worker.tunic())
			var head := Rect2(at.x - 2, at.y - 16, 4, 4).intersection(window)
			if head.has_area():
				_inside_view.draw_rect(head, SKIN)


## Where a gatherer should go for this resource right now (null = nowhere).
func find_spot(resource_type: String) -> Node2D:
	match resource_type:
		"wood":
			return grove.best_tree()
		"food":
			return wilds
		"iron":
			return mine
	return rock


## A cow waiting with room in its cart for this resource, or null.
func cow_for(resource_type: String) -> Node2D:
	for child in get_children():
		if child is Cow and child.resource == resource_type and child.has_room():
			return child
	return null


## Where a cow waits for a resource: at the far end of that walk.
func cow_site_x(resource_type: String) -> float:
	match resource_type:
		"wood":
			return grove.plot_x(mini(GameState.trees, 4)) + 4.0
		"food":
			return wilds.position.x - 30.0
		"iron":
			return mine.position.x + 22.0
	return rock.position.x + 30.0


## Where a soldier stands watch: a spot on one of the castle's floors. beat
## (0 to 1) picks the floor, so a soldier keeps to the same one; wide floors
## like the wall walk get more soldiers than a tower top.
func guard_post(beat: float, fallback_x: float) -> Vector2:
	var flats: Array = castle.built_floors()
	var total := 0.0
	for flat: Dictionary in flats:
		total += flat.x1 - flat.x0
	var along := beat * total
	for flat: Dictionary in flats:
		along -= flat.x1 - flat.x0
		if along <= 0.0:
			return Vector2(randf_range(flat.x0 + 4.0, flat.x1 - 4.0), flat.y)
	return Vector2(fallback_x, 0)


## Somewhere for an idle peasant to wander to: near home, across the
## courtyard, or up on the castle.
func stroll_spot(home_x: float) -> Vector2:
	var flats: Array = castle.built_floors().filter(func(flat: Dictionary) -> bool: return absf(flat.x0) < STROLL_REACH)
	var roll := randf()
	if flats.is_empty() or roll < 0.4:
		return Vector2(home_x + randf_range(-30.0, 30.0), 0)
	if roll < 0.7:
		return Vector2(randf_range(-CastleData.WALL_HALF + 20.0, CastleData.WALL_HALF - 20.0), 0)
	var flat: Dictionary = flats.pick_random()
	return Vector2(randf_range(flat.x0 + 4.0, flat.x1 - 4.0), flat.y)


## The door nearest to x where a peasant can sleep: the stockhouse, or any
## building of the castle or village that has one.
func bed_x(x: float) -> float:
	var nearest := stock_x
	for part: String in GameState.part_levels:
		for door: float in CastleData.doors(part, GameState.part_levels[part]):
			if absf(door - x) < absf(nearest - x):
				nearest = door
	return nearest


## How many builders other than this one are working at the top of the site.
func builders_aloft(except: Node) -> int:
	return _builders(except).filter(func(b: Node) -> bool: return b.is_top_crew()).size()


## How many builders other than this one are shaping a piece at a bench.
func builders_forming(except: Node) -> int:
	return _builders(except).filter(func(b: Node) -> bool: return b.is_forming()).size()


## How many builders other than this one are on their way to pick up a piece to place.
func builders_picking(except: Node) -> int:
	return _builders(except).filter(func(b: Node) -> bool: return b.is_picking()).size()


## True if a builder other than this one is at the rope.
func hoist_manned(except: Node) -> bool:
	return _builders(except).any(func(b: Node) -> bool: return b.is_hoisting())


func _builders(except: Node) -> Array:
	return get_children().filter(func(w: Node) -> bool: return w is Builder and w != except and not w.is_queued_for_deletion())


## Where the cooks stand: by the food store.
func kitchen_x() -> float:
	return stock_x + STORES.food.x + 40.0


## Where a peasant stands to add to or take from a resource's store.
## Anything without a store of its own is kept in the shed.
func store_x(resource_type: String) -> float:
	if not STORES.has(resource_type):
		return stock_x
	var store: Dictionary = STORES[resource_type]
	return stock_x + store.x + store.per_row * (store.piece.x + 1.0) / 2.0


## Adds and removes peasant nodes until each job has the right number.
func _sync() -> void:
	queue_redraw()
	_sync_cows()
	for job: String in JOB_SCRIPTS:
		var wanted: int = GameState.idle_peasants() if job == "" else GameState.jobs[job]
		var current := get_children().filter(func(w: Node) -> bool: return w.get("job") == job and not w.is_queued_for_deletion())
		while current.size() > wanted:
			current.pop_back().queue_free()
		for i in wanted - current.size():
			current.append(_spawn(job))
		# The first peasants in each job are the trained ones.
		for i in current.size():
			current[i].trained = job != "" and i < GameState.trained[job]


## Cows share out the hauls in turn: food first (the longest walk), then
## wood, stone, and iron once there is a mine.
func _sync_cows() -> void:
	var hauls := ["food", "wood", "stone"]
	if GameState.part_levels.mine > 0:
		hauls.append("iron")
	var cows := get_children().filter(func(c: Node) -> bool: return c is Cow)
	for i in GameState.cows - cows.size():
		var cow := Cow.new()
		cow.world = self
		cow.position.x = stock_x
		add_child(cow)
		cows.append(cow)
	for i in cows.size():
		cows[i].resource = hauls[i % hauls.size()]


func _spawn(job: String) -> Node2D:
	var worker: Node2D = JOB_SCRIPTS[job].new()
	worker.job = job
	worker.world = self
	worker.speed *= randf_range(0.9, 1.1)
	if job == "soldier":
		# Until there is somewhere to stand watch, soldiers wait by the gate.
		worker.home_x = randf_range(40.0, 160.0)
	elif job == "build":
		# Builders wait between the castle and the stockhouse.
		worker.home_x = stock_x - 40.0 + randf_range(-10.0, 10.0)
	elif job == "":
		worker.home_x = stock_x + randf_range(-12.0, 12.0)
	else:
		worker.home_x = stock_x + randf_range(-6.0, 6.0)
	# Everyone comes out of the stockhouse.
	worker.position.x = stock_x
	add_child(worker)
	return worker
