extends Node2D
## Draws the art lab's test map in the chosen art style: a castle whose keep
## is going up block by block, builders at work, and a bit of village.
## Everything is laid out on a 320 x 180 map. The style decides how many
## pixels that becomes and how each thing is drawn ("family"):
##   pixel   - drawn at low resolution and blown up, so every edge is a pixel
##   painted - smooth shapes, soft gradients, uneven hand-cut stones
##   ink     - ink outlines and hatching on parchment, light watercolour
##   flat    - plain shapes in two tones, no outlines

const W := 320.0
const H := 180.0
const GY := 150.0          ## the ground line the castle stands on
const HORIZON := 128.0     ## where the mountains meet the hills
const MEADOW := 131.0      ## where the near grass begins
const KEEP_X := 104.0
const KEEP_W := 48.0
const KEEP_H := 80.0
const BUILD_TIME := 50.0   ## seconds to raise the keep from a quarter to the top
const HOLD_TIME := 6.0     ## seconds it stands finished before starting over
const ROPE_X := 160.0
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Clouds: centre x, centre y, half width, half height.
const CLOUDS := [[60.0, 40.0, 46.0, 10.0], [190.0, 26.0, 60.0, 12.0], [285.0, 58.0, 38.0, 8.0],
		[125.0, 76.0, 30.0, 6.0], [18.0, 88.0, 26.0, 5.0]]
## Mountains: peak x, peak y, half width.
const FAR_MOUNTAINS := [[40.0, 92.0, 55.0], [160.0, 96.0, 70.0], [265.0, 90.0, 60.0]]
const NEAR_MOUNTAINS := [[85.0, 76.0, 50.0], [205.0, 64.0, 58.0], [300.0, 82.0, 42.0]]

var style: Dictionary = {}
var pal: Dictionary = {}
var fam := "pixel"
var s := 1.0               ## screen pixels per map unit in the render
var u := 1.0               ## one render pixel, in map units
var t := 0.0               ## time in seconds, set by art_lab.gd

var sky_tex: Texture2D
var cloud_tex: Texture2D
var ground_tex: Texture2D
var paper_tex: Texture2D

## The keep's blocks in the order they are laid: bottom course first, left to right.
var bricks: Array[Rect2] = []
var row_ends: Array[int] = []
var keep_top := 70.0

# How far the build has got, worked out at the start of every frame.
var laid := 0
var deck_y := GY
var finished := false


func setup(st: Dictionary) -> void:
	style = st
	pal = st.pal
	fam = st.family
	s = float(st.res.x) / W
	u = 1.0 / s
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if fam == "pixel" else CanvasItem.TEXTURE_FILTER_LINEAR
	_make_textures()
	_make_bricks()
	queue_redraw()


func block() -> Vector2:
	return style.block


func piece_count() -> int:
	return bricks.size()


# ---------------------------------------------------------------- the frame

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	_update_build()
	_draw_sky()
	_draw_mountains()
	_draw_clouds()
	_draw_hills()
	_draw_ground()
	_draw_wall()
	_draw_tower(68.0, 96.0, 24.0)
	_draw_keep()
	_draw_works()
	_draw_village()
	_draw_people()


func _update_build() -> void:
	var cyc := fmod(t, BUILD_TIME + HOLD_TIME)
	finished = cyc >= BUILD_TIME
	var p := 1.0 if finished else 0.25 + 0.75 * cyc / BUILD_TIME
	laid = clampi(int(p * bricks.size()), 0, bricks.size())
	var full := 0
	for e in row_ends:
		if e <= laid:
			full += 1
	deck_y = GY - full * block().y


func _make_bricks() -> void:
	bricks.clear()
	row_ends.clear()
	var b := block()
	var rows := int(round(KEEP_H / b.y))
	keep_top = GY - rows * b.y
	for r in rows:
		bricks.append_array(_course(KEEP_X, KEEP_W, GY - (r + 1) * b.y, b, r))
		row_ends.append(bricks.size())


## One course of blocks from x0 to x0 + w, every other one shifted by half a block.
func _course(x0: float, w: float, y: float, b: Vector2, r: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var x := x0 - (b.x * 0.5 if r % 2 == 1 else 0.0)
	var i := 0
	while x < x0 + w - 0.01:
		var bw := b.x
		if style.get("irregular", false):
			bw = b.x * (0.7 + 0.6 * _hash(r * 7.0 + i, 3.0))
		if x0 + w - (x + bw) < b.x * 0.35:
			bw = x0 + w - x
		var a := maxf(x, x0)
		var e := minf(x + bw, x0 + w)
		if e - a > 0.3:
			out.append(Rect2(a, y, e - a, b.y))
		x += bw
		i += 1
	return out


# ---------------------------------------------------------------- helpers

func _hash(a: float, b: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floor(v)


func _c(key: String) -> Color:
	return pal.get(key, Color.MAGENTA)


func _a(key: String, alpha: float) -> Color:
	return Color(_c(key), alpha)


func _snap(v: float) -> float:
	return round(v * s) / s


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	if fam == "pixel":
		var x0 := _snap(x)
		var y0 := _snap(y)
		var x1 := maxf(_snap(x + w), x0 + u)
		var y1 := maxf(_snap(y + h), y0 + u)
		draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), c)
	else:
		draw_rect(Rect2(x, y, w, h), c)


func _line(a: Vector2, b: Vector2, c: Color, w: float = 0.5) -> void:
	if fam == "pixel":
		var half := Vector2(u, u) * 0.5
		draw_line(Vector2(_snap(a.x), _snap(a.y)) + half, Vector2(_snap(b.x), _snap(b.y)) + half, c, -1.0)
	else:
		draw_line(a, b, c, w, false)


func _poly(pts: PackedVector2Array, c: Color) -> void:
	if fam == "pixel":
		for i in pts.size():
			pts[i] = Vector2(_snap(pts[i].x), _snap(pts[i].y))
	draw_colored_polygon(pts, c)


func _poly2(pts: Array, c: Color) -> void:
	_poly(PackedVector2Array(pts), c)


func _ink_outline(pts: Array, w: float = 0.35) -> void:
	var p := PackedVector2Array(pts)
	p.append(pts[0])
	draw_polyline(p, _edge_colour(), w if fam == "ink" else w * 0.8, false)


## The outline colour: ink for the ink style, a soft brown for the painted one.
func _edge_colour() -> Color:
	return _c("ink") if fam == "ink" else Color(0.3, 0.22, 0.16, 0.55)


## Outlines around shapes, for the styles that have them.
func _edged() -> bool:
	return fam == "ink" or fam == "painted"


func _edge_rect(r: Rect2, w: float = 0.35) -> void:
	if _edged():
		draw_rect(r, _edge_colour(), false, w if fam == "ink" else w * 0.8)


func _circle(c: Vector2, r: float, col: Color) -> void:
	if fam == "pixel":
		c = Vector2(_snap(c.x), _snap(c.y))
	draw_circle(c, r, col, true, -1.0, fam != "pixel")


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_poly(pts, col)


## Diagonal hatching inside a box, for the ink style's shadows.
func _hatch(x: float, top: float, w: float, bottom: float, gap: float, col: Color) -> void:
	var h := bottom - top
	if h <= 0.0 or w <= 0.0:
		return
	var c := -h
	while c < w:
		var p1 := Vector2(x + c, bottom)
		var p2 := Vector2(x + c + h, top)
		if p1.x < x:
			p1 = Vector2(x, bottom - (x - p1.x))
		if p2.x > x + w:
			p2 = Vector2(x + w, top + (p2.x - (x + w)))
		draw_line(p1, p2, col, 0.22, false)
		c += gap


