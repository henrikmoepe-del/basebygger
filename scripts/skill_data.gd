extends RefCounted
## The skill tree, as plain data. Skills are bought once with renown.
##
## "branch" is the tab the skill is shown on (see BRANCHES).
## "requires" is the skill that must be owned first ("" = none).
## "effects" are added up across all owned skills; GameState turns the totals
## into the actual numbers (see "What skills do" there).
## "cell" is the skill's column and row on its tab.
## "big" marks the few expensive skills that change more than a number.

const BRANCHES := {"peasant": "Peasants", "builder": "Builders", "village": "Village", "defence": "Defence"}

const SKILLS := {
	# --- Peasants: walking, carrying, gathering, trees ---
	"p_speed1": {
		"branch": "peasant", "name": "Sturdy Boots", "text": "All peasants walk 15% faster.",
		"cost": 1, "requires": "", "effects": {"peasant_speed": 0.15}, "cell": Vector2i(2, 0),
	},
	"p_click": {
		"branch": "peasant", "name": "Strong Backs", "text": "Gatherers carry 1 more per trip.",
		"cost": 2, "requires": "p_speed1", "effects": {"carry": 1}, "cell": Vector2i(0, 1),
	},
	"p_speed2": {
		"branch": "peasant", "name": "Worn Paths", "text": "All peasants walk another 15% faster.",
		"cost": 2, "requires": "p_speed1", "effects": {"peasant_speed": 0.15}, "cell": Vector2i(2, 1),
	},
	"p_carry1": {
		"branch": "peasant", "name": "Bigger Baskets", "text": "Gatherers carry 1 more per trip.",
		"cost": 2, "requires": "p_speed1", "effects": {"carry": 1}, "cell": Vector2i(4, 1),
	},
	"p_hire": {
		"branch": "peasant", "name": "Apprentices", "text": "Word spreads: peasants cost 25% less to hire.",
		"cost": 6, "requires": "p_click", "effects": {"peasant_discount": 0.25}, "cell": Vector2i(0, 2),
		"big": true,
	},
	"p_trees1": {
		"branch": "peasant", "name": "Forestry", "text": "Trees regrow 30% faster.",
		"cost": 3, "requires": "p_speed2", "effects": {"tree_growth": 0.3}, "cell": Vector2i(1, 2),
	},
	"p_speed3": {
		"branch": "peasant", "name": "Paved Paths", "text": "All peasants walk another 20% faster.",
		"cost": 4, "requires": "p_speed2", "effects": {"peasant_speed": 0.2}, "cell": Vector2i(2, 2),
	},
	"p_work1": {
		"branch": "peasant", "name": "Sharper Tools", "text": "Gatherers chop and mine 30% quicker.",
		"cost": 2, "requires": "p_carry1", "effects": {"gather_speed": 0.3}, "cell": Vector2i(4, 2),
	},
	"p_hire2": {
		"branch": "peasant", "name": "Town Crier", "text": "Peasants cost another 15% less to hire.",
		"cost": 5, "requires": "p_hire", "effects": {"peasant_discount": 0.15}, "cell": Vector2i(0, 3),
	},
	"p_trees2": {
		"branch": "peasant", "name": "Deep Roots", "text": "Each tree holds 4 more wood.",
		"cost": 3, "requires": "p_trees1", "effects": {"tree_wood": 4}, "cell": Vector2i(1, 3),
	},
	"p_speed4": {
		"branch": "peasant", "name": "Second Wind", "text": "All peasants walk another 20% faster.",
		"cost": 6, "requires": "p_speed3", "effects": {"peasant_speed": 0.2}, "cell": Vector2i(2, 3),
	},
	"p_work2": {
		"branch": "peasant", "name": "Steel Tools", "text": "Gatherers chop and mine another 40% quicker.",
		"cost": 4, "requires": "p_work1", "effects": {"gather_speed": 0.4}, "cell": Vector2i(3, 3),
	},
	"p_carry2": {
		"branch": "peasant", "name": "Handcarts", "text": "Gatherers carry 2 more per trip.",
		"cost": 4, "requires": "p_work1", "effects": {"carry": 2}, "cell": Vector2i(4, 3),
	},
	"p_trees3": {
		"branch": "peasant", "name": "Old Growth", "text": "Each tree holds another 6 wood.",
		"cost": 5, "requires": "p_trees2", "effects": {"tree_wood": 6}, "cell": Vector2i(1, 4),
	},
	"p_carry3": {
		"branch": "peasant", "name": "Ox Carts", "text": "Gatherers carry 3 more per trip.",
		"cost": 7, "requires": "p_carry2", "effects": {"carry": 3}, "cell": Vector2i(4, 4),
		"big": true,
	},

	# --- Builders: hammering, hauling, cheaper castle ---
	"b_hammer1": {
		"branch": "builder", "name": "Better Hammers", "text": "Builders hammer 25% faster.",
		"cost": 1, "requires": "", "effects": {"hammer": 0.25}, "cell": Vector2i(2, 0),
	},
	"b_load1": {
		"branch": "builder", "name": "Hods", "text": "Builders carry 2 more per trip.",
		"cost": 2, "requires": "b_hammer1", "effects": {"builder_load": 2}, "cell": Vector2i(0, 1),
	},
	"b_hammer2": {
		"branch": "builder", "name": "Masonry", "text": "Builders hammer another 25% faster.",
		"cost": 3, "requires": "b_hammer1", "effects": {"hammer": 0.25}, "cell": Vector2i(2, 1),
	},
	"b_speed1": {
		"branch": "builder", "name": "Sure Footing", "text": "Builders walk a further 20% faster.",
		"cost": 2, "requires": "b_hammer1", "effects": {"builder_speed": 0.2}, "cell": Vector2i(4, 1),
	},
	"b_load2": {
		"branch": "builder", "name": "Wheelbarrows", "text": "Builders carry 4 more per trip.",
		"cost": 4, "requires": "b_load1", "effects": {"builder_load": 4}, "cell": Vector2i(0, 2),
	},
	"b_crane": {
		"branch": "builder", "name": "Treadwheel Crane", "text": "A crane on site: hammering 50% faster and 4 more per trip.",
		"cost": 7, "requires": "b_hammer2", "effects": {"hammer": 0.5, "builder_load": 4}, "cell": Vector2i(2, 2),
		"big": true,
	},
	"b_cost": {
		"branch": "builder", "name": "Foremen", "text": "Builders hammer another 25% faster.",
		"cost": 3, "requires": "b_speed1", "effects": {"hammer": 0.25}, "cell": Vector2i(4, 2),
	},
	"b_load3": {
		"branch": "builder", "name": "Ox Wagons", "text": "Builders carry 6 more per trip.",
		"cost": 6, "requires": "b_load2", "effects": {"builder_load": 6}, "cell": Vector2i(0, 3),
	},
	"b_hammer3": {
		"branch": "builder", "name": "Master Masons", "text": "Builders hammer another 50% faster.",
		"cost": 6, "requires": "b_crane", "effects": {"hammer": 0.5}, "cell": Vector2i(2, 3),
	},
	"b_speed2": {
		"branch": "builder", "name": "Ramps", "text": "Builders walk a further 30% faster.",
		"cost": 4, "requires": "b_cost", "effects": {"builder_speed": 0.3}, "cell": Vector2i(4, 3),
	},
	"b_guild": {
		"branch": "builder", "name": "Stonecutters' Guild", "text": "Castle parts cost 15% less material.",
		"cost": 8, "requires": "b_hammer3", "effects": {"part_discount": 0.15}, "cell": Vector2i(2, 4),
		"big": true,
	},
	"b_plans": {
		"branch": "builder", "name": "Master Plans", "text": "Castle parts take 15% less hammering.",
		"cost": 5, "requires": "b_speed2", "effects": {"work_discount": 0.15}, "cell": Vector2i(4, 4),
	},

	# --- Village: new trades and the land around the castle ---
	"v_forester": {
		"branch": "village", "name": "Foresters", "text": "Unlocks the Forester job. Foresters plant new trees and tend the grove so it regrows faster.",
		"cost": 3, "requires": "", "effects": {}, "cell": Vector2i(1, 0),
		"big": true,
	},
	"v_plots1": {
		"branch": "village", "name": "Cleared Land", "text": "Room for 2 more trees.",
		"cost": 2, "requires": "v_forester", "effects": {"tree_plots": 2}, "cell": Vector2i(0, 1),
	},
	"v_tend": {
		"branch": "village", "name": "Green Thumbs", "text": "Each forester speeds up regrowth twice as much.",
		"cost": 3, "requires": "v_forester", "effects": {"tend": 0.15}, "cell": Vector2i(1, 1),
	},
	"v_plant": {
		"branch": "village", "name": "Seedlings", "text": "Foresters plant 50% faster.",
		"cost": 2, "requires": "v_forester", "effects": {"plant_speed": 0.5}, "cell": Vector2i(2, 1),
	},
	"v_plots2": {
		"branch": "village", "name": "Wide Grove", "text": "Room for 2 more trees.",
		"cost": 4, "requires": "v_plots1", "effects": {"tree_plots": 2}, "cell": Vector2i(0, 2),
	},
	"v_cook": {
		"branch": "village", "name": "Cooks", "text": "Unlocks the Cook job. Each cook makes the food go 8% further (up to 6 cooks).",
		"cost": 4, "requires": "", "effects": {}, "cell": Vector2i(3, 0),
		"big": true,
	},
	"v_feast": {
		"branch": "village", "name": "Hearty Meals", "text": "Peasants who have eaten work 10% faster.",
		"cost": 3, "requires": "v_cook", "effects": {"fed_bonus": 0.1}, "cell": Vector2i(3, 1),
	},
	"v_ration": {
		"branch": "village", "name": "Rationing", "text": "Peasants eat 20% less.",
		"cost": 4, "requires": "v_feast", "effects": {"food_saving": 0.2}, "cell": Vector2i(3, 2),
	},
	"v_hunt1": {
		"branch": "village", "name": "Game Bags", "text": "Hunters carry 2 more per trip.",
		"cost": 2, "requires": "", "effects": {"hunter_carry": 2}, "cell": Vector2i(4, 0),
	},
	"v_hunt2": {
		"branch": "village", "name": "Trained Hounds", "text": "Hunters carry another 3 per trip.",
		"cost": 4, "requires": "v_hunt1", "effects": {"hunter_carry": 3}, "cell": Vector2i(4, 1),
	},
	"v_lantern": {
		"branch": "village", "name": "Lanterns", "text": "Peasants work later into the evening: nights are a quarter shorter.",
		"cost": 5, "requires": "v_herald", "effects": {"night_shorter": 0.07}, "cell": Vector2i(5, 1),
		"big": true,
	},
	"v_herald": {
		"branch": "village", "name": "Heralds", "text": "Each new castle rank gives 3 more renown.",
		"cost": 4, "requires": "", "effects": {"rank_renown": 3}, "cell": Vector2i(5, 0),
	},

	"v_bunks": {
		"branch": "village", "name": "Bunk Beds", "text": "Each house holds 1 more peasant.",
		"cost": 3, "requires": "", "effects": {"house_room": 1}, "cell": Vector2i(0, 4),
	},
	"v_lofts": {
		"branch": "village", "name": "Lofts", "text": "Each house holds another 2 peasants.",
		"cost": 6, "requires": "v_bunks", "effects": {"house_room": 2}, "cell": Vector2i(1, 4),
		"big": true,
	},
	"v_brew": {
		"branch": "village", "name": "Good Ale", "text": "A full tavern makes everyone work another 10% faster.",
		"cost": 4, "requires": "", "effects": {"tavern_bonus": 0.1}, "cell": Vector2i(3, 4),
	},
	"v_deepwell": {
		"branch": "village", "name": "Deep Well", "text": "Each well level serves 4 more peasants.",
		"cost": 3, "requires": "", "effects": {"well_serves": 4}, "cell": Vector2i(4, 4),
	},

	# --- Defence: soldiers and raids ---
	"d_drill": {
		"branch": "defence", "name": "Drills", "text": "Each soldier gives 2 more defence.",
		"cost": 3, "requires": "", "effects": {"soldier_defence": 2}, "cell": Vector2i(1, 0),
	},
	"d_bunks": {
		"branch": "defence", "name": "Bunks", "text": "Room for 1 more soldier per garrison level.",
		"cost": 4, "requires": "d_drill", "effects": {"soldier_room": 1}, "cell": Vector2i(0, 1),
	},
	"d_arms": {
		"branch": "defence", "name": "Better Arms", "text": "Each soldier gives another 3 defence.",
		"cost": 5, "requires": "d_drill", "effects": {"soldier_defence": 3}, "cell": Vector2i(1, 1),
	},
	"d_veterans": {
		"branch": "defence", "name": "Veterans", "text": "Each soldier gives another 5 defence.",
		"cost": 8, "requires": "d_arms", "effects": {"soldier_defence": 5}, "cell": Vector2i(1, 2),
		"big": true,
	},
	"d_walls": {
		"branch": "defence", "name": "Thick Walls", "text": "Castle parts give 15% more defence.",
		"cost": 4, "requires": "", "effects": {"part_defence": 0.15}, "cell": Vector2i(3, 0),
	},
	"d_walls2": {
		"branch": "defence", "name": "Murder Holes", "text": "Castle parts give another 20% defence.",
		"cost": 7, "requires": "d_walls", "effects": {"part_defence": 0.2}, "cell": Vector2i(3, 1),
	},
	"d_cellars": {
		"branch": "defence", "name": "Hidden Cellars", "text": "A lost raid takes half as much from your stores.",
		"cost": 3, "requires": "", "effects": {"raid_loss_cut": 0.5}, "cell": Vector2i(5, 0),
	},
	"d_spoils": {
		"branch": "defence", "name": "Spoils of War", "text": "Each raid you beat gives 2 more renown.",
		"cost": 4, "requires": "d_cellars", "effects": {"raid_renown": 2}, "cell": Vector2i(5, 1),
	},
}
