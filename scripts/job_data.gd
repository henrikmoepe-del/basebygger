extends RefCounted
## The jobs a peasant can be assigned to, as plain data.
## "color" is the tunic colour of a peasant doing the job (placeholder art).

const JOBS := {
	"wood": {"name": "Woodcutters", "color": Color(0.25, 0.50, 0.30)},
	"stone": {"name": "Quarrymen", "color": Color(0.38, 0.42, 0.60)},
	"build": {"name": "Builders", "color": Color(0.80, 0.52, 0.20)},
}
const IDLE_COLOR := Color(0.78, 0.74, 0.62)