func _grad(stops: Array, v: float, th: float, dither: bool) -> Color:
	var n := stops.size() - 1
	var f := clampf(v, 0.0, 0.9999) * n
	var i := int(f)
	var fr := f - i
	var a: Color = stops[i]
	var b: Color = stops[mini(i + 1, n)]
	if dither:
		return b if fr > th else a
	return a.lerp(b, fr)


# ---------------------------------------------------------------- textures

## The pixel and painted styles get their sky, clouds and grass as pictures
## made once, pixel by pixel: that is how the dithering of the video is made.
## The painted style makes them small and lets the GPU blur them up.
func _make_textures() -> void:
	sky_tex = null
	cloud_tex = null
	ground_tex = null
	paper_tex = null
	if fam == "ink":
		_make_paper()
		return
	if fam != "pixel" and fam != "painted":
		return
	var dither := fam == "pixel"
	var res: Vector2i = style.res if dither else Vector2i(320, 180)
	var k := float(res.x) / W
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.08
	var sky := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var clouds := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var ground := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var sky_stops: Array = pal.sky
	var grass_stops: Array = [_c("grass_dark"), _c("grass"), _c("grass_light")]
	var flowers: Array = pal.flowers
	var ring := W * 1.2 / TAU
	for py in res.y:
		var ly := (py + 0.5) / k
		for px in res.x:
			var lx := (px + 0.5) / k
			var th: float = BAYER[(py % 4) * 4 + px % 4] / 16.0 + 1.0 / 32.0
			if ly < HORIZON + 2.0:
				sky.set_pixel(px, py, _grad(sky_stops, ly / HORIZON, th, dither))
			if ly < 110.0:
				var best := -9.0
				var dyn := 0.0
				for cl in CLOUDS:
					var dx: float = lx - cl[0]
					dx -= W * round(dx / W)
					var ex: float = dx / cl[2]
					var ey: float = (ly - cl[1]) / cl[3]
					var v := 1.0 - (ex * ex + ey * ey)
					if v > best:
						best = v
						dyn = ey
				var ang := lx / W * TAU
				best += noise.get_noise_3d(cos(ang) * ring, sin(ang) * ring, ly * 3.0) * 0.5
				if best > 0.0:
					clouds.set_pixel(px, py, _cloud_colour(best, dyn, th, dither))
			if ly >= MEADOW:
				var n := noise.get_noise_2d(lx * 2.0, ly * 4.0) * 0.5 + 0.5
				var depth := (ly - MEADOW) / (H - MEADOW)
				var col := _grad(grass_stops, clampf(n * 0.8 + 0.35 - depth * 0.3, 0.0, 1.0), th, dither)
				var fh := _hash(px * 1.31, py * 0.77)
				if ly > MEADOW + 3.0 and fh < (0.012 if dither else 0.02):
					col = flowers[int(_hash(px, py * 3.1) * flowers.size()) % flowers.size()]
				ground.set_pixel(px, py, col)
	sky_tex = ImageTexture.create_from_image(sky)
	cloud_tex = ImageTexture.create_from_image(clouds)
	ground_tex = ImageTexture.create_from_image(ground)


func _cloud_colour(v: float, dyn: float, th: float, dither: bool) -> Color:
	var lit := _c("cloud")
	var shade := _c("cloud_shade")
	var warm := _c("cloud_warm")
	if dither:
		if dyn > 0.45:
			return shade
		if dyn > 0.15:
			return shade if th < (dyn - 0.15) / 0.3 else lit
		if v < 0.1 and dyn < -0.1:
			return warm
		return lit
	var col := lit.lerp(shade, clampf(dyn * 0.9 + 0.25, 0.0, 1.0))
	if dyn < 0.0:
		col = col.lerp(warm, (1.0 - smoothstep(0.0, 0.3, v)) * 0.7)
	col.a = smoothstep(0.0, 0.25, v)
	return col


func _make_paper() -> void:
	var img := Image.create(160, 90, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.09
	var paper := _c("paper")
	var dark := _c("paper_dark")
	for y in 90:
		for x in 160:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var edge := Vector2((x - 80.0) / 80.0, (y - 45.0) / 45.0).length()
			var v := clampf(n * 0.35 + smoothstep(0.75, 1.45, edge) * 0.8, 0.0, 1.0)
			img.set_pixel(x, y, paper.lerp(dark, v))
	paper_tex = ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- sky

func _draw_sky() -> void:
	draw_rect(Rect2(0, 0, W, H), _c("bg"))
	var sun: Vector2 = pal.sun_pos
	match fam:
		"pixel", "painted":
			draw_texture_rect(sky_tex, Rect2(0, 0, W, H), false)
			_circle(sun, 11.0, _a("sun_halo", 0.18))
			_circle(sun, 8.0, _a("sun_halo", 0.35))
			_circle(sun, 5.5, _c("sun"))
		"flat":
			var top: Color = pal.sky[0]
			var low: Color = pal.sky[1]
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, HORIZON), Vector2(0, HORIZON)]),
					PackedColorArray([top, top, low, low]))
			_circle(sun, 9.0, _a("sun_halo", 0.6))
			_circle(sun, 6.0, _c("sun"))
		"ink":
			draw_texture_rect(paper_tex, Rect2(0, 0, W, H), false)
			draw_arc(sun, 5.5, 0.0, TAU, 32, _c("ink"), 0.35, false)
			for i in 12:
				var a := TAU * i / 12.0 + 0.13
				draw_line(sun + Vector2(cos(a), sin(a)) * 7.5, sun + Vector2(cos(a), sin(a)) * (10.0 if i % 2 == 0 else 9.0),
						_c("ink_light"), 0.3, false)
	_draw_birds()


func _draw_birds() -> void:
	var col := _c("bird")
	for i in 4:
		var x := fmod(t * 5.0 + i * 83.0, W + 40.0) - 20.0
		var y := 46.0 + i * 7.0 + sin(t * 1.3 + i) * 2.0
		var flap := 1.0 if fmod(t * 3.0 + i * 0.4, 1.0) < 0.5 else -0.3
		_line(Vector2(x - 2.0, y - flap), Vector2(x, y), col, 0.3)
		_line(Vector2(x, y), Vector2(x + 2.0, y - flap), col, 0.3)


func _draw_clouds() -> void:
	match fam:
		"pixel", "painted":
			var off := fmod(t * 1.2, W)
			if fam == "pixel":
				off = _snap(off)
			draw_texture_rect(cloud_tex, Rect2(-off, 0, W, H), false)
			draw_texture_rect(cloud_tex, Rect2(W - off, 0, W, H), false)
		"flat":
			for cl in CLOUDS:
				var x := fposmod(cl[0] - t * 1.2 + 40.0, W + 80.0) - 40.0
				var cy: float = cl[1]
				var rx: float = cl[2] * 0.55
				var ry: float = cl[3] * 0.9
				_circle(Vector2(x - rx * 0.45, cy), ry * 0.9, _c("cloud"))
				_circle(Vector2(x + rx * 0.1, cy - ry * 0.35), ry * 1.25, _c("cloud"))
				_circle(Vector2(x + rx * 0.55, cy + ry * 0.05), ry * 0.8, _c("cloud"))
				draw_rect(Rect2(x - rx * 0.45, cy, rx, ry * 0.9), _c("cloud"))
		"ink":
			for cl in CLOUDS:
				var x := fposmod(cl[0] - t * 1.2 + 40.0, W + 80.0) - 40.0
				var cy: float = cl[1]
				var rx: float = cl[2] * 0.5
				var ry: float = cl[3] * 0.7
				var ink := _c("ink_light")
				for i in 4:
					var bx := x - rx + (i + 0.5) * rx * 0.5
					var br := ry * (0.8 + 0.4 * _hash(i, cl[0]))
					draw_arc(Vector2(bx, cy), br, PI, TAU, 16, ink, 0.3, false)
				draw_line(Vector2(x - rx - ry * 0.4, cy), Vector2(x + rx + ry * 0.4, cy), ink, 0.3, false)


