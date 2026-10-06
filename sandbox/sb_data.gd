extends RefCounted
## Data for the sandbox (the test map in res://sandbox): work types, jobs, the
## palette from the art direction, and the size of the ground.
##
## The job system here is the new one being tried out. Every peasant has a
## priority for each kind of WORK (1 = first, 2, 3, 0 = never). A JOB is a
## preset of those priorities: giving someone a job sets them, and the player
## can still change single priorities per person. Left alone, a peasant does
## the most important work there is for them, nearest first. An ORDER from
## the player comes before all of it, until it is done or released.

## Kinds of work, in the order they are shown in the priority grid.
const WORK := ["firefight", "fight", "build", "chop", "mine", "haul"]

const WORK_NAMES := {
	"firefight": "Fires", "fight": "Fight", "build": "Build",
	"chop": "Chop", "mine": "Mine", "haul": "Haul",
}

## Each job: its name, tunic colour, and its preset of work priorities.
## Anything missing from "work" is 0 (never).
const JOBS := {
	"builder": {"name": "Builder", "tunic": Color("#8a5a34"),
		"work": {"firefight": 1, "build": 1, "haul": 3}},
	"woodcutter": {"name": "Woodcutter", "tunic": Color("#3f7a78"),
		"work": {"firefight": 1, "chop": 1, "haul": 3}},
	"miner": {"name": "Miner", "tunic": Color("#575160"),
		"work": {"firefight": 1, "mine": 1, "haul": 3}},
	"hauler": {"name": "Hauler", "tunic": Color("#b88a54"),
		"work": {"firefight": 1, "haul": 1, "build": 3}},
	"guard": {"name": "Guard", "tunic": Color("#45558a"),
		"work": {"fight": 1, "firefight": 2}},
}

const JOB_ORDER := ["builder", "woodcutter", "miner", "hauler", "guard"]

const NAMES := ["Alda", "Bram", "Cedric", "Dagny", "Edwin", "Freya", "Gunnar",
		"Hilde", "Ivo", "Jorun", "Kettil", "Liv", "Magnus", "Nora"]

## The ground is a band with depth: y = 0 is the back (the foot of the
## buildings), y = GROUND_DEPTH the front. Nothing is scaled: further forward
## only means lower on the screen and drawn in front.
const GROUND_DEPTH := 80.0
const WALK_TOP := 6.0
const WALK_BOTTOM := 78.0
const WEST_EDGE := -360.0
const EAST_EDGE := 620.0

## How many peasants work one thing at a time when choosing for themselves.
## Orders from the player ignore these.
const CAPACITY := {"tree": 1, "rock": 2, "item": 1, "site": 4, "fire": 3}

## Palette (from the Game_1 Art Direction page).
const INK := Color("#1a1622")
const SKY1 := Color("#3e6aa0")
const SKY2 := Color("#6a98c8")
const SKY3 := Color("#a6c8e0")
const HAZE := Color("#d8e4e0")
const WHITE := Color("#f4f1e6")
const STONE0 := Color("#3a3540")
const STONE1 := Color("#575160")
const STONE2 := Color("#7c7680")
const STONE3 := Color("#a39c98")
const STONE4 := Color("#c9c0b0")
const WOOD0 := Color("#3a2418")
const WOOD1 := Color("#5c3a24")
const WOOD2 := Color("#8a5a34")
const WOOD3 := Color("#b88a54")
const THATCH := Color("#d6b268")
const GRASS0 := Color("#1d3222")
const GRASS1 := Color("#2e5230")
const GRASS2 := Color("#4a7a38")
const GRASS3 := Color("#78a444")
const GRASS4 := Color("#b4c860")
const DIRT := Color("#9c7a52")
const RED0 := Color("#5a1e24")
const RED1 := Color("#9a3028")
const FIRE := Color("#d0582c")
const GOLD := Color("#f2b640")
const LIGHT := Color("#ffe9a0")
const SKIN0 := Color("#a86a4c")
const SKIN1 := Color("#e6b08a")
const TEAL := Color("#3f7a78")
const MTN0 := Color("#6c7aa0")
const MTN1 := Color("#9aa8c8")
const DAUB := Color("#e2d4b0")
const SLATE1 := Color("#45558a")
