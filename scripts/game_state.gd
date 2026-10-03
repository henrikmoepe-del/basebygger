extends Node
## Global game data (autoload). Scenes read and change the game through this,
## so the 2D builder and the later 3D mode can share the same state.

signal resources_changed
signal castle_changed

const CastleData = preload("res://scripts/castle_data.gd")

var resources := {"wood": 0, "stone": 0}
## How many castle pieces are built, in CastleData.PIECES order.
var built_count := 0


func add_resource(type: String, amount: int) -> void:
	resources[type] += amount
	resources_changed.emit()


func can_afford(cost: Dictionary) -> bool:
	for type: String in cost:
		if resources[type] < cost[type]:
			return false
	return true


## The next piece to build, or an empty Dictionary when the castle is done.
func next_piece() -> Dictionary:
	if built_count >= CastleData.PIECES.size():
		return {}
	return CastleData.PIECES[built_count]


func build_next() -> bool:
	var piece := next_piece()
	if piece.is_empty() or not can_afford(piece.cost):
		return false
	for type: String in piece.cost:
		resources[type] -= piece.cost[type]
	built_count += 1
	resources_changed.emit()
	castle_changed.emit()
	return true


## Sum of the defence of every built piece. The 3D mode will use this.
func total_defence() -> int:
	var total := 0
	for i in built_count:
		total += CastleData.PIECES[i].defence
	return total