# ---------------------------------------------------------------- land

func _draw_mountains() -> void:
	for m in FAR_MOUNTAINS:
		_mountain(m[0], m[1], m[2], true)
	for m in NEAR_MOUNTAINS:
		_mountain(m[0], m[1], m[2], false)


func _mountain(px: float, py: float, w: float, far: bool) -> void:
	var base := HORIZON
	var lit := _c("mtn_far" if far else "mtn")
	var dark := _c("mtn_far_shade" if far else "mtn_shade")
	var left := [Vector2(px - w, base), Vector2(px, py), Vector2(px, base)]
	var right := [Vector2(px, py), Vector2(px + w, base), Vector2(px, base)]
	if fam == "painted":
		var haze: Color = pal.sky[pal.sky.size() - 1]
		draw_polygon(PackedVector2Array(left), PackedColorArray([lit.lerp(haze, 0.5), lit, lit.lerp(haze, 0.5)]))
		draw_polygon(PackedVector2Array(right), PackedColorArray([dark, dark.lerp(haze, 0.5), dark.lerp(haze, 0.5)]))
	else:
		_poly2(left, lit)
		_poly2(right, dark)
	var sh := (base - py) * 0.3
	var sw := w * 0.3
	if fam == "ink":
		var ink := _c("ink_light" if far else "ink")
		draw_polyline(PackedVector2Array([Vector2(px - w, base), Vector2(px, py), Vector2(px + w, base)]), ink, 0.35, false)
		# hatching down the shaded side
		var n := int(w / 2.2)
		for i in range(1, n):
			var f := float(i) / n
			var top := Vector2(px + w * f, py + (base - py) * f)
			draw_line(top, top + Vector2(-1.2, 3.0 + 4.0 * _hash(i, px)), _c("ink_light"), 0.22, false)
		draw_polyline(PackedVector2Array([Vector2(px - sw, py + sh), Vector2(px - sw * 0.4, py + sh * 0.7),
				Vector2(px, py + sh * 1.1), Vector2(px + sw * 0.5, py + sh * 0.8), Vector2(px + sw, py + sh)]),
				_c("ink_light"), 0.25, false)
		return
	_poly2([Vector2(px, py), Vector2(px, py + sh * 1.1), Vector2(px - sw * 0.3, py + sh * 0.75),
			Vector2(px - sw * 0.7, py + sh), Vector2(px - sw, py + sh)], _c("snow"))
	_poly2([Vector2(px, py), Vector2(px + sw, py + sh), Vector2(px + sw * 0.5, py + sh * 0.8),
			Vector2(px, py + sh * 1.1)], _c("snow_shade"))


func _hill_y(x: float) -> float:
	return 119.0 + sin(x * 0.045) * 3.0 + sin(x * 0.13) * 1.2


func _draw_hills() -> void:
	var pts := PackedVector2Array()
	for i in 41:
		pts.append(Vector2(i * 8.0, _hill_y(i * 8.0)))
	pts.append(Vector2(W, MEADOW))
	pts.append(Vector2(0, MEADOW))
	if fam == "ink":
		var ridge := PackedVector2Array()
		for i in 41:
			ridge.append(pts[i])
		draw_polyline(ridge, _c("ink_light"), 0.3, false)
		for i in 30:
			var x := i * 11.0 + _hash(i, 2.0) * 5.0
			var y := _hill_y(x) + 2.0
			draw_line(Vector2(x, y), Vector2(x, y - 2.0), _c("ink_light"), 0.25, false)
			draw_arc(Vector2(x, y - 3.2), 1.4, 0.0, TAU, 12, _c("ink_light"), 0.25, false)
		for i in 4:
			var y := 125.5 + i * 1.5
			var x := fmod(i * 47.0 + t * 1.5, 60.0)
			while x < W:
				draw_line(Vector2(x, y), Vector2(x + 14.0, y), _c("ink_light"), 0.22, false)
				x += 24.0 + i * 3.0
		return
	_poly(pts, _c("hill"))
	for i in 56:
		var x := i * 6.0 + _hash(i, 1.0) * 3.0
		var y := _hill_y(x) + 0.8
		var r := 1.8 + _hash(i, 9.0) * 1.6
		_circle(Vector2(x, y), r, _c("hill_tree"))
		if fam != "flat":
			_circle(Vector2(x - 0.5, y - 0.4), r * 0.6, _c("hill_tree_light"))
	_r(0, 124.5, W, MEADOW - 124.5, _c("lake"))
	for i in 18:
		var x := fmod(i * 37.0 + t * 2.0, W)
		_r(x, 125.5 + (i % 3) * 1.7, 3.0 + (i % 2) * 2.0, 0.5, _c("lake_light"))


func _draw_ground() -> void:
	match fam:
		"pixel", "painted":
			draw_texture_rect(ground_tex, Rect2(0, 0, W, H), false)
		"flat":
			draw_rect(Rect2(0, MEADOW, W, H - MEADOW), _c("grass"))
			draw_rect(Rect2(0, 160, W, H - 160), _c("grass_dark"))
		"ink":
			for i in 140:
				var x := _hash(i, 5.0) * W
				var y := MEADOW + 2.0 + _hash(i, 6.0) * (H - MEADOW - 4.0)
				draw_line(Vector2(x, y), Vector2(x - 0.6, y - 1.4), _c("ink_light"), 0.2, false)
				draw_line(Vector2(x, y), Vector2(x + 0.7, y - 1.2), _c("ink_light"), 0.2, false)
	# the road along the foot of the castle
	match fam:
		"ink":
			draw_line(Vector2(0, GY), Vector2(W, GY), _c("ink"), 0.35, false)
			var x := 0.0
			while x < W:
				draw_line(Vector2(x, 156.0), Vector2(x + 9.0, 156.0), _c("ink_light"), 0.3, false)
				x += 12.0
			for i in 50:
				_circle(Vector2(_hash(i, 21.0) * W, 151.5 + _hash(i, 22.0) * 3.5), 0.18, _c("ink_light"))
		_:
			_r(0, GY, W, 6.0, _c("path"))
			if fam != "flat":
				_r(0, GY, W, 0.6, _c("path_dark"))
				for i in 70:
					var px := _hash(i, 31.0) * W
					var py := GY + 1.0 + _hash(i, 32.0) * 4.5
					_r(px, py, 1.0, 0.5, _c("path_dark") if i % 3 else _c("path_light"))
				for i in 60:
					_r(_hash(i, 41.0) * W, 155.2 + _hash(i, 42.0), 0.6, 1.2, _c("grass_dark"))


