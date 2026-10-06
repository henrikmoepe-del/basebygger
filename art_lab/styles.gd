extends RefCounted
## The art styles the art lab can show. Each style says how big the pixels
## are ("res": how many pixels the 320 x 180 map becomes), how it is drawn
## ("family": pixel, painted, ink or flat), how big one building block is
## ("block", in map units) and its colours ("pal").
##
## The first four are taken from castle-valley-loop-1080p60.mp4: bright
## cream stone, blue cone roofs, dithered sky, half-timbered houses.


static func all() -> Array:
	var day := _valley_day()
	return [
		{
			"id": "valley", "name": "Valley pixel",
			"desc": "Like the video: big pixels (320 x 180, each 4 x 4 on screen), dithered sky and grass, cream stone, blue roofs.",
			"family": "pixel", "res": Vector2i(320, 180), "block": Vector2(6, 3), "pal": day,
		},
		{
			"id": "valley_fine", "name": "Valley pixel, fine",
			"desc": "The same look at the game's own size today (640 x 360): pixels half as big, smaller blocks, more detail.",
			"family": "pixel", "res": Vector2i(640, 360), "block": Vector2(4, 2), "pal": day,
		},
		{
			"id": "valley_dusk", "name": "Valley pixel, dusk",
			"desc": "The video's style in evening light: warm sky, the sun behind the mountains, lit windows and a torch.",
			"family": "pixel", "res": Vector2i(320, 180), "block": Vector2(6, 3), "pal": _valley_dusk(), "lit": true,
		},
		{
			"id": "painted", "name": "Storybook painted",
			"desc": "The video's colours without pixels: smooth, soft clouds, hand-cut stones of uneven width.",
			"family": "painted", "res": Vector2i(2560, 1440), "block": Vector2(8, 4), "irregular": true, "pal": _painted(day),
		},
		{
			"id": "ink", "name": "Ink and parchment",
			"desc": "Like a drawing in an old chronicle: ink lines, light watercolour, hatched shadows.",
			"family": "ink", "res": Vector2i(2560, 1440), "block": Vector2(8, 5), "irregular": true, "pal": _ink(),
		},
		{
			"id": "flat", "name": "Flat modern",
			"desc": "Clean shapes, no outlines or texture, bright colours. Easy to read, quick to make art for.",
			"family": "flat", "res": Vector2i(2560, 1440), "block": Vector2(8, 4), "pal": _flat(),
		},
		{
			"id": "pixellab", "name": "PixelLab",
			"desc": "Pictures made by PixelLab (pixellab.ai) at the game's size, 640 x 360. The keep is laid out of its own picture, 14 x 8 pixels a piece.",
			"family": "sprites", "res": Vector2i(640, 360), "block": Vector2(14, 8), "pal": {},
		},
	]


static func _c(hex: String) -> Color:
	return Color(hex)


static func _valley_day() -> Dictionary:
	return {
		"bg": _c("#f3e3bc"),
		"sky": [_c("#3567d4"), _c("#4f8ae2"), _c("#86b8ee"), _c("#c3dcf2"), _c("#f3e3bc")],
		"sun": _c("#fffbe0"), "sun_halo": _c("#ffeaa0"), "sun_pos": Vector2(40, 30),
		"cloud": _c("#f7f5fb"), "cloud_shade": _c("#c6c3e4"), "cloud_warm": _c("#f6dc9c"),
		"mtn_far": _c("#b3bce0"), "mtn_far_shade": _c("#9aa3cf"),
		"mtn": _c("#9aa4d4"), "mtn_shade": _c("#7480b8"),
		"snow": _c("#f6f6fc"), "snow_shade": _c("#cdd2ea"),
		"hill": _c("#86c06a"), "hill_tree": _c("#4d9a4e"), "hill_tree_light": _c("#6fb85a"),
		"lake": _c("#8fc8f0"), "lake_light": _c("#e2f2fc"),
		"grass_dark": _c("#4a9834"), "grass": _c("#5fae3e"), "grass_light": _c("#7cc44e"),
		"flowers": [_c("#e85a6a"), _c("#b090f0"), _c("#f4e070"), _c("#ffffff")],
		"path": _c("#d2b483"), "path_dark": _c("#b08f62"), "path_light": _c("#e6cfa0"),
		"stone": _c("#ece1bf"), "stone_light": _c("#faf3dc"), "stone_dark": _c("#d3c399"),
		"mortar": _c("#bba987"), "shadow": _c("#6a5a7a"),
		"roof": _c("#3b5ec4"), "roof_light": _c("#5f86e0"), "roof_dark": _c("#2a438f"),
		"window": _c("#2c2c5e"), "window_lit": _c("#ffd860"),
		"door": _c("#7a4426"), "door_dark": _c("#4f2a16"),
		"wood": _c("#9a6a3a"), "wood_dark": _c("#63401f"),
		"plaster": _c("#f4ead2"), "timber": _c("#6e4426"),
		"house_roof": _c("#d4643c"), "house_roof_light": _c("#ec8a5c"), "house_roof_dark": _c("#a9462a"),
		"leaf": _c("#3e9a4a"), "leaf_dark": _c("#2b7840"), "leaf_light": _c("#66bf5c"), "trunk": _c("#6c4a2a"),
		"flag": _c("#e8462c"), "flag2": _c("#f4c440"),
		"skin": _c("#f2c9a0"), "hair": _c("#6b4222"), "legs": _c("#4e3e30"),
		"tunics": [_c("#3c6cc4"), _c("#c44c3c"), _c("#4c8c3e"), _c("#b48c4c"), _c("#7c5ca4"), _c("#d8d0c0")],
		"bird": _c("#3a3a5a"),
	}


