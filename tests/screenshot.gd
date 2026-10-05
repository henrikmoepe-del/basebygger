extends SceneTree
## Takes real screenshots of a build in progress. Unlike snapshot.gd this
## opens the game window, so it shows exactly what the player sees.
## Run with:
##   godot --path . -s tests/screenshot.gd -- --save=user://test_save.json --out=<folder> --plan=<name>
## Plans are in PLANS below.

## Each plan: the levels to start from, the part to raise, where the camera
## looks [x, lift, zoom], how many builders, and how many pictures to take.
const PLANS := {
	"wall": {"levels": {}, "part": "walls", "camera": [330, -40, 2.0], "shots": 6},
	"wall3": {"levels": {"walls": 2, "garrison": 1}, "part": "walls", "camera": [300, -30, 2.0], "shots": 6},
	"keep": {"levels": {"walls": 2}, "part": "keep", "camera": [-205, 0, 1.5], "shots": 8},
	"keep5": {"levels": {"walls": 3, "keep": 4}, "part": "keep", "camera": [-205, 80, 1.0], "shots": 10},
	"keep4": {"levels": {"walls": 3, "keep": 3}, "part": "keep", "camera": [-205, 110, 1.5], "shots": 10},
	"keep7": {"levels": {"walls": 6, "keep": 6, "garrison": 4, "court": 4}, "part": "keep", "camera": [-205, 200, 1.0], "shots": 12},
	"keep8": {"levels": {"walls": 6, "keep": 7, "garrison": 4, "court": 4}, "part": "keep", "camera": [-205, 230, 1.0], "shots": 12},
	"tower": {"levels": {"walls": 2}, "part": "towers", "camera": [460, 0, 1.5], "shots": 8},
	"court": {"levels": {"walls": 2}, "part": "court", "camera": [-430, -30, 2.0], "shots": 6},
	"rooms": {"levels": {"walls": 3, "keep": 3, "towers": 2, "garrison": 2}, "part": "", "camera": [-205, 10, 1.5], "shots": 3, "open": true, "jobs": {"cook": 2}},
	"rooms_night": {"levels": {"walls": 3, "keep": 3, "towers": 2, "garrison": 2}, "part": "", "camera": [-205, 10, 1.5], "shots": 2, "open": true, "jobs": {"cook": 2}, "night": true},
	"rooms_build": {"levels": {"walls": 2}, "part": "keep", "camera": [-205, 0, 1.5], "shots": 5, "open": true},
	"rooms_pick": {"levels": {"walls": 3, "keep": 4, "towers": 2, "garrison": 2}, "picks": [["armoury", "store"], ["store", "store"], ["armoury", "beds"]], "part": "", "camera": [-205, 40, 1.5], "shots": 2, "open": true},
	"keep_card": {"levels": {"walls": 3, "keep": 4, "towers": 2, "garrison": 2}, "picks": [["armoury", "store"], ["store", "store"]], "part": "", "camera": [-205, 40, 1.5], "shots": 1, "mouse": [180, 200]},
	"keep_build_card": {"levels": {"walls": 3, "keep": 4, "towers": 2, "garrison": 2}, "picks": [["armoury", "store"], ["store", "store"]], "part": "", "camera": [-205, 40, 1.5], "shots": 1, "hover": "keep"},
	"badger": {"levels": {"walls": 1}, "part": "", "camera": [1068, -45, 2.0], "shots": 2, "events": ["badger"], "jobs": {"hunter": 2}},
	"badger_close": {"levels": {"walls": 1}, "part": "", "camera": [1095, 5, 6.0], "shots": 2, "events": ["badger"]},
	"badger_hover": {"levels": {"walls": 1}, "part": "", "camera": [1068, -45, 2.0], "shots": 1, "events": ["badger"], "mouse": [388, 172]},
	"policies": {"levels": {"walls": 2}, "part": "", "camera": [100, 0, 1.0], "shots": 1, "policies": ["rations"]},
	"log": {"levels": {"walls": 2}, "part": "", "camera": [100, 0, 1.0], "shots": 1, "events": ["badger", "raid"], "log": true},
	"mood": {"levels": {"walls": 2, "well": 2, "tavern": 2}, "part": "", "camera": [100, 0, 1.0], "shots": 1, "happiness": 80.0},
	"mood_tip": {"levels": {"walls": 2, "well": 2, "tavern": 2, "quarry": 1}, "part": "", "camera": [100, 0, 1.0], "shots": 1, "happiness": 80.0, "policies": ["rations"], "mouse": [252, 9]},
	"stockhouse": {"levels": {"walls": 1, "stockhouse": 0}, "part": "stockhouse", "camera": [610, -40, 2.0], "shots": 4},
	"stores_full": {"levels": {"walls": 1, "stockhouse": 3}, "part": "", "camera": [610, -40, 2.0], "shots": 1, "stock": {"wood": 583, "stone": 200, "food": 90, "planks": 0, "iron": 0}},
	"spring": {"levels": {"walls": 2, "keep": 2, "houses": 3, "well": 1, "stockhouse": 2}, "stock": {"wood": 214, "stone": 187, "food": 96, "planks": 0, "iron": 0}, "part": "", "camera": [300, 0, 1.0], "shots": 1, "day": 1},
	"summer": {"levels": {"walls": 2, "keep": 2, "houses": 3, "well": 1, "stockhouse": 2}, "stock": {"wood": 214, "stone": 187, "food": 96, "planks": 0, "iron": 0}, "part": "", "camera": [300, 0, 1.0], "shots": 1, "day": 4},
	"autumn": {"levels": {"walls": 2, "keep": 2, "houses": 3, "well": 1, "stockhouse": 2}, "stock": {"wood": 214, "stone": 187, "food": 96, "planks": 0, "iron": 0}, "part": "", "camera": [300, 0, 1.0], "shots": 1, "day": 7},
	"winter": {"levels": {"walls": 2, "keep": 2, "houses": 3, "well": 1, "stockhouse": 2}, "stock": {"wood": 214, "stone": 187, "food": 96, "planks": 0, "iron": 0}, "part": "", "camera": [300, 0, 1.0], "shots": 1, "day": 10},
	"boosts": {"levels": {"walls": 2, "keep": 1, "tavern": 1, "well": 1, "quarry": 1, "stockhouse": 2}, "stock": {"wood": 214, "stone": 187, "food": 96, "planks": 0, "iron": 0}, "part": "", "camera": [100, 0, 1.0], "shots": 1, "buy": ["feast"], "panel": "boosts"},
	"bakery": {"levels": {"walls": 2, "towers": 1, "bakery": 1, "stockhouse": 2}, "stock": {"wood": 150, "stone": 80, "food": 150, "planks": 0, "iron": 0}, "part": "", "camera": [545, -40, 2.0], "shots": 2, "jobs": {"baker": 2}},
	"people": {"levels": {"walls": 1, "stockhouse": 2}, "stock": {"wood": 150, "stone": 80, "food": 150, "planks": 0, "iron": 0}, "part": "", "camera": [610, -40, 2.0], "shots": 1, "point_peasant": true},
	"rooms_new": {"levels": {"walls": 3, "keep": 3, "towers": 2, "garrison": 2}, "picks": [["larder", "chapel"], ["chapel", "larder"]], "part": "", "camera": [-205, 110, 1.5], "shots": 1, "open": true},
	"trader_fire": {"levels": {"walls": 1, "stockhouse": 2}, "stock": {"wood": 150, "stone": 80, "food": 150, "planks": 20, "iron": 0}, "part": "", "camera": [690, -40, 2.0], "shots": 1, "events": ["trader", "fire"]},
	"accident": {"levels": {"stockhouse": 2}, "part": "walls", "camera": [330, -40, 2.0], "shots": 2, "events": ["accident"]},
	"hurt_close": {"levels": {"stockhouse": 2}, "part": "walls", "camera": [330, -10, 6.0], "shots": 40, "events": ["accident"], "follow_hurt": true},
	"warband": {"levels": {"walls": 2, "palisade": 1, "watchtower": 1}, "part": "", "camera": [-800, -40, 2.0], "shots": 1, "raid_kind": "warband", "events": ["raid"]},
	"bandits": {"levels": {"walls": 2, "palisade": 1, "watchtower": 1}, "part": "", "camera": [-720, -40, 2.0], "shots": 1, "raid_kind": "bandits", "events": ["raid"]},
	"children": {"levels": {"walls": 1, "stockhouse": 2, "houses": 4}, "stock": {"wood": 150, "stone": 80, "food": 150, "planks": 0, "iron": 0}, "part": "", "camera": [610, -40, 2.0], "shots": 1, "kids": 3, "point_peasant": true},
	"boost_click": {"levels": {"walls": 1, "tavern": 2, "well": 1, "stockhouse": 2}, "stock": {"wood": 150, "stone": 80, "food": 150, "planks": 0, "iron": 0}, "part": "", "camera": [1296, -45, 2.0], "shots": 1, "click": [320, 150]},
	"rooms_picker": {"levels": {"walls": 3, "keep": 2}, "part": "", "camera": [-205, 10, 1.5], "shots": 1, "picker": true},
	"gate": {"levels": {"walls": 2}, "part": "gate", "camera": [30, -40, 2.0], "shots": 5},
	"tavern": {"levels": {"walls": 1}, "part": "tavern", "camera": [1170, -45, 2.0], "shots": 5},
	"inside": {"levels": {"walls": 3, "keep": 5, "towers": 4, "garrison": 3, "court": 2}, "part": "", "camera": [20, 20, 1.0], "shots": 4, "open": true, "soldiers": 8},
	"inside_build": {"levels": {"walls": 2}, "part": "keep", "camera": [-205, 0, 1.5], "shots": 6, "open": true},
	"sawmill": {"levels": {"walls": 1, "sawmill": 2}, "part": "", "camera": [1125, -45, 2.0], "shots": 3, "jobs": {"sawyer": 3}},
	"stockyard": {"levels": {"walls": 1, "sawmill": 2, "mine": 1}, "part": "", "camera": [570, -45, 2.0], "shots": 2, "jobs": {"sawyer": 3}},
	"idle": {"levels": {"walls": 3, "keep": 3, "towers": 3, "garrison": 2, "court": 2, "tavern": 1, "houses": 3}, "part": "", "camera": [100, 0, 0.75], "shots": 5},
}

