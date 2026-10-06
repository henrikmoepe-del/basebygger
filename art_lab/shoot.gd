extends SceneTree
## Takes pictures of every art style in the art lab, in a real window.
##   godot --path . -s art_lab/shoot.gd -- --out=<folder> [--clips]
## For each style: <id>_early.png, <id>_late.png and <id>_done.png; with
## --clips also numbered frames <id>/f_000.png for a short film.

const TIMES := {"early": 14.0, "late": 38.0, "done": 52.0}
const CLIP_FRAMES := 72
const CLIP_FPS := 12.0

var lab: Control
var out := "user://art_lab_shots"
var clips := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--clips":
			clips = true
	DirAccess.make_dir_recursive_absolute(out)
	lab = load("res://art_lab/art_lab.tscn").instantiate()
	root.add_child(lab)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	lab.set_process(false)
	for i in lab.styles.size():
		lab.set_style(i)
		var id: String = lab.styles[i].id
		for k in TIMES:
			await _shot(TIMES[k], "%s/%s_%s.png" % [out, id, k])
		if clips:
			DirAccess.make_dir_recursive_absolute("%s/%s" % [out, id])
			for f in CLIP_FRAMES:
				await _shot(30.0 + f / CLIP_FPS, "%s/%s/f_%03d.png" % [out, id, f])
		print("shot ", id)
	quit()


func _shot(time: float, path: String) -> void:
	lab.set_time(time)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
