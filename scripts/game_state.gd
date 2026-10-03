extends Node
## Global game data (autoload). Scenes read and change the game through this,
## so the 2D builder and the later 3D mode can share the same state.

signal resources_changed
signal castle_changed
signal build_progress_changed
signal peasants_changed
signal trees_changed
signal builders_changed
signal upgrades_changed

const CastleData = preload("res://scripts/castle_data.gd")
const PEASANT_BASE_COST := 10
const PEASANT_COST_GROWTH := 1.5
const START_TREES := 2
const MAX_TREES := 8
const TREE_BASE_COST := 8
const TREE_COST_GROWTH := 1.6
const START_BUILDERS := 1
const BUILDER_BASE_COST := 20
const BUILDER_COST_GROWTH := 1.7

## Upgrades can be bought again and again; each level costs "growth" times more.
const UPGRADES := {
	"peasant_speed": {"name": "Faster Peasants", "cost": {"wood": 20}, "growth": 1.8},
	"carry": {"name": "Bigger Baskets", "cost": {"wood": 25, "stone": 25}, "growth": 2.0},
	"builder_speed": {"name": "Better Hammers", "cost": {"stone": 30}, "growth": 1.8},
}

var resources := {"wood": 0, "stone": 0}
## How many castle pieces are finished, in CastleData.PIECES order.
var built_count := 0
## True while the next piece is paid for and under construction.
var building := false
## Seconds of builder work done on the piece under construction.
var build_progress := 0.0
var peasants := 0
var trees := START_TREES
var builders := START_BUILDERS
var upgrades := {"peasant_speed": 0, "carry": 0, "builder_speed": 0}


func _process(delta: float) -> void:
	if building:
		_advance_build(build_rate() * delta)


func add_resource(type: String, amount: int) -> void:
	resources[type] += amount
	resources_changed.emit()


func can_afford(cost: Dictionary) -> bool:
	for type: String in cost:
		if resources[type] < cost[type]:
			return false
	return true


## Pays the cost if affordable. Returns false (and takes nothing) if not.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for type: String in cost:
		resources[type] -= cost[type]
	resources_changed.emit()
	return true


# --- Castle ---

## The next piece to build (or being built), or an empty Dictionary when the castle is done.
func next_piece() -> Dictionary:
	if built_count >= CastleData.PIECES.size():
		return {}
	return CastleData.PIECES[built_count]


## Pays for the next piece and puts the builders to work on it.
func start_build() -> bool:
	var piece := next_piece()
	if building or piece.is_empty() or not spend(piece.cost):
		return false
	building = true
	build_progress = 0.0
	castle_changed.emit()
	return true


## Work done per second by all builders together.
func build_rate() -> float:
	return builders * (1.0 + 0.25 * upgrades.builder_speed)


## How far along the current piece is, from 0 to 1.
func build_fraction() -> float:
	if not building:
		return 0.0
	return clampf(build_progress / next_piece().work, 0.0, 1.0)


## Sum of the defence of every finished piece. The 3D mode will use this.
func total_defence() -> int:
	var total := 0
	for i in built_count:
		total += CastleData.PIECES[i].defence
	return total


func _advance_build(work: float) -> void:
	build_progress += work
	if build_progress >= next_piece().work:
		building = false
		build_progress = 0.0
		built_count += 1
		castle_changed.emit()
	build_progress_changed.emit()


# --- Things to buy ---

## Each peasant costs more than the last (the classic incremental curve).
func peasant_cost() -> Dictionary:
	return {"wood": ceili(PEASANT_BASE_COST * pow(PEASANT_COST_GROWTH, peasants))}


func hire_peasant() -> bool:
	if not spend(peasant_cost()):
		return false
	peasants += 1
	peasants_changed.emit()
	return true


## Cost of the next tree, or an empty Dictionary when the grove is full.
func tree_cost() -> Dictionary:
	if trees >= MAX_TREES:
		return {}
	return {"wood": ceili(TREE_BASE_COST * pow(TREE_COST_GROWTH, trees - START_TREES))}


func plant_tree() -> bool:
	if trees >= MAX_TREES or not spend(tree_cost()):
		return false
	trees += 1
	trees_changed.emit()
	return true


func builder_cost() -> Dictionary:
	return {"stone": ceili(BUILDER_BASE_COST * pow(BUILDER_COST_GROWTH, builders - START_BUILDERS))}


func hire_builder() -> bool:
	if not spend(builder_cost()):
		return false
	builders += 1
	builders_changed.emit()
	return true


func upgrade_cost(id: String) -> Dictionary:
	var upgrade: Dictionary = UPGRADES[id]
	var cost := {}
	for type: String in upgrade.cost:
		cost[type] = ceili(upgrade.cost[type] * pow(upgrade.growth, upgrades[id]))
	return cost


func buy_upgrade(id: String) -> bool:
	if not spend(upgrade_cost(id)):
		return false
	upgrades[id] += 1
	upgrades_changed.emit()
	return true


# --- What the upgrades do ---

func peasant_speed_mult() -> float:
	return 1.0 + 0.2 * upgrades.peasant_speed


## How many resources a peasant carries per trip.
func carry_amount() -> int:
	return 1 + upgrades.carry
