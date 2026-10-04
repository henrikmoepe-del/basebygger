extends RefCounted
## The look of every panel, button and label in the game, in one place:
## dark wood panels, parchment text, flat square edges to suit the pixel look.
## hud.gd builds this once and gives it to the HUD; change a colour here and
## the whole interface follows.

const WOOD_DARK := Color(0.17, 0.13, 0.10, 0.94)
const WOOD := Color(0.36, 0.26, 0.17)
const WOOD_LIGHT := Color(0.46, 0.34, 0.22)
const WOOD_PRESSED := Color(0.26, 0.19, 0.13)
const WOOD_DISABLED := Color(0.24, 0.21, 0.18)
const EDGE := Color(0.60, 0.46, 0.28)
const EDGE_DARK := Color(0.10, 0.07, 0.05)
const PARCHMENT := Color(0.96, 0.91, 0.78)
const PARCHMENT_DIM := Color(0.62, 0.57, 0.48)
const GOLD := Color(1.0, 0.82, 0.38)
const GOOD := Color(0.62, 0.88, 0.50)
const BAD := Color(1.0, 0.50, 0.42)
const INK := Color(0.20, 0.17, 0.15)

## The colour that stands for each resource, on its chip in the top bar.
const RESOURCE_COLORS := {
	"wood": Color(0.62, 0.42, 0.24), "stone": Color(0.70, 0.70, 0.75),
	"food": Color(0.82, 0.30, 0.34), "iron": Color(0.45, 0.50, 0.62),
	"renown": Color(1.0, 0.82, 0.38), "legacy": Color(0.70, 0.55, 0.95),
}


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 11

	theme.set_stylebox("panel", "Panel", _box(WOOD_DARK, EDGE, 1, 0))
	theme.set_stylebox("normal", "Button", _box(WOOD, EDGE_DARK, 1, 4))
	theme.set_stylebox("hover", "Button", _box(WOOD_LIGHT, EDGE, 1, 4))
	theme.set_stylebox("pressed", "Button", _box(WOOD_PRESSED, EDGE, 1, 4))
	theme.set_stylebox("disabled", "Button", _box(WOOD_DISABLED, EDGE_DARK, 1, 4))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", PARCHMENT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", PARCHMENT_DIM)
	theme.set_color("font_color", "Label", PARCHMENT)
	theme.set_stylebox("panel", "TooltipPanel", _box(Color(0.08, 0.06, 0.05, 0.97), EDGE, 1, 4))
	theme.set_color("font_color", "TooltipLabel", PARCHMENT)
	theme.set_font_size("font_size", "TooltipLabel", 10)
	return theme


## Makes a button small: the same look with almost no room around the text.
## Used for the - / + / Train buttons in the peasants panel.
static func make_compact(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _box(WOOD, EDGE_DARK, 1, 1))
	button.add_theme_stylebox_override("hover", _box(WOOD_LIGHT, EDGE, 1, 1))
	button.add_theme_stylebox_override("pressed", _box(WOOD_PRESSED, EDGE, 1, 1))
	button.add_theme_stylebox_override("disabled", _box(WOOD_DISABLED, EDGE_DARK, 1, 1))


## A flat box: fill colour, edge colour, edge width, and room around the text.
static func _box(fill: Color, edge: Color, edge_width: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(edge_width)
	box.set_content_margin_all(margin)
	return box
