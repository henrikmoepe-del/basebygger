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
## Which script runs each job ("" = idle).
const JOB_SCRIPTS := {
	"": Worker, "wood": Gatherer, "stone": Gatherer, "hunter": Gatherer,
	"build": Builder, "forester": Forester, "cook": Cook, "soldier": Soldier,
}

@export var grove: Node2D
@export var rock: Node2D
@export var wilds: Node2D
@export var castle: Node2D
@export var stock_x := 215.0


func _ready() -> void:
	GameState.peasants_changed.connect(_sync)
	_sync()


func _draw() -> void:
	# The stockhouse: everything gathered is stored here.
	draw_rect(Rect2(stock_x - 14, -18, 28, 18), Color(0.48, 0.32, 0.20))
	draw_rect(Rect2(stock_x - 17, -24, 34, 7), Color(0.33, 0.21, 0.13))
	draw_rect(Rect2(stock_x - 4, -11, 8, 11), Color(0.20, 0.13, 0.08))
	if GameState.jobs.cook > 0:
		# The cooking pot over a fire.
		var x := kitchen_x()
		draw_rect(Rect2(x - 4, -8, 8, 5), Color(0.22, 0.23, 0.27))
		draw_rect(Rect2(x - 3, -3, 6, 3), Color(0.95, 0.55, 0.15))


## Where a gatherer should go for this resource right now (null = nowhere).
func find_spot(resource_type: String) -> Node2D:
	match resource_type:
		"wood":
			return grove.best_tree()
		"food":
			return wilds
	return rock


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
	for job: String in JOB_SCRIPTS:
		var wanted: int = GameState.idle_peasants() if job == "" else GameState.jobs[job]
		var current := get_children().filter(func(w: Node) -> bool: return w.job == job and not w.is_queued_for_deletion())
		while current.size() > wanted:
			current.pop_back().queue_free()
		for i in wanted - current.size():
			current.append(_spawn(job))
		# The first peasants in each job are the trained ones.
		for i in current.size():
			current[i].trained = job != "" and i < GameState.trained[job]


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
		# Builders wait in front of the castle.
		worker.home_x = castle.position.x - 140.0 + randf_range(0.0, 60.0)
	elif job == "":
		worker.home_x = stock_x + randf_range(-12.0, 12.0)
	else:
		worker.home_x = stock_x + randf_range(-6.0, 6.0)
	# Everyone comes out of the stockhouse.
	worker.position.x = stock_x
	add_child(worker)
	return worker