static func _valley_dusk() -> Dictionary:
	var p := _valley_day()
	p.merge({
		"bg": _c("#f8c070"),
		"sky": [_c("#25205a"), _c("#4b3a86"), _c("#9a4f86"), _c("#e07a62"), _c("#f8c070")],
		"sun": _c("#ffd27a"), "sun_halo": _c("#ff9a50"), "sun_pos": Vector2(205, 112),
		"cloud": _c("#f4a888"), "cloud_shade": _c("#7a5a90"), "cloud_warm": _c("#ffd090"),
		"mtn_far": _c("#7a5f96"), "mtn_far_shade": _c("#634e86"),
		"mtn": _c("#54477e"), "mtn_shade": _c("#3e3466"),
		"snow": _c("#f6c4b8"), "snow_shade": _c("#a88ab0"),
		"hill": _c("#3f6e4a"), "hill_tree": _c("#2a5040"), "hill_tree_light": _c("#3c6a48"),
		"lake": _c("#c88a8a"), "lake_light": _c("#ffd0a0"),
		"grass_dark": _c("#2c5232"), "grass": _c("#386a3a"), "grass_light": _c("#4a7c42"),
		"flowers": [_c("#c04a5a"), _c("#8a6ac0"), _c("#d0b050"), _c("#d0c8d0")],
		"path": _c("#9a7a62"), "path_dark": _c("#7a5e4c"), "path_light": _c("#b8947a"),
		"stone": _c("#d9b49c"), "stone_light": _c("#f0ccaa"), "stone_dark": _c("#b08e86"),
		"mortar": _c("#8e7076"), "shadow": _c("#2a2050"),
		"roof": _c("#34428e"), "roof_light": _c("#5c5ab0"), "roof_dark": _c("#222c66"),
		"window": _c("#2a2040"),
		"door": _c("#5a3226"), "door_dark": _c("#3a1e18"),
		"wood": _c("#7a5238"), "wood_dark": _c("#4e3224"),
		"plaster": _c("#e6c4a8"), "timber": _c("#4e3022"),
		"house_roof": _c("#b04a3a"), "house_roof_light": _c("#d8704e"), "house_roof_dark": _c("#82342c"),
		"leaf": _c("#2e6a44"), "leaf_dark": _c("#1f4c36"), "leaf_light": _c("#4a8a50"), "trunk": _c("#4a3424"),
		"skin": _c("#e8a888"), "hair": _c("#4a2c1c"), "legs": _c("#3a2c2c"),
		"tunics": [_c("#34548e"), _c("#9a3c3a"), _c("#3c6a3a"), _c("#8a6a44"), _c("#5c4880"), _c("#b8a0a0")],
		"bird": _c("#2a1e3a"),
	}, true)
	return p


static func _painted(day: Dictionary) -> Dictionary:
	var p := day.duplicate(true)
	p.merge({
		"stone": _c("#eadbb4"), "stone_light": _c("#fbf2d8"), "stone_dark": _c("#cdb88a"),
		"mortar": _c("#a8946e"), "shadow": _c("#4a4a7a"),
	}, true)
	return p