# ---------------------------------------------------------------- stone

## One block of stone. k (0 to 1) picks its shade so the wall is not all one colour.
func _brick(r: Rect2, k: float) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	match fam:
		"pixel":
			_r(x, y, w, h, _c("mortar"))
			var c := _c("stone")
			if k < 0.18:
				c = _c("stone_light")
			elif k > 0.82:
				c = _c("stone_dark")
			_r(x, y, w - u, h - u, c)
			if s >= 2.0 and k > 0.3:
				_r(x, y, w - u, u, _c("stone_light"))
		"painted":
			draw_rect(r, _c("mortar"))
			var c := _c("stone_dark").lerp(_c("stone_light"), 0.25 + 0.6 * k)
			draw_rect(r.grow(-0.28), c)
			draw_rect(Rect2(x + 0.28, y + 0.28, w - 0.56, 0.5), Color(1, 1, 1, 0.18))
			draw_rect(Rect2(x + 0.28, y + h - 0.8, w - 0.56, 0.5), Color(0, 0, 0, 0.07))
		"ink":
			draw_rect(r, _c("stone").lerp(_c("stone_dark"), k * 0.4))
			draw_rect(r, Color(_c("ink_light"), 0.75), false, 0.22)
		"flat":
			draw_rect(r, _c("mortar"))
			draw_rect(r.grow(-0.35), _c("stone") if k < 0.7 else _c("stone_light"))


## A whole wall of blocks from top to bottom, used for the parts already standing.
func _wall_fill(x: float, top: float, w: float, bottom: float, seed: float) -> void:
	var b := block()
	var r := 0
	var y := bottom - b.y
	while y + b.y > top + 0.01:
		var row := _course(x, w, y, b, r)
		for i in row.size():
			var br := row[i]
			if br.position.y < top:
				br = Rect2(br.position.x, top, br.size.x, br.end.y - top)
			_brick(br, _hash(seed + r, i))
		r += 1
		y -= b.y


## Light on the left, shadow on the right, so a box or a round tower has some depth.
func _shade(x: float, top: float, w: float, bottom: float, round_tower: bool) -> void:
	var h := bottom - top
	if h <= 0.0:
		return
	match fam:
		"pixel":
			var dw := w * (0.28 if round_tower else 0.12)
			_r(x + w - dw, top, dw, h, _a("shadow", 0.28))
			if round_tower:
				_r(x + w - dw * 0.4, top, dw * 0.4, h, _a("shadow", 0.25))
				_r(x + w * 0.1, top, w * 0.14, h, _a("stone_light", 0.45))
		"painted":
			var sh := _a("shadow", 0.42 if round_tower else 0.3)
			var clear := _a("shadow", 0.0)
			var x0 := x + w * (0.45 if round_tower else 0.7)
			draw_polygon(PackedVector2Array([Vector2(x0, top), Vector2(x + w, top), Vector2(x + w, bottom), Vector2(x0, bottom)]),
					PackedColorArray([clear, sh, sh, clear]))
			if round_tower:
				var li := Color(1, 1, 1, 0.3)
				var no := Color(1, 1, 1, 0.0)
				draw_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + w * 0.3, top), Vector2(x + w * 0.3, bottom), Vector2(x, bottom)]),
						PackedColorArray([no, li, li, no]))
		"ink":
			_hatch(x + w * (0.7 if round_tower else 0.82), top, w * (0.3 if round_tower else 0.18), bottom, 0.9, _a("ink", 0.55))
		"flat":
			draw_rect(Rect2(x + w * (0.6 if round_tower else 0.8), top, w * (0.4 if round_tower else 0.2), h), _a("shadow", 0.12))


func _outline_box(x: float, top: float, w: float, bottom: float) -> void:
	_edge_rect(Rect2(x, top, w, bottom - top), 0.4)


## Battlements: merlons along the top of a wall.
func _merlons(x: float, y: float, w: float, mw: float, mh: float) -> void:
	var n := maxi(int((w + mw) / (mw * 2.0)), 2)
	var gap := (w - mw) / (n - 1)
	for i in n:
		var mx := x + i * gap
		_solid(mx, y - mh, mw, mh)
	_band(x - 0.5, y - 0.2, w + 1.0, 1.2)


func _solid(x: float, y: float, w: float, h: float) -> void:
	match fam:
		"pixel":
			_r(x, y, w, h, _c("stone"))
			_r(x, y, w, u, _c("stone_light"))
			_r(x + w - u, y, u, h, _c("stone_dark"))
		"painted":
			draw_rect(Rect2(x, y, w, h), _c("stone"))
			draw_rect(Rect2(x, y, w, 0.5), _c("stone_light"))
			draw_rect(Rect2(x + w * 0.65, y, w * 0.35, h), _a("shadow", 0.2))
			_edge_rect(Rect2(x, y, w, h), 0.3)
		"ink":
			draw_rect(Rect2(x, y, w, h), _c("stone"))
			draw_rect(Rect2(x, y, w, h), _c("ink"), false, 0.35)
		"flat":
			draw_rect(Rect2(x, y, w, h), _c("stone"))


## A plain ledge of darker stone, under battlements and roofs.
func _band(x: float, y: float, w: float, h: float) -> void:
	match fam:
		"ink":
			draw_rect(Rect2(x, y, w, h), _c("stone_dark"))
			draw_rect(Rect2(x, y, w, h), _c("ink"), false, 0.3)
		_:
			_r(x, y, w, h, _c("stone_dark"))
			if fam != "flat":
				_r(x, y + h - u, w, u, _a("shadow", 0.35))


func _window(cx: float, bottom: float, w: float, h: float) -> void:
	var lit: bool = style.get("lit", false)
	var col := _c("window_lit") if lit else _c("window")
	var x := cx - w * 0.5
	var top := bottom - h
	if lit:
		_circle(Vector2(cx, bottom - h * 0.5), h * 0.9, _a("window_lit", 0.12))
	match fam:
		"pixel":
			_r(x, top + u, w, h - u, col)
			_r(x + u, top, w - 2.0 * u, u, col)
			_r(x - u * 0.5, bottom, w + u, u, _c("stone_light"))
			if not lit:
				_r(x, top + u, w, u, _c("roof_dark"))
		"painted":
			draw_rect(Rect2(x, top + w * 0.5, w, h - w * 0.5), col)
			draw_circle(Vector2(cx, top + w * 0.5), w * 0.5, col, true, -1.0, false)
			draw_rect(Rect2(x - 0.3, bottom, w + 0.6, 0.6), _c("stone_light"))
		"ink":
			var pts := [Vector2(x, bottom), Vector2(x, top + w * 0.5), Vector2(cx, top), Vector2(x + w, top + w * 0.5), Vector2(x + w, bottom)]
			_poly2(pts, col.lerp(_c("paper"), 0.25))
			_ink_outline(pts, 0.3)
		"flat":
			draw_rect(Rect2(x, top + w * 0.5, w, h - w * 0.5), col)
			draw_circle(Vector2(cx, top + w * 0.5), w * 0.5, col, true, -1.0, false)


