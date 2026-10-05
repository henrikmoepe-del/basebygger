extends RefCounted
## The seasons, in order through the year. Each lasts DAYS_PER_SEASON days.
## A season has "effects" while it lasts, read with GameState.effect_total
## like those of events and policies ("happiness" is points of happiness).
## Events can be kept to a season with "needs": {"season": "winter"}.
## The colours are for the scenery (backdrop.gd): the near and far hills,
## the ground, the grass tufts; "flowers" says if flowers grow, "snow" if
## snow lies on the hills.

const DAYS_PER_SEASON := 3

const SEASONS := [
	{
		"id": "spring", "name": "Spring",
		"text": "Everyone is a little happier",
		"effects": {"happiness": 5.0},
		"near": Color(0.58, 0.76, 0.52), "far": Color(0.70, 0.82, 0.72),
		"ground": Color(0.47, 0.70, 0.38), "tuft": Color(0.36, 0.60, 0.30), "flowers": true,
	},
	{
		"id": "summer", "name": "Summer",
		"text": "Food grows 30% faster at the wilds and farm",
		"effects": {"food_site_rate": 0.3},
		"near": Color(0.58, 0.74, 0.54), "far": Color(0.70, 0.80, 0.72),
		"ground": Color(0.45, 0.68, 0.38), "tuft": Color(0.36, 0.58, 0.30), "flowers": true,
	},
	{
		"id": "autumn", "name": "Autumn",
		"text": "Harvest time: food grows 60% faster",
		"effects": {"food_site_rate": 0.6},
		"near": Color(0.72, 0.66, 0.42), "far": Color(0.78, 0.76, 0.62),
		"ground": Color(0.56, 0.62, 0.34), "tuft": Color(0.62, 0.48, 0.24),
	},
	{
		"id": "winter", "name": "Winter",
		"text": "Little food grows, the cold slows work by 10%, and spirits are low",
		"effects": {"food_site_rate": -0.6, "work_speed": -0.1, "happiness": -5.0},
		"near": Color(0.80, 0.84, 0.86), "far": Color(0.86, 0.88, 0.92),
		"ground": Color(0.70, 0.74, 0.70), "tuft": Color(0.52, 0.56, 0.48), "snow": true,
	},
]
