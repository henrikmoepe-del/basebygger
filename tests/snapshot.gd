extends SceneTree
## Paints pictures of a build in progress, without opening a window: it runs
## the real game, and every so often draws the castle (with the game's own
## drawing code) and the peasants into a PNG. For looking at how building
## looks when no window can be opened.
## Run with:
##   godot --headless --path . -s tests/snapshot.gd -- --save=user://test_save.json --out=<folder> --plan=<name>
## Plans are in PLANS below.

const SCALE := 2
const SKY := Color(0.93, 0.92, 0.66)
const GRASS := Color(0.45, 0.68, 0.38)
const SKIN := Color(0.93, 0.76, 0.62)

## Each plan: the levels to start from, the part to raise, the stretch of the
## world to picture [left, right, height], and how many pictures to take.
const PLANS := {
	"wall": {"levels": {}, "part": "walls", "view": [150, 520, 120], "shots": 6},
	"keep": {"levels": {"walls": 2}, "part": "keep", "view": [-260, 60, 200], "shots": 8},
	"keep5": {"levels": {"walls": 3, "keep": 4}, "part": "keep", "view": [-260, 60, 300], "shots": 8},
	"wall3": {"levels": {"walls": 2, "garrison": 1}, "part": "walls", "view": [150, 520, 120], "shots": 6},
	"tower": {"levels": {"walls": 2}, "part": "towers", "view": [300, 520, 180], "shots": 8},
	"tower3": {"levels": {"walls": 2, "towers": 2}, "part": "towers", "view": [140, 520, 220], "shots": 8},
	"court": {"levels": {"walls": 2}, "part": "court", "view": [-400, -180, 140], "shots": 6},
	"gate": {"levels": {"walls": 2}, "part": "gate", "view": [-90, 130, 110], "shots": 5},
	"house": {"levels": {"walls": 1}, "part": "tavern", "view": [1060, 1260, 80], "shots": 5},
}

var gs: Node


## Something the castle can draw on, that paints into an image instead.
class ImageCanvas:
	var image: Image
	var origin: Vector2

	func draw_rect(rect: Rect2, color: Color, _filled := true, _width := -1.0) -> void:
		var area := Rect2i(Vector2i((rect.position + origin).round()), Vector2i(maxi(roundi(rect.size.x), 1), maxi(roundi(rect.size.y), 1)))
		area = area.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
		if area.has_area():
			image.fill_rect(area, Color(color, 1.0))

	func draw_line(from: Vector2, to: Vector2, color: Color, _width := 1.0) -> void:
		var steps := maxi(int(from.distance_to(to)), 1)
		for i in steps + 1:
			draw_rect(Rect2(from.lerp(to, float(i) / steps), Vector2.ONE), color)


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run()


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var plan: Dictionary = PLANS[_arg("plan", "keep")]
	var out := _arg("out", "user://")
	for part: String in plan.levels:
		gs.part_levels[part] = plan.levels[part]
	# Stores big enough for the materials of any level, unless the plan says.
	if not plan.levels.has("stockhouse"):
		gs.part_levels.stockhouse = 15
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	Engine.time_scale = 20.0
	gs.no_nights = true
	gs.peasants += 4
	gs.jobs.build += 3
	gs.peasants_changed.emit()
	for type in gs.resources:
		gs.resources[type] = 100000
	gs.order_part(plan.part)
	var size: int = gs.job_size()
	var next := 0
	while gs.job_part != "" and next < plan.shots:
		await process_frame
		gs.day_time = 10.0
		# Spread the pictures over the job, by pieces placed.
		if gs.job_placed >= int(size * (next + 0.5) / plan.shots):
			_snap("%s/%s_%d.png" % [out, _arg("plan", "keep"), next], plan.view)
			print("shot %d at %d of %d pieces" % [next, gs.job_placed, size])
			next += 1
	Engine.time_scale = 1.0
	quit()


func _snap(path: String, view: Array) -> void:
	var width: int = view[1] - view[0]
	var height: int = view[2] + 14
	var canvas := ImageCanvas.new()
	canvas.image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.image.fill(SKY)
	canvas.origin = Vector2(-view[0], view[2])
	canvas.draw_rect(Rect2(view[0], 0, width, 14), GRASS)
	var castle := current_scene.get_node("Castle")
	var workers := current_scene.get_node("Workers")
	castle._draw_layer(canvas, false)
	_peasants(canvas, workers, true)
	castle._draw_layer(canvas, true)
	_peasants(canvas, workers, false)
	canvas.image.resize(width * SCALE, height * SCALE, Image.INTERPOLATE_NEAREST)
	canvas.image.save_png(path)


## Peasants as plain figures: those up on the curtain wall, or the rest.
func _peasants(canvas: ImageCanvas, workers: Node, back: bool) -> void:
	for w in workers.get_children():
		if not w.has_method("tunic") or not w.visible or (w.z_index == 1) != back:
			continue
		var at: Vector2 = w.position
		canvas.draw_rect(Rect2(at.x - 3, at.y - 12, 6, 12), w.tunic())
		canvas.draw_rect(Rect2(at.x - 2, at.y - 16, 4, 4), SKIN)
		if w.get("_piece") != null and (w._carrying > 0 or w._piece >= 0):
			canvas.draw_rect(Rect2(at.x - 4, at.y - 20, 8, 3), Color(0.9, 0.2, 0.8))
