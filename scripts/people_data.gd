extends RefCounted
## Peasants as people: each has a name and a trait (GameState.people). For
## now the counts per job in GameState stay in charge, and the people are
## fitted to them (GameState._fit_people); later, parents, children, needs
## and the like will belong to the people themselves.
##
## A trait changes how its peasant works:
##   speed      how fast they walk (1 = as usual)
##   work       how well they work (1 = as usual), on top of being trained
##   happiness  points of everyone's happiness, for each peasant with it

const NAMES := [
	"Ada", "Alric", "Agnes", "Bertram", "Beatrix", "Cedric", "Cecily", "Dunstan", "Edith", "Edmund",
	"Elsbeth", "Fulk", "Gilda", "Godwin", "Hawise", "Hugh", "Ida", "Isolde", "Jocelyn", "Juliana",
	"Lambert", "Mabel", "Matilda", "Milo", "Nesta", "Odo", "Osric", "Petronilla", "Ralf", "Rohese",
	"Sibyl", "Tancred", "Theobald", "Ursula", "Walter", "Wymond", "Yvette", "Aldith", "Baldwin", "Emma",
]

const TRAITS := {
	"quick": {"name": "Quick", "text": "walks 15% faster", "speed": 1.15},
	"slow": {"name": "Slow", "text": "walks 15% slower", "speed": 0.85},
	"diligent": {"name": "Hard-working", "text": "works 15% better", "work": 1.15},
	"lazy": {"name": "Lazy", "text": "works 15% worse", "work": 0.85},
	"cheerful": {"name": "Cheerful", "text": "everyone is a point happier", "happiness": 1.0},
	"gloomy": {"name": "Gloomy", "text": "everyone is a point less happy", "happiness": -1.0},
	"plain": {"name": "Plain", "text": "nothing special"},
}