## The far-out view saved with every picture: the whole castle and the stockyard.
const WIDE_ZOOM := 0.5
const WIDE_X := 60.0

var gs: Node


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var name := _arg("plan", "keep")
	var plan: Dictionary = PLANS[name]
	var out := _arg("out", "user://")
	# Wait for GameState to load the save first, or it would overwrite the plan.
	await process_frame
	for part: String in gs.part_levels:
		gs.part_levels[part] = 0
	for part: String in plan.levels:
		gs.part_levels[part] = plan.levels[part]
	# Stores big enough for the materials of any level, unless the plan says.
	if not plan.levels.has("stockhouse"):
		gs.part_levels.stockhouse = 15
	gs.keep_picks = plan.get("picks", []).duplicate(true)
	gs.day = plan.get("day", gs.day)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	Engine.time_scale = 12.0
	gs.no_nights = not plan.get("night", false)
	gs.peasants += 6
	gs.jobs.build += 3
	gs.peasants_changed.emit()
	for type in gs.resources:
		gs.resources[type] = 100000
	var camera: Camera2D = current_scene.get_node("Camera")
	camera.set_process(false)
	camera.set_process_unhandled_input(false)
	camera.zoom = Vector2(plan.camera[2], plan.camera[2])
	camera.position = Vector2(plan.camera[0], 270.0 - 90.0 / plan.camera[2] - plan.camera[1])
	if plan.get("open", false):
		current_scene.get_node("Castle").toggle_all_open()
	for job: String in plan.get("jobs", {}):
		gs.peasants += plan.jobs[job]
		gs.jobs[job] = plan.jobs[job]
		gs.peasants_changed.emit()
	if plan.has("soldiers"):
		gs.peasants += plan.soldiers
		gs.jobs.soldier = plan.soldiers
		gs.peasants_changed.emit()

	if plan.get("picker", false):
		current_scene.get_node("HUD").show_room_picker()
	if plan.has("hover"):
		# Build mode on, pointing at a part's circle: shows its build card.
		var hover: Node2D = current_scene.get_node("BuildHover")
		hover.set_active(true)
		hover._set_hovered(plan.hover)
	if plan.has("policies"):
		for policy: String in plan.policies:
			gs.toggle_policy(policy)
		current_scene.get_node("HUD").policies_button.button_pressed = true
	for i in plan.get("kids", 0):
		var adults: Array = gs.grown_ups()
		adults.shuffle()
		gs.have_child(adults[0], adults[1])
	if plan.has("raid_kind"):
		gs.next_raid_kind = plan.raid_kind
	for event: String in plan.get("events", []):
		gs.start_event(event)
	if plan.has("stock"):
		for type: String in plan.stock:
			gs.resources[type] = plan.stock[type]
		gs.resources_changed.emit()
	for boost: String in plan.get("buy", []):
		gs.buy_boost(boost)
	if plan.get("panel", "") == "boosts":
		current_scene.get_node("HUD").boosts_button.button_pressed = true
	if plan.get("point_peasant", false):
		# Point the mouse at the peasant nearest the middle of the view, just before each picture.
		pass
	if plan.has("happiness"):
		gs.happiness = plan.happiness
	if plan.get("log", false):
		current_scene.get_node("HUD").log_button.button_pressed = true
	if not plan.has("mouse"):
		# Out of the way, over the sky at the top right, unless the plan points somewhere.
		Input.warp_mouse(Vector2(630, 60) * 2.0)
	if plan.has("click"):
		# A click at a point on screen (in the 640x360 view), as a player would.
		var at := Vector2(plan.click[0], plan.click[1]) * 2.0
		Input.warp_mouse(at)
		await process_frame
		var motion := InputEventMouseMotion.new()
		motion.position = at
		Input.parse_input_event(motion)
		await process_frame
		for down: bool in [true, false]:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = down
			press.position = at
			Input.parse_input_event(press)
			await process_frame
	if plan.has("mouse"):
		# The mouse at a point on screen (in the 640x360 view).
		Input.warp_mouse(Vector2(plan.mouse[0], plan.mouse[1]) * 2.0)
	if plan.part == "":
		# Nothing to build: just watch the peasants for a while.
		for shot in plan.shots:
			var t := 0.0
			while t < 25.0:
				await process_frame
				t += root.get_process_delta_time()
				gs.day_time = gs.DAY_LENGTH * 0.85 if plan.get("night", false) else 10.0
			if plan.get("point_peasant", false):
				_point_at_peasant(plan.has("kids"))
				await process_frame
			await _shoot("%s/%s_%d.png" % [out, name, shot])
	else:
		gs.order_part(plan.part)
		var size: int = gs.job_size()
		var next := 0
		while gs.job_part != "" and next < plan.shots:
			await process_frame
			gs.day_time = 10.0
			# Spread the pictures over the job, by pieces placed.
			if gs.job_placed >= int(size * (next + 0.5) / plan.shots):
				if plan.get("follow_hurt", false):
					# Look closely at whoever is hurt.
					for worker in current_scene.get_node("Workers").get_children():
						if worker.get("person") != null and worker.person.get("hurt", false):
							camera.position = worker.global_position + Vector2(0, -10)
					await process_frame
				await _shoot("%s/%s_%d.png" % [out, name, next])
				print("shot %d at %d of %d pieces" % [next, gs.job_placed, size])
				next += 1
	Engine.time_scale = 1.0
	# Leave no save behind: the tests start from a new game.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	quit()


