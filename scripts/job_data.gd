extends RefCounted
## The jobs a peasant can be assigned to, as plain data.
## "color" is the tunic colour of a peasant doing the job (placeholder art).
## "requires_skill" is the skill that unlocks the job (left out = always there).
## "gathers" is the resource a gathering job brings in, when it isn't the job id.

const JOBS := {
	"wood": {"name": "Woodcutters", "color": Color(0.25, 0.50, 0.30)},
	"stone": {"name": "Quarrymen", "color": Color(0.38, 0.42, 0.60)},
	"hunter": {"name": "Hunters", "color": Color(0.62, 0.30, 0.26), "gathers": "food"},
	"build": {"name": "Builders", "color": Color(0.80, 0.52, 0.20)},
	"forester": {"name": "Foresters", "color": Color(0.55, 0.72, 0.30), "requires_skill": "v_forester"},
	"cook": {"name": "Cooks", "color": Color(0.92, 0.90, 0.84), "requires_skill": "v_cook"},
}
const IDLE_COLOR := Color(0.78, 0.74, 0.62)