func _door(cx: float, bottom: float, w: float, h: float, gate := false) -> void:
	var x := cx - w * 0.5
	var top := bottom - h
	var arch := w * 0.5
	match fam:
		"ink":
			var pts := [Vector2(x, bottom), Vector2(x, top + arch), Vector2(cx, top), Vector2(x + w, top + arch), Vector2(x + w, bottom)]
			_poly2(pts, _c("door"))
			_ink_outline(pts, 0.35)
			var lx := x + 1.5
			while lx < x + w - 0.5:
				draw_line(Vector2(lx, top + arch * 0.6), Vector2(lx, bottom), _c("ink_light"), 0.22, false)
				lx += 1.5
		_:
			_r(x, top + arch, w, h - arch, _c("door"))
			if fam == "pixel":
				var steps := int(arch / u)
				for i in steps:
					var f := float(i) / maxf(steps, 1)
					var half := w * 0.5 * sqrt(1.0 - (1.0 - f) * (1.0 - f))
					_r(cx - half, top + i * u, half * 2.0, u, _c("door"))
			else:
				draw_circle(Vector2(cx, top + arch), arch, _c("door"), true, -1.0, false)
			if gate:
				var gx := x + 1.0
				while gx < x + w - 0.5:
					_r(gx, top + 1.0, 0.5, h - 1.0, _c("door_dark"))
					gx += 2.0
				_r(x, top + h * 0.45, w, 0.5, _c("door_dark"))
			else:
				var lx := x + w / 3.0
				while lx < x + w - 0.5:
					_r(lx, top + arch * 0.6, 0.5 if fam != "pixel" else u, h - arch * 0.6, _c("door_dark"))
					lx += w / 3.0
				_r(x, top + h * 0.6, w, 0.6 if fam != "pixel" else u, _c("door_dark"))


## A pointed roof: a cone on a round tower, or a house's gable.
func _roof(x0: float, x1: float, base: float, rh: float, light: String, main: String, dark: String) -> void:
	var cx := (x0 + x1) * 0.5
	var half := (x1 - x0) * 0.5
	var apex := base - rh
	match fam:
		"pixel":
			var rows := int(rh / u)
			for i in rows:
				var y := apex + i * u
				var f := float(i + 1) / rows
				var hw := half * f
				var band := int((y - apex) / 1.5) % 3 == 2
				var col := _c(dark) if band else _c(main)
				_r(cx - hw, y, hw * 2.0, u, col)
				_r(cx - hw, y, hw * 0.7, u, _c(dark) if band else _c(light))
				_r(cx + hw * 0.65, y, hw * 0.35, u, _c(dark))
			_r(x0, base - u, x1 - x0, u, _c(dark))
		"painted":
			var l := _c(light)
			var m := _c(main)
			var d := _c(dark)
			draw_polygon(PackedVector2Array([Vector2(x0, base), Vector2(cx, apex), Vector2(cx, base)]), PackedColorArray([l, l.lerp(m, 0.5), m]))
			draw_polygon(PackedVector2Array([Vector2(cx, apex), Vector2(x1, base), Vector2(cx, base)]), PackedColorArray([m, d, m.lerp(d, 0.4)]))
			var rows := int(rh / 1.6)
			for i in range(1, rows):
				var f := float(i) / rows
				var y := apex + rh * f
				draw_line(Vector2(cx - half * f, y), Vector2(cx + half * f, y), Color(d, 0.45), 0.25, false)
			draw_rect(Rect2(x0, base - 0.6, x1 - x0, 0.6), d)
			_ink_outline([Vector2(x0, base), Vector2(cx, apex), Vector2(x1, base)], 0.4)
		"ink":
			var pts := [Vector2(x0, base), Vector2(cx, apex), Vector2(x1, base)]
			_poly2(pts, _c(main))
			_ink_outline(pts, 0.4)
			var n := int(half / 1.4)
			for i in range(1, n):
				var bx := cx + half * float(i) / n
				draw_line(Vector2(cx, apex), Vector2(bx, base), _a("ink", 0.5), 0.2, false)
		"flat":
			_poly2([Vector2(x0, base), Vector2(cx, apex), Vector2(cx, base)], _c(light))
			_poly2([Vector2(cx, apex), Vector2(x1, base), Vector2(cx, base)], _c(main))


func _flag(x: float, y: float) -> void:
	var top := y - 9.0
	var wave := sin(t * 4.0 + x) * 0.7
	var pole := _c("ink") if fam == "ink" else _c("wood_dark")
	_line(Vector2(x, y), Vector2(x, top), pole, 0.35)
	var pts := [Vector2(x + 0.3, top), Vector2(x + 6.5, top + 1.6 + wave), Vector2(x + 0.3, top + 3.5)]
	_poly2(pts, _c("flag"))
	_poly2([Vector2(x + 0.3, top + 1.2), Vector2(x + 4.5, top + 1.9 + wave * 0.7), Vector2(x + 0.3, top + 2.4)], _c("flag2"))
	if _edged():
		_ink_outline(pts, 0.25)


# ---------------------------------------------------------------- castle

func _draw_wall() -> void:
	# curtain wall
	_wall_fill(10.0, 126.0, 60.0, GY, 1.0)
	_shade(10.0, 126.0, 60.0, GY, false)
	_outline_box(10.0, 126.0, 60.0, GY)
	_draw_guard()
	_merlons(10.0, 126.0, 60.0, 3.0, 3.0)
	# gate tower
	_wall_fill(22.0, 106.0, 22.0, GY, 5.0)
	_shade(22.0, 106.0, 22.0, GY, false)
	_outline_box(22.0, 106.0, 22.0, GY)
	_merlons(21.0, 106.0, 24.0, 3.0, 3.5)
	_door(33.0, GY, 10.0, 15.0, true)
	_window(33.0, 120.0, 2.5, 5.0)
	if style.get("lit", false):
		_torch(46.5, 136.0)


func _torch(x: float, y: float) -> void:
	var f := 0.8 + 0.2 * sin(t * 13.0) * sin(t * 7.3)
	_circle(Vector2(x, y - 1.5), 6.0 * f, _a("window_lit", 0.12))
	_circle(Vector2(x, y - 1.5), 3.0 * f, _a("window_lit", 0.25))
	_r(x - 0.4, y - 1.0, 0.8, 3.0, _c("wood_dark"))
	_r(x - 0.6, y - 2.6 * f, 1.2, 1.8 * f, _c("flag2"))


func _draw_tower(x: float, top: float, w: float) -> void:
	_wall_fill(x, top, w, GY, 9.0)
	_shade(x, top, w, GY, true)
	_outline_box(x, top, w, GY)
	_window(x + w * 0.5, 118.0, 3.0, 6.0)
	_window(x + w * 0.5, 136.0, 3.0, 6.0)
	_band(x - 1.0, top - 1.5, w + 2.0, 1.8)
	_roof(x - 2.0, x + w + 2.0, top - 1.4, 30.0, "roof_light", "roof", "roof_dark")
	_flag(x + w * 0.5, top - 31.0)


func _draw_keep() -> void:
	var b := block()
	for i in laid:
		_brick(bricks[i], _hash(i, 11.0))
	var top := keep_top if finished else deck_y
	_shade(KEEP_X, top, KEEP_W, GY, false)
	_outline_box(KEEP_X, top, KEEP_W, GY)
	# windows show once the wall round them is laid
	for wy in [GY - 24.0, GY - 50.0, GY - 72.0]:
		for wx in [KEEP_X + 11.0, KEEP_X + KEEP_W - 11.0]:
			if wy - 7.0 >= top:
				_window(wx, wy, 4.0, 7.0)
			elif wy > top:
				_r(wx - 2.0, top, 4.0, wy - top, _c("window_lit") if style.get("lit", false) else _c("window"))
	_door(KEEP_X + KEEP_W * 0.5, GY, 9.0, 13.0)
	if finished:
		_merlons(KEEP_X - 1.0, keep_top, KEEP_W + 2.0, 4.0, 4.0)
		_flag(KEEP_X + KEEP_W * 0.5, keep_top - 4.0)
	elif laid < bricks.size() and b.y > 0.0:
		# the next block, lying ready on the deck beside where it goes
		pass