## Moves the mouse onto the peasant nearest the middle of the screen.
func _point_at_peasant(plan_kids := false) -> void:
	var camera: Camera2D = current_scene.get_node("Camera")
	var workers: Node2D = current_scene.get_node("Workers")
	var best: Node2D = null
	for worker in workers.get_children():
		if worker.get("person") == null or (plan_kids and not worker.person.get("child", false)):
			continue
		if worker.visible and worker.position.y > -0.5 and (best == null \
				or absf(worker.global_position.x - camera.position.x) < absf(best.global_position.x - camera.position.x)):
			best = worker
	if best != null:
		var on_screen: Vector2 = (best.global_position + Vector2(0, -8) - camera.position) * camera.zoom + Vector2(320, 180)
		Input.warp_mouse(on_screen * 2.0)


## Saves two pictures: the close-up the plan asks for, and the whole castle
## from far out (<name>_wide.png), so nothing outside the close-up is missed.
func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	var camera: Camera2D = current_scene.get_node("Camera")
	var zoom := camera.zoom
	var position := camera.position
	camera.zoom = Vector2(WIDE_ZOOM, WIDE_ZOOM)
	camera.position = Vector2(WIDE_X, 270.0 - 90.0 / WIDE_ZOOM)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path.replace(".png", "_wide.png"))
	camera.zoom = zoom
	camera.position = position
