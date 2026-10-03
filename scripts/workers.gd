extends Node2D
## Keeps one walking peasant on screen for every peasant in GameState, each
## running the script for their job, and draws the stockhouse. Peasants ask
## this node where things are (gather spots, the building site).

const CastleData = preload("res://scripts/castle_data.gd")
const Worker = preload("res://scripts/worker.gd")
const Gatherer = preload("res://scripts/gatherer.gd")
const Builder = preload("res://scripts/builder.gd")
const Forester = preload("res://scripts/forester.gd")
## Which script runs each job ("" = idle).
const JOB_SCRIPTS := {"": Worker, "wood": Gatherer, "stone": Gatherer, "build": Builder, "forester": Forester}

@export var grove: Node2D
@export var rock: Node2D
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


## Where a gatherer should go for this resource right now (null = nowhere).
func find_spot(resource_type: String) -> Node2D:
	if resource_type == "wood":
		return grove.best_tree()
	return rock


## Where builders stand to work on the current job.
func site_x() -> float:
	return castle.position.x + CastleData.PARTS[GameState.job_part].site_x


## Adds and removes peasant nodes until each job has the right number.
func _sync() -> void:
	for job: String in JOB_SCRIPTS:
		var wanted: int = GameState.idle_peasants() if job == "" else GameState.jobs[job]
		var current := get_children().filter(func(w: Node) -> bool: return w.job == job and not w.is_queued_for_deletion())
		while current.size() > wanted:
			current.pop_back().queue_free()
		for i in wanted - current.size():
			_spawn(job)


func _spawn(job: String) -> void:
	var worker: Node2D = JOB_SCRIPTS[job].new()
	worker.job = job
	worker.world = self
	worker.speed *= randf_range(0.9, 1.1)
	if job == "build":
		# Builders wait in front of the castle.
		worker.home_x = castle.position.x - 140.0 + randf_range(0.0, 60.0)
	elif job == "":
		worker.home_x = stock_x - 24.0 + randf_range(-12.0, 4.0)
	else:
		worker.home_x = stock_x + randf_range(-6.0, 6.0)
	# Everyone comes out of the stockhouse.
	worker.position.x = stock_x
	add_child(worker)