## The building works: the ladder up the keep, the hoist on its deck with the
## rope down to the yard, the bench where blocks are shaped, and the piles.
func _draw_works() -> void:
	var b := block()
	var cb := Vector2(minf(b.x, 5.0), minf(b.y, 3.0))
	# bench
	_r(167.0, GY - 4.5, 10.0, 1.0, _c("wood"))
	_r(168.0, GY - 3.5, 0.8, 3.5, _c("wood_dark"))
	_r(175.2, GY - 3.5, 0.8, 3.5, _c("wood_dark"))
	if _edged():
		draw_rect(Rect2(167.0, GY - 4.5, 10.0, 1.0), _edge_colour(), false, 0.25)
	_brick(Rect2(169.0, GY - 4.5 - cb.y, cb.x, cb.y), 0.5)
	# stone pile
	var px := 199.0
	for row in 3:
		for i in 3 - row:
			_brick(Rect2(px + i * cb.x + row * cb.x * 0.5, GY - (row + 1) * cb.y, cb.x, cb.y), _hash(row, i))
	# log pile
	for i in 4:
		var lx := 216.0 + i * 2.6 + (1.3 if i == 3 else 0.0)
		var ly := GY - 1.4 - (2.4 if i == 3 else 0.0)
		if i == 3:
			lx = 218.6
		_circle(Vector2(lx, ly), 1.3, _c("wood"))
		_circle(Vector2(lx, ly), 0.6, _c("wood_dark"))
		if _edged():
			draw_arc(Vector2(lx, ly), 1.3, 0.0, TAU, 12, _edge_colour(), 0.25, false)
	if finished:
		return
	# ladder against the keep
	var lt := deck_y - 3.0
	var wood := _c("ink") if fam == "ink" else _c("wood")
	_line(Vector2(153.5, GY), Vector2(153.5, lt), wood, 0.4)
	_line(Vector2(156.5, GY), Vector2(156.5, lt), wood, 0.4)
	var ry := GY - 1.5
	while ry > lt:
		_line(Vector2(153.5, ry), Vector2(156.5, ry), wood, 0.3)
		ry -= 2.5
	# hoist on the deck: an A-frame with a beam out over the yard
	var top := deck_y - 10.0
	_line(Vector2(144.5, deck_y), Vector2(147.0, top), _c("wood_dark") if fam != "ink" else wood, 0.45)
	_line(Vector2(149.5, deck_y), Vector2(147.0, top), _c("wood_dark") if fam != "ink" else wood, 0.45)
	_line(Vector2(145.0, top), Vector2(ROPE_X + 0.8, top), wood, 0.5)
	_circle(Vector2(ROPE_X, top + 0.6), 0.9, _c("wood_dark"))
	# the rope and what hangs on it
	var rc := fmod(t / 6.0, 1.0)
	var end_y := GY - cb.y - 0.4
	var has_block := true
	if rc >= 0.2 and rc < 0.85:
		end_y = lerpf(GY - cb.y - 0.4, deck_y - cb.y - 3.0, (rc - 0.2) / 0.65)
	elif rc >= 0.85:
		end_y = deck_y - 5.0
		has_block = false
	var rope := Color(0.35, 0.28, 0.2) if fam != "ink" else _c("ink_light")
	_line(Vector2(ROPE_X, top + 1.4), Vector2(ROPE_X, end_y), rope, 0.25)
	_line(Vector2(ROPE_X, top + 1.2), Vector2(147.5, deck_y - 6.0), rope, 0.25)
	if has_block:
		_brick(Rect2(ROPE_X - cb.x * 0.5, end_y + 0.4, cb.x, cb.y), 0.4)


# ---------------------------------------------------------------- village

func _draw_village() -> void:
	_pine(231.0, GY, 15.0)
	_house(238.0, 131.0, 24.0, 15.0, 1.0)
	_well(270.0)
	_house(280.0, 135.0, 18.0, 12.0, 2.0)
	_round_tree(306.0, GY, 7.0)
	_pine(316.0, GY, 12.0)
	_pine(93.0, GY, 9.0)


func _house(x: float, top: float, w: float, rh: float, seed: float) -> void:
	var timber := _c("ink") if fam == "ink" else _c("timber")
	_r(x, top, w, GY - top, _c("plaster"))
	var tw := 0.9 if fam != "pixel" else u
	if fam != "flat" or true:
		_r(x, top, tw, GY - top, timber)
		_r(x + w - tw, top, tw, GY - top, timber)
		_r(x + w * 0.5 - tw * 0.5, top, tw, GY - top, timber)
		_r(x, top, w, tw, timber)
		_r(x, top + (GY - top) * 0.5, w, tw, timber)
		if fam != "flat":
			var mid := top + (GY - top) * 0.5
			_line(Vector2(x + 0.5, mid), Vector2(x + w * 0.5 - 0.5, top + 0.5), timber, 0.45)
			_line(Vector2(x + w - 0.5, mid), Vector2(x + w * 0.5 + 0.5, top + 0.5), timber, 0.45)
	_window(x + w * 0.25, top + (GY - top) * 0.5 - 1.5, 3.0, 3.5)
	_window(x + w * 0.75, top + (GY - top) * 0.5 - 1.5, 3.0, 3.5)
	_door(x + w * 0.75, GY, 3.5, 6.0)
	_window(x + w * 0.25, GY - 2.0, 3.0, 3.0)
	if _edged():
		draw_rect(Rect2(x, top, w, GY - top), _edge_colour(), false, 0.35)
	# chimney, then the roof over it
	_r(x + w * 0.72, top - rh * 0.75, 2.5, rh * 0.5, _c("stone_dark"))
	_roof(x - 3.0, x + w + 3.0, top + 0.5, rh, "house_roof_light", "house_roof", "house_roof_dark")
	if fam != "ink":
		var smoke := fmod(t * 0.4 + seed * 0.37, 1.0)
		for i in 3:
			var f := fmod(smoke + i / 3.0, 1.0)
			_circle(Vector2(x + w * 0.72 + 1.2 + f * 4.0, top - rh * 0.8 - f * 10.0), 0.6 + f * 1.4, Color(0.9, 0.9, 0.92, 0.5 * (1.0 - f)))


func _well(x: float) -> void:
	_r(x - 3.0, GY - 3.0, 6.0, 3.0, _c("stone"))
	_r(x - 3.0, GY - 3.0, 6.0, 0.7, _c("stone_light"))
	_r(x - 2.8, GY - 9.0, 0.6, 6.0, _c("wood_dark"))
	_r(x + 2.2, GY - 9.0, 0.6, 6.0, _c("wood_dark"))
	_roof(x - 4.0, x + 4.0, GY - 8.5, 3.0, "house_roof_light", "house_roof", "house_roof_dark")
	if _edged():
		draw_rect(Rect2(x - 3.0, GY - 3.0, 6.0, 3.0), _edge_colour(), false, 0.3)


