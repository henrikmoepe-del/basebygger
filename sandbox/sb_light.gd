extends RefCounted
## Warm light for the night (art direction: "at night, only fire, candles,
## windows and torches give light, and it is always warm"). Lights are
## PointLight2D nodes; the world's CanvasModulate darkens everything else.

const WARM := Color("#ffb060")


static var _texture: Texture2D


## A soft round glow texture, made once.
static func texture() -> Texture2D:
	if _texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_texture = t
	return _texture


## Adds a warm light to a node: `size` is its reach in pixels.
static func add(to: Node2D, offset: Vector2, size: float, energy := 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = texture()
	light.texture_scale = size / 64.0
	light.color = WARM
	light.energy = energy
	light.position = offset
	light.blend_mode = Light2D.BLEND_MODE_ADD
	to.add_child(light)
	return light
