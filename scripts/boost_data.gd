extends RefCounted
## Boosts: short-lived help bought at a building (the Boosts button). Each
## belongs to a castle part or village building ("building") and can only be
## bought once that stands. It costs resources and lasts "lasts" seconds,
## with "effects" read by GameState.effect_total, the same effects events,
## policies and seasons use:
##   happiness       points of happiness
##   work_speed      a share faster everyone walks and works
##   food_site_rate  a share faster food grows at the wilds and the farm
##   gather_speed    a share faster gathering (wood, stone, food, iron)
##   builder_speed   a share faster builders walk and climb
##   hammer          a share faster builders shape and set pieces
##   soldier_might   a share harder soldiers hit
## A boost can't be bought again while it is going on.

const BOOSTS := {
	"feast": {
		"name": "Feast", "building": "tavern",
		"text": "Happier (+15) and 10% faster work",
		"cost": {"food": 40}, "lasts": 180.0,
		"effects": {"happiness": 15.0, "work_speed": 0.1},
	},
	"clean_water": {
		"name": "Clean water", "building": "well",
		"text": "Happier (+8)",
		"cost": {"stone": 15}, "lasts": 240.0,
		"effects": {"happiness": 8.0},
	},
	"manure": {
		"name": "Manure the fields", "building": "farm",
		"text": "Food grows twice as fast",
		"cost": {"wood": 20}, "lasts": 180.0,
		"effects": {"food_site_rate": 1.0},
	},
	"new_picks": {
		"name": "New picks", "building": "quarry",
		"text": "Everyone gathers 30% faster",
		"cost": {"wood": 15, "stone": 15}, "lasts": 180.0,
		"effects": {"gather_speed": 0.3},
	},
	"drill": {
		"name": "Drill", "building": "garrison",
		"text": "Soldiers hit 25% harder",
		"cost": {"food": 30}, "lasts": 240.0,
		"effects": {"soldier_might": 0.25},
	},
	"masons": {
		"name": "Hire masons", "building": "keep",
		"text": "Builders shape and set pieces 50% faster",
		"cost": {"wood": 40, "stone": 40}, "lasts": 180.0,
		"effects": {"hammer": 0.5},
	},
}