func _pine(x: float, base: float, h: float) -> void:
	_r(x - 0.6, base - 2.5, 1.2, 2.5, _c("trunk"))
	for i in 3:
		var f := float(i) / 3.0
		var w := h * (0.42 - f * 0.1)
		var bot := base - 2.0 - h * f * 0.55
		var top := bot - h * 0.5
		var pts := [Vector2(x - w, bot), Vector2(x, top), Vector2(x + w, bot)]
		match fam:
			"ink":
				_poly2(pts, _c("leaf"))
				_ink_outline(pts, 0.3)
			"flat":
				_poly2(pts, _c("leaf"))
				_poly2([Vector2(x, top), Vector2(x + w, bot), Vector2(x, bot)], _c("leaf_dark"))
			_:
				_poly2(pts, _c("leaf_dark"))
				_poly2([Vector2(x - w * 0.8, bot - 0.6), Vector2(x, top + 0.6), Vector2(x + w * 0.1, bot - 0.6)], _c("leaf"))
				_poly2([Vector2(x - w * 0.55, bot - 1.2), Vector2(x - w * 0.1, top + 2.0), Vector2(x - w * 0.15, bot - 1.2)], _c("leaf_light"))
				if fam == "painted":
					_ink_outline(pts, 0.3)


func _round_tree(x: float, base: float, r: float) -> void:
	_r(x - 0.8, base - r, 1.6, r, _c("trunk"))
	var c := Vector2(x, base - r * 1.5)
	match fam:
		"ink":
			_circle(c, r, _c("leaf"))
			draw_arc(c, r, 0.0, TAU, 32, _c("ink"), 0.35, false)
			_hatch(c.x + r * 0.2, c.y - r * 0.5, r * 0.7, c.y + r * 0.7, 0.9, _a("ink", 0.4))
		"flat":
			_circle(c, r, _c("leaf"))
		_:
			_circle(c + Vector2(0.6, 0.6), r, _c("leaf_dark"))
			_circle(c + Vector2(-0.6, -0.4), r * 0.8, _c("leaf"))
			_circle(c + Vector2(-1.8, -1.8), r * 0.4, _c("leaf_light"))
			if fam == "painted":
				draw_arc(c + Vector2(0.3, 0.3), r + 0.3, 0.0, TAU, 32, _edge_colour(), 0.3, false)


# ---------------------------------------------------------------- people

func _tunic(i: int) -> Color:
	var list: Array = pal.tunics
	return list[i % list.size()]


func _draw_people() -> void:
	var b := block()
	var cb := Vector2(minf(b.x, 5.0), minf(b.y, 3.0))
	var rc := fmod(t / 6.0, 1.0)
	# shaper at the bench
	var hp := fmod(t * 1.4, 1.0)
	_person(180.0, GY + 1.0, -1.0, "hammer", hp, _tunic(0))
	if hp > 0.7 and hp < 0.95:
		var f := (hp - 0.7) / 0.25
		for i in 3:
			var d := Vector2(-1.5 + i * 1.5, -2.0 - i * 0.5) * f * 2.0
			_circle(Vector2(171.5, GY - 4.5 - cb.y) + d + Vector2(0, f * f * 3.0), 0.35, _c("stone_light"))
	# carrier from the stone pile to the bench
	var cf := fmod(t / 9.0, 1.0)
	if cf < 0.42:
		_person(lerpf(208.0, 187.0, cf / 0.42), GY + 1.6, -1.0, "walk", fmod(t * 2.2, 1.0), _tunic(3), true)
	elif cf < 0.52:
		_person(187.0, GY + 1.6, -1.0, "idle", 0.0, _tunic(3))
	elif cf < 0.94:
		_person(lerpf(187.0, 208.0, (cf - 0.52) / 0.42), GY + 1.6, 1.0, "walk", fmod(t * 2.2, 1.0), _tunic(3))
	else:
		_person(208.0, GY + 1.6, 1.0, "idle", 0.0, _tunic(3), true)
	# villager on the road
	var vl := fmod(t * 5.0, 136.0)
	var vx := 232.0 + pingpong(t * 5.0, 68.0)
	_person(vx, GY + 3.5, 1.0 if vl < 68.0 else -1.0, "walk", fmod(t * 2.0, 1.0), _tunic(5))
	if finished:
		_person(163.0, GY + 1.0, -1.0, "idle", 0.0, _tunic(2))
		_person(158.0, GY + 2.0, 1.0, "idle", 0.0, _tunic(1))
		_person(152.0, GY + 1.5, 1.0, "idle", 0.0, _tunic(4))
		return
	# the one who ties blocks on the rope
	_person(164.0, GY + 1.0, -1.0, "tie" if rc < 0.2 else "idle", rc, _tunic(2))
	# the hauler at the hoist
	_person(143.0, deck_y, 1.0, "pull" if rc >= 0.2 and rc < 0.85 else "idle", fmod(t * 2.0, 1.0), _tunic(1))
	# the mason setting the next block
	if laid < bricks.size():
		var nb := bricks[laid]
		# beside the block, on the part of the deck not yet laid, but clear of the hoist
		var mx := nb.end.x + 1.8
		var dir := -1.0
		var fy := deck_y
		if mx > 139.0:
			mx = minf(nb.position.x - 1.8, 139.0)
			dir = 1.0
			fy = nb.position.y if laid > 0 and bricks[laid - 1].position.y == nb.position.y else deck_y
		_person(mx, fy, dir, "set", fmod(t * 0.9, 1.0), _tunic(4))
	# someone climbing the ladder
	var lf := absf(fmod(t / 7.0, 1.0) * 2.0 - 1.0)
	_person(155.0, lerpf(GY, deck_y + 1.0, lf), 1.0, "climb", fmod(t * 2.5, 1.0), _tunic(0))


func _draw_guard() -> void:
	var gx := 50.0 + sin(t * 0.25) * 12.0
	var dir := 1.0 if cos(t * 0.25) > 0.0 else -1.0
	_person(gx, 126.0, dir, "guard", fmod(t * 0.6, 1.0), _c("roof_dark"))


