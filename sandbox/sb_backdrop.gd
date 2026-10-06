extends Node2D
## The sandbox's backdrop, after the art direction: dithered sky, blue
## low-contrast mountains far back, a hill line, then the ground band with
## depth and a dirt path along it, and a darker strip at the very front.

const SbData := preload("res://sandbox/sb_data.gd")
const LEFT := -900.0
const RIGHT := 1200.0


func _draw() -> void:
	var w := RIGHT - LEFT
	# Sky in bands, with a 4x4 ordered dither where two bands meet.
	var bands := [[-400.0, SbData.SKY1], [-170.0, SbData.SKY2], [-95.0, SbData.SKY3]]
	for i in bands.size():
		var top: float = bands[i][0]
		var bottom: float = bands[i + 1][0] if i + 1 < bands.size() else 0.0
		draw_rect(Rect2(LEFT, top, w, bottom - top), bands[i][1])
	for i in range(1, bands.size()):
		_dither(bands[i][0] - 6.0, 6.0, bands[i][1])
	# Mountains: low contrast, blue.
	var x := LEFT
	var k := 0
	while x < RIGHT:
		var peak := 45.0 + float((k * 37) % 40)
		var half := 60.0 + float((k * 23) % 40)
		draw_colored_polygon(PackedVector2Array([Vector2(x, -20), Vector2(x + half, -20 - peak), Vector2(x + half * 2.0, -20)]), SbData.MTN0 if k % 2 == 0 else SbData.MTN1)
		draw_colored_polygon(PackedVector2Array([Vector2(x + half * 0.75, -20 - peak * 0.75), Vector2(x + half, -20 - peak), Vector2(x + half * 1.25, -20 - peak * 0.75)]), SbData.WHITE)
		x += half * 1.4
		k += 1
	# Hills just behind the ground.
	var pts := PackedVector2Array([Vector2(LEFT, 0)])
	x = LEFT
	while x <= RIGHT:
		pts.append(Vector2(x, -18.0 - 8.0 * sin(x / 70.0) - 4.0 * sin(x / 23.0)))
		x += 8.0
	pts.append(Vector2(RIGHT, 0))
	draw_colored_polygon(pts, SbData.GRASS1)
	_draw_castle()
	# The ground band: grass, a strip of earth at the back where buildings stand.
	draw_rect(Rect2(LEFT, -2, w, SbData.GROUND_DEPTH + 2), SbData.GRASS2)
	draw_rect(Rect2(LEFT, -2, w, 4), SbData.GRASS1)
	# The dirt path runs along the middle of the band, gently winding.
	x = LEFT
	while x < RIGHT:
		# Keep in step with sandbox.gd path_y.
		var y := 34.0 + 6.0 * sin(x / 90.0)
		draw_rect(Rect2(x, y, 4, 9), SbData.DIRT)
		draw_rect(Rect2(x, y + 9, 4, 1), SbData.DIRT.darkened(0.2))
		x += 4.0
	# Tufts and flowers, placed the same way every time.
	for i in 500:
		var tx := LEFT + fmod(float(i) * 97.31, w)
		var ty := fmod(float(i) * 31.7, SbData.GROUND_DEPTH)
		var c := SbData.GRASS3 if i % 3 else SbData.GRASS4
		if i % 29 == 0:
			c = SbData.GOLD
		draw_rect(Rect2(tx, ty, 1, 2 if i % 2 else 1), c)
	# Front strip, darker.
	draw_rect(Rect2(LEFT, SbData.GROUND_DEPTH, w, 200), SbData.GRASS1)
	_dither(SbData.GROUND_DEPTH - 4.0, 4.0, SbData.GRASS1)


## A 4x4 ordered dither of colour c over a strip, half filled.
func _dither(top: float, height: float, c: Color) -> void:
	var y := top
	while y < top + height:
		var x := LEFT + float(int(y) % 2)
		while x < RIGHT:
			draw_rect(Rect2(x, y, 1, 1), c)
			x += 2.0
		y += 1.0


## The castle's curtain wall at the back of the courtyard, with two towers:
## plainer and cooler than what stands in front of it, so the eye goes there.
func _draw_castle() -> void:
	var left := -340.0
	var right := 130.0
	var top := -58.0
	draw_rect(Rect2(left, top, right - left, -top), SbData.STONE1)
	# Courses of stone, a shade darker every other row.
	var y := top + 6.0
	var row := 0
	while y < 0.0:
		var off := 6.0 if row % 2 else 0.0
		var x := left + off
		while x < right:
			draw_rect(Rect2(x, y, 1, 6), SbData.STONE0)
			x += 12.0
		draw_rect(Rect2(left, y, right - left, 1), SbData.STONE0)
		y += 6.0
		row += 1
	# Battlements and the wall walk.
	var x := left
	while x < right:
		draw_rect(Rect2(x, top - 6.0, 6, 6), SbData.STONE1)
		draw_rect(Rect2(x, top - 6.0, 6, 1), SbData.STONE2)
		x += 12.0
	draw_rect(Rect2(left, top, right - left, 1), SbData.STONE2)
	for tx in [left - 10.0, right - 18.0]:
		draw_rect(Rect2(tx, top - 30.0, 28, 30 - top), SbData.STONE1)
		draw_rect(Rect2(tx, top - 30.0, 1, 30 - top), SbData.STONE2)
		draw_rect(Rect2(tx + 13.0, top - 14.0, 2, 6), SbData.INK)
		draw_rect(Rect2(tx + 13.0, top + 14.0, 2, 6), SbData.INK)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 3.0, top - 30.0), Vector2(tx + 14.0, top - 52.0), Vector2(tx + 31.0, top - 30.0)]), SbData.SLATE1)
		draw_line(Vector2(tx + 14.0, top - 52.0), Vector2(tx + 14.0, top - 60.0), SbData.WOOD0, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tx + 14.0, top - 60.0), Vector2(tx + 20.0, top - 58.0), Vector2(tx + 14.0, top - 56.0)]), SbData.RED1)
	# The gate at the east end, where peasants shelter when the bell rings.
	draw_rect(Rect2(right - 52.0, -26.0, 22, 26), SbData.INK)
	draw_rect(Rect2(right - 52.0, -26.0, 4, 26), SbData.WOOD0)
	draw_rect(Rect2(right - 34.0, -26.0, 4, 26), SbData.WOOD0)
	draw_rect(Rect2(right - 52.0, -26.0, 22, 2), SbData.STONE3)
