extends SceneTree
## Makes the building plan for every part at every level, without building
## anything, and checks each one: a deck never drops while builders are up on
## it, and every piece is set from somewhere a builder can stand.
## Run with:
##   godot --headless --path . -s tests/check_plans.gd -- --save=user://test_save.json

const CastleData = preload("res://scripts/castle_data.gd")
const BuildPlan = preload("res://scripts/build_plan.gd")


func _initialize() -> void:
	var faults := 0
	for part: String in CastleData.PARTS:
		for level in CastleData.MAX_VISUAL_LEVEL + 1:
			faults += _check(part, level)
	print("ALL OK" if faults == 0 else "SOMETHING FAILED: %d faults" % faults)
	quit()


func _check(part: String, level: int) -> int:
	var plan := BuildPlan.make(part, level)
	var faults := 0
	var floors := {}
	for i in plan.fetch:
		var piece: Dictionary = plan.pieces[i]
		var before: float = floors.get(piece.section, 0.0)
		# Ladders are put up from the ground before anyone is on the deck.
		if piece.floor > before + 0.5 and piece.kind != BuildPlan.Kind.LADDER:
			faults += 1
			print("%s %d > %d: piece %d (kind %d, %s) lowers the deck of section %d from %.0f to %.0f" % [
				part, level, level + 1, i, piece.kind, piece.rect, piece.section, before, piece.floor])
		if piece.kind != BuildPlan.Kind.LADDER:
			floors[piece.section] = piece.floor
		if not piece.top and piece.stand.y < -0.5 and not _platform_at(plan, piece.stand, i):
			faults += 1
			print("%s %d > %d: piece %d (kind %d) is set from %s, where there is nothing to stand on" % [
				part, level, level + 1, i, piece.kind, piece.stand])
	return faults


func _platform_at(plan: Dictionary, at: Vector2, index: int) -> bool:
	for platform: Dictionary in plan.platforms:
		if at.x >= platform.x0 - 0.5 and at.x <= platform.x1 + 0.5 and absf(at.y - platform.y) < 0.5 and index >= platform.from and index <= platform.until:
			return true
	return false
