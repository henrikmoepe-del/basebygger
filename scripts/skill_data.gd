extends RefCounted
## The skill tree, as plain data. Skills are bought with renown, and most
## can be bought several times (levels).
##
## "cell" is where the node sits on the skill map, in grid steps from the
##     centre (x right, y down). Four arms grow out from the centre:
##     west = gathering, north = building, east = village, south = defence.
## "requires" is the skill that must have at least one level first ("" = none).
##     A skill is hidden as "?" until its required skill is bought.
## "max_level" is how many times it can be bought.
## "cost" is the renown for the first level; each further level costs
##     "cost_step" more.
## "effects" are per level. They are added up across all skills; GameState
##     turns the totals into actual numbers (see "What skills do" there).
## "icon" is a short stand-in for a picture until we have real art.
## "big" marks the unlocks that change more than a number.

const SKILLS := {
	# --- West: gathering ---
	"boots": {
		"name": "Sturdy Boots", "icon": "Bt", "text": "All peasants walk 10% faster per level.",
		"cell": Vector2i(-1, 0), "requires": "", "max_level": 5, "cost": 1, "cost_step": 1,
		"effects": {"peasant_speed": 0.1},
	},
	"t_wood": {
		"name": "Woodcutters", "icon": "WC", "text": "A trade. Peasants chopping wood can be trained as woodcutters, who chop twice as fast and carry twice as much.",
		"cell": Vector2i(-1, -1), "requires": "boots", "max_level": 1, "cost": 3, "cost_step": 0,
		"effects": {}, "big": true,
	},
	"t_stone": {
		"name": "Quarrymen", "icon": "QM", "text": "A trade. Peasants mining stone can be trained as quarrymen, who mine twice as fast and carry twice as much.",
		"cell": Vector2i(-1, 1), "requires": "boots", "max_level": 1, "cost": 3, "cost_step": 0,
		"effects": {}, "big": true,
	},
	"baskets": {
		"name": "Bigger Baskets", "icon": "Bk", "text": "Gatherers carry 1 more per trip per level.",
		"cell": Vector2i(-2, 0), "requires": "boots", "max_level": 5, "cost": 2, "cost_step": 1,
		"effects": {"carry": 1},
	},
	"tools": {
		"name": "Sharper Tools", "icon": "Tl", "text": "Gatherers chop and mine 20% quicker per level.",
		"cell": Vector2i(-2, -1), "requires": "baskets", "max_level": 4, "cost": 2, "cost_step": 1,
		"effects": {"gather_speed": 0.2},
	},
	"apprentices": {
		"name": "Apprentices", "icon": "Ap", "text": "Peasants cost 12% less to hire per level.",
		"cell": Vector2i(-3, 0), "requires": "baskets", "max_level": 3, "cost": 4, "cost_step": 2,
		"effects": {"peasant_discount": 0.12},
	},
	"forestry": {
		"name": "Forestry", "icon": "Fy", "text": "Trees regrow 25% faster per level.",
		"cell": Vector2i(-2, 1), "requires": "baskets", "max_level": 3, "cost": 2, "cost_step": 1,
		"effects": {"tree_growth": 0.25},
	},
	"roots": {
		"name": "Deep Roots", "icon": "Rt", "text": "Each tree holds 3 more wood per level.",
		"cell": Vector2i(-3, 1), "requires": "forestry", "max_level": 3, "cost": 3, "cost_step": 1,
		"effects": {"tree_wood": 3},
	},
	"forester": {
		"name": "Foresters", "icon": "FO", "text": "A trade and a new job. Foresters plant new trees and tend the grove so it regrows faster.",
		"cell": Vector2i(-2, 2), "requires": "forestry", "max_level": 1, "cost": 3, "cost_step": 0,
		"effects": {}, "big": true,
	},
	"plots": {
		"name": "Cleared Land", "icon": "Ld", "text": "Room for 2 more trees per level.",
		"cell": Vector2i(-3, 2), "requires": "forester", "max_level": 2, "cost": 2, "cost_step": 2,
		"effects": {"tree_plots": 2},
	},
	"tend": {
		"name": "Green Thumbs", "icon": "Gt", "text": "Each forester speeds up regrowth by another 10% per level.",
		"cell": Vector2i(-3, 3), "requires": "forester", "max_level": 2, "cost": 3, "cost_step": 1,
		"effects": {"tend": 0.1},
	},
	"seedlings": {
		"name": "Seedlings", "icon": "Sd", "text": "Foresters plant 40% faster per level.",
		"cell": Vector2i(-2, 3), "requires": "forester", "max_level": 2, "cost": 2, "cost_step": 1,
		"effects": {"plant_speed": 0.4},
	},

	# --- North: building ---
	"hammers": {
		"name": "Better Hammers", "icon": "Hm", "text": "Builders hammer 20% faster per level.",
		"cell": Vector2i(0, -1), "requires": "", "max_level": 5, "cost": 1, "cost_step": 1,
		"effects": {"hammer": 0.2},
	},
	"t_build": {
		"name": "Master Builders", "icon": "MB", "text": "A trade. Builders can be trained as master builders, who hammer twice as fast and haul twice as much.",
		"cell": Vector2i(1, -1), "requires": "hammers", "max_level": 1, "cost": 4, "cost_step": 0,
		"effects": {}, "big": true,
	},
	"hods": {
		"name": "Hods", "icon": "Hd", "text": "Builders carry 3 more per trip per level.",
		"cell": Vector2i(0, -2), "requires": "hammers", "max_level": 4, "cost": 2, "cost_step": 1,
		"effects": {"builder_load": 3},
	},
	"footing": {
		"name": "Sure Footing", "icon": "Ft", "text": "Builders walk a further 15% faster per level.",
		"cell": Vector2i(-1, -2), "requires": "hods", "max_level": 3, "cost": 2, "cost_step": 1,
		"effects": {"builder_speed": 0.15},
	},
	"plans": {
		"name": "Master Plans", "icon": "Pl", "text": "Everything takes 8% less hammering per level.",
		"cell": Vector2i(1, -2), "requires": "hods", "max_level": 3, "cost": 3, "cost_step": 1,
		"effects": {"work_discount": 0.08},
	},
	"heralds": {
		"name": "Heralds", "icon": "Hr", "text": "Each new castle rank gives 2 more renown per level.",
		"cell": Vector2i(2, -2), "requires": "plans", "max_level": 2, "cost": 4, "cost_step": 2,
		"effects": {"rank_renown": 2},
	},
	"crane": {
		"name": "Treadwheel Crane", "icon": "CR", "text": "A crane on site: hammering 50% faster and 4 more per trip.",
		"cell": Vector2i(0, -3), "requires": "hods", "max_level": 1, "cost": 7, "cost_step": 0,
		"effects": {"hammer": 0.5, "builder_load": 4}, "big": true,
	},
	"guild": {
		"name": "Stonecutters' Guild", "icon": "Gd", "text": "Everything costs 7% less material per level.",
		"cell": Vector2i(0, -4), "requires": "crane", "max_level": 3, "cost": 5, "cost_step": 2,
		"effects": {"part_discount": 0.07},
	},

	# --- East: village ---
	"gamebags": {
		"name": "Game Bags", "icon": "Gb", "text": "Hunters carry 1 more per trip per level.",
		"cell": Vector2i(1, 0), "requires": "", "max_level": 4, "cost": 2, "cost_step": 1,
		"effects": {"hunter_carry": 1},
	},
	"cook": {
		"name": "Cooks", "icon": "CK", "text": "A trade. Peasants at the pot can be trained as cooks, whose meals stretch the food twice as far.",
		"cell": Vector2i(2, 0), "requires": "gamebags", "max_level": 1, "cost": 4, "cost_step": 0,
		"effects": {}, "big": true,
	},
	"feast": {
		"name": "Hearty Meals", "icon": "Ml", "text": "Peasants who have eaten work 5% faster per level.",
		"cell": Vector2i(2, -1), "requires": "cook", "max_level": 3, "cost": 3, "cost_step": 1,
		"effects": {"fed_bonus": 0.05},
	},
	"ration": {
		"name": "Rationing", "icon": "Rn", "text": "Peasants eat 8% less per level.",
		"cell": Vector2i(3, 0), "requires": "cook", "max_level": 3, "cost": 3, "cost_step": 1,
		"effects": {"food_saving": 0.08},
	},
	"t_hunt": {
		"name": "Hunters", "icon": "HU", "text": "A trade. Peasants finding food can be trained as hunters, who bring back twice as much.",
		"cell": Vector2i(1, 1), "requires": "gamebags", "max_level": 1, "cost": 3, "cost_step": 0,
		"effects": {}, "big": true,
	},
	"bunks": {
		"name": "Bunk Beds", "icon": "Bd", "text": "Each house holds 1 more peasant per level.",
		"cell": Vector2i(2, 1), "requires": "t_hunt", "max_level": 3, "cost": 3, "cost_step": 1,
		"effects": {"house_room": 1},
	},
	"ale": {
		"name": "Good Ale", "icon": "Al", "text": "A full tavern makes everyone work another 4% faster per level.",
		"cell": Vector2i(3, 1), "requires": "bunks", "max_level": 3, "cost": 3, "cost_step": 1,
		"effects": {"tavern_bonus": 0.04},
	},
	"deepwell": {
		"name": "Deep Well", "icon": "Wl", "text": "Each well level serves 2 more peasants per level.",
		"cell": Vector2i(2, 2), "requires": "bunks", "max_level": 3, "cost": 2, "cost_step": 1,
		"effects": {"well_serves": 2},
	},
	"lanterns": {
		"name": "Lanterns", "icon": "LN", "text": "Peasants work later into the evening: nights are a quarter shorter.",
		"cell": Vector2i(3, 2), "requires": "ale", "max_level": 1, "cost": 5, "cost_step": 0,
		"effects": {"night_shorter": 0.07}, "big": true,
	},

	# --- South: defence ---
	"drills": {
		"name": "Drills", "icon": "Dr", "text": "Each soldier gives 1 more defence per level.",
		"cell": Vector2i(0, 1), "requires": "", "max_level": 5, "cost": 2, "cost_step": 1,
		"effects": {"soldier_defence": 1},
	},
	"t_guard": {
		"name": "Men-at-arms", "icon": "MA", "text": "A trade. Peasants standing guard can be trained as men-at-arms, who count double for defence.",
		"cell": Vector2i(1, 2), "requires": "drills", "max_level": 1, "cost": 4, "cost_step": 0,
		"effects": {}, "big": true,
	},
	"thickwalls": {
		"name": "Thick Walls", "icon": "Tw", "text": "Castle parts give 8% more defence per level.",
		"cell": Vector2i(0, 2), "requires": "drills", "max_level": 4, "cost": 3, "cost_step": 1,
		"effects": {"part_defence": 0.08},
	},
	"barracks": {
		"name": "Barracks Bunks", "icon": "Bb", "text": "Room for 1 more soldier per garrison level, per level.",
		"cell": Vector2i(-1, 2), "requires": "drills", "max_level": 2, "cost": 4, "cost_step": 2,
		"effects": {"soldier_room": 1},
	},
	"veterans": {
		"name": "Veterans", "icon": "VT", "text": "Each soldier gives another 5 defence.",
		"cell": Vector2i(-1, 3), "requires": "barracks", "max_level": 1, "cost": 8, "cost_step": 0,
		"effects": {"soldier_defence": 5}, "big": true,
	},
	"cellars": {
		"name": "Hidden Cellars", "icon": "Ce", "text": "A lost raid takes a quarter less from your stores per level.",
		"cell": Vector2i(0, 3), "requires": "thickwalls", "max_level": 2, "cost": 3, "cost_step": 1,
		"effects": {"raid_loss_cut": 0.25},
	},
	"spoils": {
		"name": "Spoils of War", "icon": "Sp", "text": "Each raid you beat gives 1 more renown per level.",
		"cell": Vector2i(1, 3), "requires": "cellars", "max_level": 3, "cost": 3, "cost_step": 1,
		"effects": {"raid_renown": 1},
	},
}
