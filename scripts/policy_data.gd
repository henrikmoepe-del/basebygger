extends RefCounted
## Policies: rules for the castle the player turns on and off (the Policies
## button). Each has a benefit and a drawback, and "effects" that
## GameState.effect_total adds up, the same effects events use:
##   food_saving  a share less food eaten at dawn (negative: more)
##   work_speed   a share faster everyone walks and works (negative: slower)
##
## Adding an entry here is all a new policy needs, if it only uses effects
## that already exist. Later ones (child labour, bathing, religion, cults)
## will need new effects, and maybe policies that rule each other out.

const POLICIES := {
	"rations": {
		"name": "Smaller rations",
		"benefit": "Peasants eat 25% less",
		"drawback": "Everyone works 10% slower",
		"effects": {"food_saving": 0.25, "work_speed": -0.10},
	},
	"long_days": {
		"name": "Long days",
		"benefit": "Everyone works 15% faster",
		"drawback": "Peasants eat 20% more",
		"effects": {"work_speed": 0.15, "food_saving": -0.20},
	},
}