## A peasant. fy is where their feet are, dir which way they face.
func _person(x: float, fy: float, dir: float, pose: String, ph: float, tunic: Color, load := false) -> void:
	if fam == "pixel":
		x = _snap(x)
		fy = _snap(fy)
	var b := block()
	var cb := Vector2(minf(b.x, 5.0), minf(b.y, 3.0))
	var kd := 0.0
	if pose == "set":
		kd = 1.6 * clampf(sin(ph * TAU) * 1.6, 0.0, 1.0)
	elif pose == "tie":
		kd = 1.0
	var skin := _c("skin")
	var legs := _c("legs")
	if fam == "painted" or fam == "flat":
		_ellipse(Vector2(x, fy), 2.2, 0.55, Color(0, 0, 0, 0.16))
	# legs
	var step := sin(ph * TAU) if pose == "walk" else 0.0
	if pose == "climb":
		var up := 1.0 if ph < 0.5 else 0.0
		_limb(Vector2(x - 0.6, fy - 2.4), Vector2(x - 0.6, fy - up), legs)
		_limb(Vector2(x + 0.6, fy - 2.4), Vector2(x + 0.6, fy - 1.0 + up), legs)
	elif kd > 0.5:
		_limb(Vector2(x, fy - 2.4 + kd), Vector2(x - dir * 1.2, fy), legs)
		_limb(Vector2(x, fy - 2.4 + kd), Vector2(x + dir * 1.0, fy - 0.2), legs)
	else:
		_limb(Vector2(x - 0.6, fy - 2.4), Vector2(x - 0.6 + step * 0.9, fy), legs)
		_limb(Vector2(x + 0.6, fy - 2.4), Vector2(x + 0.6 - step * 0.9, fy), legs)
	var sh := Vector2(x + dir * 0.3, fy - 5.6 + kd)
	if load:
		_brick(Rect2(x - dir * 1.4 - cb.x * 0.5, fy - 6.4 - cb.y + kd, cb.x, cb.y), 0.3)
	_body(x, fy - 6.4 + kd, fy - 2.2 + kd, dir, tunic)
	_head(x, fy - 7.5 + kd, dir, pose == "climb")
	match pose:
		"walk":
			if load:
				_limb(sh, Vector2(x - dir * 0.6, fy - 6.6), skin)
			else:
				_limb(sh, sh + Vector2(-step * 0.9, 2.6), skin)
		"hammer":
			var a := 0.0
			if ph < 0.7:
				a = lerpf(0.6, -2.0, smoothstep(0.0, 1.0, ph / 0.7))
			else:
				a = lerpf(-2.0, 0.6, (ph - 0.7) / 0.3)
			var dv := Vector2(cos(a) * dir, sin(a))
			var hand := sh + dv * 2.3
			_limb(sh, hand, skin)
			var head := hand + dv * 1.8
			_line(hand, head, _c("wood_dark") if fam != "ink" else _c("ink"), 0.35)
			_r(head.x - 0.6, head.y - 0.6, 1.2, 1.2, Color(0.3, 0.3, 0.35))
		"pull":
			var hand := sh + Vector2(dir * 2.0, -1.2 + sin(ph * TAU) * 1.2)
			_limb(sh, hand, skin)
			_limb(sh + Vector2(-dir * 0.4, 0.3), hand + Vector2(-dir * 0.4, 0.8), skin)
		"climb":
			var up := 1.0 if ph < 0.5 else 0.0
			_limb(Vector2(x - 1.0, fy - 6.0), Vector2(x - 1.3, fy - 9.4 + up), skin)
			_limb(Vector2(x + 1.0, fy - 6.0), Vector2(x + 1.3, fy - 8.4 - up), skin)
		"set":
			var hand := Vector2(x + dir * 2.6, fy - 2.0 + kd * 0.5)
			_limb(sh, hand, skin)
			if ph < 0.45:
				_brick(Rect2(hand.x - cb.x * 0.5 + dir * cb.x * 0.4, hand.y - cb.y * 0.6, cb.x, cb.y), 0.6)
		"tie":
			_limb(sh, Vector2(x + dir * 2.4, fy - 1.6 + sin(ph * 40.0) * 0.4), skin)
		"guard":
			var sx := x + dir * 1.6
			_line(Vector2(sx, fy - 0.5), Vector2(sx, fy - 12.0), _c("wood_dark") if fam != "ink" else _c("ink"), 0.3)
			_poly2([Vector2(sx - 0.6, fy - 12.0), Vector2(sx, fy - 14.0), Vector2(sx + 0.6, fy - 12.0)], Color(0.75, 0.78, 0.82))
			_limb(sh, Vector2(sx, fy - 5.0), skin)
		_:
			_limb(sh, sh + Vector2(dir * 0.2, 2.6), skin)


func _limb(a: Vector2, b: Vector2, c: Color) -> void:
	match fam:
		"pixel":
			_line(a, b, c)
		"painted":
			draw_line(a, b, c, 0.75, false)
		"ink":
			draw_line(a, b, _c("ink"), 0.35, false)
		"flat":
			draw_line(a, b, c, 0.9, false)
			draw_circle(b, 0.45, c, true, -1.0, false)


func _body(x: float, top: float, bottom: float, dir: float, c: Color) -> void:
	match fam:
		"pixel":
			_r(x - 1.5, top, 3.0, bottom - top, c)
			if s >= 2.0:
				_r(x - 1.5 if dir > 0.0 else x + 1.0, top, 0.5, bottom - top, c.darkened(0.25))
				_r(x - 1.5, bottom - 1.0, 3.0, 0.5, _c("legs"))
		"painted":
			var pts := PackedVector2Array([Vector2(x - 1.1, top), Vector2(x + 1.1, top), Vector2(x + 1.7, bottom), Vector2(x - 1.7, bottom)])
			draw_colored_polygon(pts, c)
			var back := x - dir * 1.7
			draw_colored_polygon(PackedVector2Array([Vector2(x - dir * 1.1, top), Vector2(x - dir * 0.3, top), Vector2(x - dir * 0.5, bottom), Vector2(back, bottom)]), c.darkened(0.2))
			draw_rect(Rect2(x - 1.5, bottom - 1.0, 3.0, 0.45), c.darkened(0.45))
			_ink_outline([Vector2(x - 1.1, top), Vector2(x + 1.1, top), Vector2(x + 1.7, bottom), Vector2(x - 1.7, bottom)], 0.3)
		"ink":
			var pts := [Vector2(x - 1.1, top), Vector2(x + 1.1, top), Vector2(x + 1.7, bottom), Vector2(x - 1.7, bottom)]
			_poly2(pts, c)
			_ink_outline(pts, 0.3)
		"flat":
			draw_colored_polygon(PackedVector2Array([Vector2(x - 1.2, top), Vector2(x + 1.2, top), Vector2(x + 1.6, bottom), Vector2(x - 1.6, bottom)]), c)
			draw_circle(Vector2(x, top + 0.6), 1.2, c, true, -1.0, false)


func _head(x: float, cy: float, dir: float, back_view: bool) -> void:
	var skin := _c("skin")
	var hair := _c("hair")
	match fam:
		"pixel":
			_r(x - 1.0, cy - 1.0, 2.0, 2.0, hair if back_view else skin)
			_r(x - 1.0, cy - 1.5, 2.0, 1.0, hair)
			if not back_view:
				_r(x - 1.5 if dir > 0.0 else x + 1.0, cy - 1.3, 0.5, 1.6, hair)
				if s >= 2.0:
					_r(x + dir * 0.5 - 0.25, cy - 0.3, 0.5, 0.5, Color(0.15, 0.1, 0.1))
		"painted", "flat":
			if back_view:
				draw_circle(Vector2(x, cy), 1.2, hair, true, -1.0, false)
				return
			draw_circle(Vector2(x, cy), 1.15, skin, true, -1.0, false)
			draw_circle(Vector2(x - dir * 0.35, cy - 0.45), 0.95, hair, true, -1.0, false)
			draw_circle(Vector2(x + dir * 0.3, cy + 0.15), 0.85, skin, true, -1.0, false)
			if fam == "painted":
				draw_circle(Vector2(x + dir * 0.6, cy - 0.05), 0.16, Color(0.15, 0.1, 0.1), true, -1.0, false)
				draw_arc(Vector2(x, cy), 1.2, 0.0, TAU, 20, _edge_colour(), 0.22, false)
		"ink":
			draw_circle(Vector2(x, cy), 1.15, hair if back_view else skin, true, -1.0, false)
			draw_arc(Vector2(x, cy), 1.15, 0.0, TAU, 16, _c("ink"), 0.3, false)
			if not back_view:
				draw_arc(Vector2(x, cy), 1.15, PI + 0.2 - (0.0 if dir > 0.0 else 0.0), TAU - 0.2, 8, _c("ink"), 0.55, false)
