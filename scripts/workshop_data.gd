extends RefCounted
## Workshops: buildings where peasants turn goods from the stockyard into
## other goods. Each entry is the job that works there (see job_data.gd),
## run by crafter.gd: the crafter fetches the inputs from their stores,
## carries them to the workshop, works them, and carries what they made back
## to its store in the stockyard.
##
##   part       the building it happens in; each level has room for per_level
##   inputs     what one batch takes: resource -> amount
##   output     the resource it makes, and "makes" how much per batch
##   batches    how many batches a crafter carries in one trip
##   time       seconds of work per batch
##   sound      what the work sounds like (see sfx.gd)
##   carry_in   the colour of the load carried to the workshop
##   carry_out  the colour of the load carried back (also the chips that fly)
##
## A new workshop needs an entry here, a job in job_data.gd, and its building
## in castle_data.gd.

const WORKSHOPS := {
	"sawyer": {
		"part": "sawmill", "per_level": 2,
		"inputs": {"wood": 1}, "output": "planks", "makes": 1, "batches": 2, "time": 3.0,
		"sound": "chop", "carry_in": Color(0.52, 0.36, 0.22), "carry_out": Color(0.78, 0.60, 0.36),
	},
	# Grain from the food store and wood for the oven make more, and better, food.
	"baker": {
		"part": "bakery", "per_level": 2,
		"inputs": {"food": 2, "wood": 1}, "output": "food", "makes": 4, "batches": 2, "time": 4.0,
		"sound": "hammer", "carry_in": Color(0.85, 0.75, 0.45), "carry_out": Color(0.80, 0.55, 0.28),
	},
}
