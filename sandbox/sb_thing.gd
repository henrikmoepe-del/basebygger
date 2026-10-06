extends Node2D
## Something in the sandbox world that peasants can work on or be ordered to:
## a building site, tree, rock, loose item, fire or raider. Its position is
## (x, depth) on the ground band, and the y-sorted parent draws whatever is
## further forward in front.

const SbData := preload("res://sandbox/sb_data.gd")

## "site", "tree", "rock", "item", "fire", "raider", "well", "stockyard".
var kind := ""
var world: Node2D
## The peasants working on this right now.
var workers: Array = []
## Forbidden (X): nobody works on it by themselves; orders still can.
var forbidden := false


## How many peasants may pick this by themselves at once.
func capacity() -> int:
	return SbData.CAPACITY.get(kind, 1)


## True while there is something to do here.
func is_open() -> bool:
	return true


## True if the point (in the world) is on this thing, for clicks.
func hit(_p: Vector2) -> bool:
	return false


## Where a peasant stands to work here. Spreads several workers apart.
func work_spot(peasant: Node2D) -> Vector2:
	var i := workers.find(peasant)
	if i < 0:
		i = workers.size()
	var side := -1.0 if i % 2 == 0 else 1.0
	return position + Vector2(side * (8.0 + 5.0 * float(i / 2)), 4.0 + 3.0 * float(i / 2))


## A few words for the HUD: "the Hut", "a tree".
func label() -> String:
	return kind


## A line for pointing at it with nobody selected.
func describe() -> String:
	return label().capitalize() + (" (forbidden)" if forbidden else "")


func claim(peasant: Node2D) -> void:
	if not workers.has(peasant):
		workers.append(peasant)


func release(peasant: Node2D) -> void:
	workers.erase(peasant)
