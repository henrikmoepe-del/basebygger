extends Node2D
## Keeps one walking peasant on screen for every peasant in GameState, each
## running the script for their job, and draws the stockhouse. Peasants ask
## this node where things are (gather spots, the building site).

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
## One piece appears in a pile for every PILE_UNIT, then 4x, 9x, 16x that...
const PILE_UNIT := 6.0
const MAX_PILE_PIECES := 6
const FLOAT_TIME := 1.2
const MAX_FLOATS := 12
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
@export var stock_x := 170.0

## Numbers floating up from the stockhouse as loads arrive:
## each is {"text": String, "color": Color, "age": float, "x": float}.
var _floats: Array[Dictionary] = []
var _font: Font = ThemeDB.fallback_font
## Seconds left of the stockhouse's little bump when a load arrives.
var _bump := 0.0


func _ready() -> void:
	GameState.castle_changed.connect(_sync)
	GameState.peasants_changed.connect(_sync)
	GameState.income_delivered.connect(_on_income_delivered)
	GameState.resources_changed.connect(queue_redraw)
	_sync()


func _draw() -> void:
	_draw_piles()
	# The stockhouse: everything gathered is stored here. It swells for a
	# moment each time a load comes in.
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
	_floats.append({"text": "+%d" % amount, "color": FLOAT_COLORS[type], "age": 0.0, "x": stock_x + randf_range(-10.0, 4.0)})
	queue_redraw()


## Logs and stone blocks stacked beside the stockhouse, so the stores can be
## seen at a glance. The piles grow slowly: each row needs more than the last.
func _draw_piles() -> void:
	_draw_pile(stock_x + 20.0, GameState.resources.wood, Vector2(7, 3), Color(0.52, 0.36, 0.22))
	_draw_pile(stock_x - 34.0, GameState.resources.stone, Vector2(5, 4), Color(0.66, 0.66, 0.70))


func _draw_pile(left: float, amount: int, piece: Vector2, color: Color) -> void:
	var pieces := mini(int(sqrt(amount / PILE_UNIT)), MAX_PILE_PIECES)
	var row := 0
	var in_row := 0
	var row_size := 3
	for i in pieces:
		var x := left + in_row * (piece.x + 1) + row * (piece.x + 1) * 0.5
		var y := -(row + 1) * piece.y
		draw_rect(Rect2(x, y, piece.x, piece.y - 1), color if (i + row) % 2 == 0 else color.darkened(0.12))
		in_row += 1
		if in_row >= row_size - row:
			in_row = 0
			row += 1
			if row >= row_size:
				break


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


## The height of the top of the castle walls, where soldiers stand (negative = up).
func wall_top_y() -> float:
	return CastleData.top_y("walls", GameState.part_levels.walls)


## Where the cooks stand.
func kitchen_x() -> float:
	return stock_x - 24.0


## Where builders stand to work on the current job.
func site_x() -> float:
	return castle.position.x + CastleData.PARTS[GameState.job_part].site_x


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
		# Soldiers spread out along the wall, clear of the gate in the middle.
		var side := -1.0 if randf() < 0.5 else 1.0
		worker.home_x = castle.position.x + side * randf_range(26.0, 96.0)
	elif job == "build":
		# Builders wait between the castle and the stockhouse.
		worker.home_x = castle.position.x + 132.0 + randf_range(0.0, 20.0)
	elif job == "":
		worker.home_x = stock_x + randf_range(-12.0, 12.0)
	else:
		worker.home_x = stock_x + randf_range(-6.0, 6.0)
	# Everyone comes out of the stockhouse.
	worker.position.x = stock_x
	add_child(worker)
	return worker
