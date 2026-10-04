extends Node2D
## The row of trees. Keeps one tree node per tree counted in GameState.

const TreeSpot = preload("res://scripts/tree.gd")

## The first tree stands nearest the stockhouse; later ones are a longer walk.
@export var first_x := 762.0
@export var spacing := 14.0


func _ready() -> void:
	GameState.trees_changed.connect(_sync.bind(true))
	_sync(false)


## The grown tree with the most wood left, or null if none can be chopped.
func best_tree() -> Node2D:
	var best: Node2D = null
	for tree in get_children():
		if tree.can_gather() and (best == null or tree.wood_left > best.wood_left):
			best = tree
	return best


## Where tree number index stands (0 = the first tree).
func plot_x(index: int) -> float:
	return first_x + spacing * index


func _sync(as_sapling: bool) -> void:
	while get_child_count() < GameState.trees:
		var tree := TreeSpot.new()
		tree.position.x = plot_x(get_child_count())
		if as_sapling:
			tree.start_as_sapling()
		add_child(tree)
