extends CanvasLayer
## Developer shortcuts for testing, so the game doesn't have to be played
## from the start every time. They only work when the game is run from the
## Godot editor (a debug build), never in an exported game.
##
##   F1  show or hide this list
##   F2  game speed: x1 -> x5 -> x20 -> x50 -> x1
##   F3  skip 10 minutes (resources from current income; the build job finishes)
##   F4  +1000 wood, stone and food, +20 renown
##   F6  +5 idle peasants (ignores the housing limit)

const SPEEDS := [1.0, 5.0, 20.0, 50.0]
const SKIP_SECONDS := 600.0
const HELP := "DEV  F1 help  F2 speed  F3 skip 10 min  F4 resources  F6 peasants"

var _speed_index := 0
var _label := Label.new()


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_label.position = Vector2(8, 300)
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color(0.75, 0.15, 0.15))
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0.96, 0.95, 0.85))
	_label.text = HELP
	add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			_label.visible = not _label.visible
		KEY_F2:
			_speed_index = (_speed_index + 1) % SPEEDS.size()
			Engine.time_scale = SPEEDS[_speed_index]
			_label.text = HELP if _speed_index == 0 else "%s   [speed x%d]" % [HELP, SPEEDS[_speed_index]]
		KEY_F3:
			GameState.dev_skip(SKIP_SECONDS)
		KEY_F4:
			for type: String in GameState.resources:
				GameState.resources[type] += 1000
			GameState.renown += 20
			GameState.resources_changed.emit()
			GameState.skills_changed.emit()
		KEY_F6:
			GameState.peasants += 5
			GameState.peasants_changed.emit()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
