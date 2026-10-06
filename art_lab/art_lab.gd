extends Control
## The art lab: a test map with the castle and a few peasants building on
## it, drawn in several art styles to compare. It is not part of the game.
## Open art_lab/art_lab.tscn in Godot and press F6 (Run Current Scene).
## Keys: Left/Right or 1-6 change style, Space pauses, Up/Down change speed,
## H hides the text.

const Styles := preload("res://art_lab/styles.gd")
const Painter := preload("res://art_lab/painter.gd")

var styles: Array = Styles.all()
var index := 0
var t := 18.0
var speed := 1.0
var paused := false

var vp: SubViewport
var view: TextureRect
var painter: Node2D
var title: Label
var info: Label
var panel: PanelContainer


func _ready() -> void:
	# The game draws at 640 x 360; the lab wants the whole window, so the
	# smooth styles get every screen pixel.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	vp = SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	painter = Painter.new()
	vp.add_child(painter)
	view = TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(view)
	panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.08, 0.06, 0.72)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", box)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_bottom = -12.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#f4e6c4"))
	col.add_child(title)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color("#e0d2b0"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(620, 0)
	col.add_child(info)
	set_style(0)


func set_style(i: int) -> void:
	index = posmod(i, styles.size())
	var st: Dictionary = styles[index]
	vp.size = st.res
	vp.msaa_2d = Viewport.MSAA_DISABLED if st.family == "pixel" else Viewport.MSAA_4X
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if st.family == "pixel" else CanvasItem.TEXTURE_FILTER_LINEAR
	painter.setup(st)
	var b: Vector2 = st.block
	title.text = "%d/%d  %s" % [index + 1, styles.size(), st.name]
	info.text = "%s\nBlock %s x %s, %d blocks in the keep.  Left/Right or 1-%d: style   Space: pause   Up/Down: speed   H: hide this" % [
		st.desc, _num(b.x), _num(b.y), painter.piece_count(), styles.size()]


func set_time(seconds: float) -> void:
	t = seconds
	painter.t = t
	painter.queue_redraw()


func _num(v: float) -> String:
	return str(int(v)) if v == int(v) else str(v)


func _process(delta: float) -> void:
	if not paused:
		set_time(t + delta * speed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if key == KEY_RIGHT:
		set_style(index + 1)
	elif key == KEY_LEFT:
		set_style(index - 1)
	elif key >= KEY_1 and key <= KEY_9 and key - KEY_1 < styles.size():
		set_style(key - KEY_1)
	elif key == KEY_SPACE:
		paused = not paused
	elif key == KEY_UP:
		speed = minf(speed * 2.0, 16.0)
	elif key == KEY_DOWN:
		speed = maxf(speed * 0.5, 0.25)
	elif key == KEY_H:
		panel.visible = not panel.visible
