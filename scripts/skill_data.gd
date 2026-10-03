extends RefCounted
## The skill tree, as plain data. Skills are bought once with renown.
##
## "requires" is the skill that must be owned first ("" = none).
## "effects" are added up across all owned skills; GameState turns the totals
## into the actual numbers (see "What skills do" there).
## "cell" is the skill's column and row on the skill tree screen.
## "big" marks the few expensive skills that change more than a number.

const SKILLS := {
	# --- Peasant branch ---
	"p_speed1": {
		"name": "Sturdy Boots", "text": "Peasants walk 15% faster.",
		"cost": 1, "requires": "", "effects": {"peasant_speed": 0.15}, "cell": Vector2i(1, 0),
	},
	"p_click": {
		"name": "Strong Arms", "text": "Your own clicks gather 1 more.",
		"cost": 2, "requires": "p_speed1", "effects": {"click": 1}, "cell": Vector2i(0, 1),
	},
	"p_speed2": {
		"name": "Worn Paths", "text": "Peasants walk another 15% faster.",
		"cost": 2, "requires": "p_speed1", "effects": {"peasant_speed": 0.15}, "cell": Vector2i(1, 1),
	},
	"p_carry1": {
		"name": "Bigger Baskets", "text": "Peasants carry 1 more per trip.",
		"cost": 2, "requires": "p_speed1", "effects": {"carry": 1}, "cell": Vector2i(2, 1),
	},
	"p_hire": {
		"name": "Apprentices", "text": "Word spreads: peasants cost 25% less to hire.",
		"cost": 6, "requires": "p_click", "effects": {"peasant_discount": 0.25}, "cell": Vector2i(0, 2),
		"big": true,
	},
	"p_trees1": {
		"name": "Forestry", "text": "Trees regrow 30% faster.",
		"cost": 3, "requires": "p_speed2", "effects": {"tree_growth": 0.3}, "cell": Vector2i(1, 2),
	},
	"p_work1": {
		"name": "Sharper Tools", "text": "Peasants chop and mine 30% quicker.",
		"cost": 2, "requires": "p_carry1", "effects": {"gather_speed": 0.3}, "cell": Vector2i(2, 2),
	},
	"p_trees2": {
		"name": "Deep Roots", "text": "Each tree holds 4 more wood.",
		"cost": 3, "requires": "p_trees1", "effects": {"tree_wood": 4}, "cell": Vector2i(1, 3),
	},
	"p_carry2": {
		"name": "Handcarts", "text": "Peasants carry 2 more per trip.",
		"cost": 4, "requires": "p_work1", "effects": {"carry": 2}, "cell": Vector2i(2, 3),
	},

	# --- Builder branch ---
	"b_hammer1": {
		"name": "Better Hammers", "text": "Builders hammer 25% faster.",
		"cost": 1, "requires": "", "effects": {"hammer": 0.25}, "cell": Vector2i(4, 0),
	},
	"b_load1": {
		"name": "Hods", "text": "Builders carry 2 more per trip.",
		"cost": 2, "requires": "b_hammer1", "effects": {"builder_load": 2}, "cell": Vector2i(3, 1),
	},
	"b_hammer2": {
		"name": "Masonry", "text": "Builders hammer another 25% faster.",
		"cost": 3, "requires": "b_hammer1", "effects": {"hammer": 0.25}, "cell": Vector2i(4, 1),
	},
	"b_speed1": {
		"name": "Sure Footing", "text": "Builders walk 20% faster.",
		"cost": 2, "requires": "b_hammer1", "effects": {"builder_speed": 0.2}, "cell": Vector2i(5, 1),
	},
	"b_load2": {
		"name": "Wheelbarrows", "text": "Builders carry 4 more per trip.",
		"cost": 4, "requires": "b_load1", "effects": {"builder_load": 4}, "cell": Vector2i(3, 2),
	},
	"b_crane": {
		"name": "Treadwheel Crane", "text": "A crane on site: hammering 50% faster and 4 more per trip.",
		"cost": 7, "requires": "b_hammer2", "effects": {"hammer": 0.5, "builder_load": 4}, "cell": Vector2i(4, 2),
		"big": true,
	},
	"b_cost": {
		"name": "Foremen", "text": "Builders cost 25% less to hire.",
		"cost": 3, "requires": "b_speed1", "effects": {"builder_discount": 0.25}, "cell": Vector2i(5, 2),
	},
}
