extends RefCounted
## The kinds of work a peasant can be given, as plain data.
##
## Any peasant can do a job, slowly. Each job also has a trade: once its
## skill is bought, peasants doing the job can be trained, and a trained
## peasant does the same work twice as well (see GameState.train).
##
## "name" is the work; "trade" is what a trained peasant is called.
## "trade_skill" is the skill that allows training for the job.
## "color" is the tunic colour of a peasant doing the job (placeholder art).
## "gathers" is the resource a gathering job brings in, when it isn't the job id.
## "requires_skill" means the job doesn't exist at all until that skill is bought.
## "requires_part" is a castle part that must be built before the job exists.

const JOBS := {
	"wood": {
		"name": "Chop wood", "trade": "Woodcutter", "trade_skill": "t_wood",
		"color": Color(0.25, 0.50, 0.30),
	},
	"stone": {
		"name": "Mine stone", "trade": "Quarryman", "trade_skill": "t_stone",
		"color": Color(0.38, 0.42, 0.60),
	},
	"hunter": {
		"name": "Find food", "trade": "Hunter", "trade_skill": "t_hunt",
		"color": Color(0.62, 0.30, 0.26), "gathers": "food",
	},
	"build": {
		"name": "Build", "trade": "Master builder", "trade_skill": "t_build",
		"color": Color(0.80, 0.52, 0.20),
	},
	"cook": {
		"name": "Cook", "trade": "Cook", "trade_skill": "cook",
		"color": Color(0.92, 0.90, 0.84),
	},
	"soldier": {
		"name": "Stand guard", "trade": "Man-at-arms", "trade_skill": "t_guard",
		"color": Color(0.55, 0.14, 0.16), "requires_part": "garrison",
	},
	# Tending the grove takes know-how: only trained foresters can do it.
	"forester": {
		"name": "Tend the grove", "trade": "Forester", "trade_skill": "forester",
		"color": Color(0.55, 0.72, 0.30), "requires_skill": "forester",
	},
}
const IDLE_COLOR := Color(0.78, 0.74, 0.62)
## The hat that marks a trained peasant.
const TRAINED_HAT := Color(0.95, 0.80, 0.30)