static func _ink() -> Dictionary:
	return {
		"bg": _c("#efe3c4"), "paper": _c("#efe3c4"), "paper_dark": _c("#d6c18f"),
		"ink": _c("#3b2a1c"), "ink_light": _c("#806648"),
		"sun_pos": Vector2(40, 30),
		"mtn": _c("#e2d6b6"), "mtn_shade": _c("#d2c29c"), "mtn_far": _c("#e8dcbe"), "mtn_far_shade": _c("#dccdaa"),
		"hill": _c("#d4d0a0"), "lake": _c("#d2d8c8"),
		"grass": _c("#dcd6a4"),
		"path": _c("#e6d4a8"),
		"stone": _c("#e9dab4"), "stone_light": _c("#f4e9cc"), "stone_dark": _c("#d4c094"),
		"mortar": _c("#c8b48a"), "shadow": _c("#5a4630"),
		"roof": _c("#8e9cc2"), "roof_light": _c("#aab6d6"), "roof_dark": _c("#6e7ca4"),
		"window": _c("#4a3a2a"), "window_lit": _c("#e8c060"),
		"door": _c("#a07452"), "door_dark": _c("#6a4a30"),
		"wood": _c("#a8805a"), "wood_dark": _c("#6a5038"),
		"plaster": _c("#f2e8cc"), "timber": _c("#5a4430"),
		"house_roof": _c("#c88e6a"), "house_roof_light": _c("#dcaa88"), "house_roof_dark": _c("#a86e50"),
		"leaf": _c("#aab67c"), "leaf_dark": _c("#8c9a64"), "leaf_light": _c("#c4cc96"), "trunk": _c("#7a6044"),
		"flag": _c("#c0503a"), "flag2": _c("#d8b050"),
		"skin": _c("#eed4b4"), "hair": _c("#6a5038"), "legs": _c("#6a5848"),
		"tunics": [_c("#8a9ac4"), _c("#c48a70"), _c("#9aac7c"), _c("#cca872"), _c("#a48cb4"), _c("#e0d6c0")],
		"bird": _c("#3b2a1c"),
	}


static func _flat() -> Dictionary:
	return {
		"bg": _c("#d8f0f8"),
		"sky": [_c("#7cc4f0"), _c("#d6f0fa")],
		"sun": _c("#fff2b0"), "sun_halo": _c("#fff8d8"), "sun_pos": Vector2(40, 30),
		"cloud": _c("#ffffff"), "cloud_shade": _c("#e6f2fa"),
		"mtn_far": _c("#b4c0e6"), "mtn_far_shade": _c("#a2b0de"),
		"mtn": _c("#97a6da"), "mtn_shade": _c("#8291cc"),
		"snow": _c("#ffffff"), "snow_shade": _c("#e8ecf8"),
		"hill": _c("#94d47e"), "hill_tree": _c("#6cbc68"), "hill_tree_light": _c("#80c870"),
		"lake": _c("#7cc6ea"), "lake_light": _c("#bfe6f8"),
		"grass_dark": _c("#6cbc5a"), "grass": _c("#7fca6a"), "grass_light": _c("#92d67a"),
		"flowers": [_c("#ff7a8a"), _c("#ffffff")],
		"path": _c("#ecd49e"), "path_dark": _c("#dcc088"), "path_light": _c("#f6e2b6"),
		"stone": _c("#f4ead6"), "stone_light": _c("#fff8ea"), "stone_dark": _c("#e2d4b4"),
		"mortar": _c("#d8c8a6"), "shadow": _c("#5a5a8a"),
		"roof": _c("#5a78e0"), "roof_light": _c("#7896f0"), "roof_dark": _c("#4560c8"),
		"window": _c("#3a4070"), "window_lit": _c("#ffd860"),
		"door": _c("#b0704a"), "door_dark": _c("#8a5434"),
		"wood": _c("#b8885a"), "wood_dark": _c("#8a6038"),
		"plaster": _c("#fff4e0"), "timber": _c("#8a5a3a"),
		"house_roof": _c("#f07a50"), "house_roof_light": _c("#f8966a"), "house_roof_dark": _c("#d8603c"),
		"leaf": _c("#4fb060"), "leaf_dark": _c("#3e9a50"), "leaf_light": _c("#6cc878"), "trunk": _c("#8a6040"),
		"flag": _c("#f05a40"), "flag2": _c("#ffc840"),
		"skin": _c("#f6d0aa"), "hair": _c("#5a3a2a"), "legs": _c("#4a4060"),
		"tunics": [_c("#4a7ae0"), _c("#e85a4a"), _c("#4ab05a"), _c("#f0b040"), _c("#9a6ae0"), _c("#f0e8e0")],
		"bird": _c("#4a5070"),
	}
