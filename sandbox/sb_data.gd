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
const WORK := ["firefight", "fight", "rescue", "build", "chop", "mine", "forage", "hunt", "craft", "haul"]

const WORK_NAMES := {
	"firefight": "Fires", "fight": "Fight", "rescue": "Rescue", "build": "Build",
	"chop": "Chop", "mine": "Mine", "forage": "Food", "hunt": "Hunt", "craft": "Craft", "haul": "Haul",
}

## Each job: its name, tunic colour, and its preset of work priorities.
## Anything missing from "work" is 0 (never).
const JOBS := {
	"builder": {"name": "Builder", "tunic": Color("#8a5a34"),
		"work": {"firefight": 1, "rescue": 1, "build": 1, "haul": 3}},
	"woodcutter": {"name": "Woodcutter", "tunic": Color("#3f7a78"),
		"work": {"firefight": 1, "rescue": 1, "chop": 1, "haul": 3}},
	"miner": {"name": "Miner", "tunic": Color("#575160"),
		"work": {"firefight": 1, "rescue": 1, "mine": 1, "haul": 3}},
	"forager": {"name": "Forager", "tunic": Color("#78a444"),
		"work": {"firefight": 1, "rescue": 1, "forage": 1, "haul": 3}},
	"hunter": {"name": "Hunter", "tunic": Color("#2e5230"),
		"work": {"firefight": 1, "rescue": 1, "hunt": 1, "haul": 3}},
	"crafter": {"name": "Crafter", "tunic": Color("#6a3a6a"),
		"work": {"firefight": 1, "rescue": 1, "craft": 1, "haul": 3}},
	"hauler": {"name": "Hauler", "tunic": Color("#b88a54"),
		"work": {"firefight": 1, "rescue": 1, "haul": 1, "build": 3}},
	"guard": {"name": "Guard", "tunic": Color("#45558a"),
		"work": {"fight": 1, "firefight": 2, "rescue": 1}},
}

## Work that has a skill: it grows by doing it (see sb_peasant.gd `learn`).
const SKILLED := ["build", "chop", "mine", "forage", "hunt", "craft", "fight"]
const SKILL_MAX := 10
## Seconds of practice for the next level: BASE + PER_LEVEL * level.
const SKILL_BASE := 20.0
const SKILL_PER_LEVEL := 12.0

const JOB_ORDER := ["builder", "woodcutter", "miner", "forager", "hunter", "crafter", "hauler", "guard"]

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

## Buildings the player can place: title, look, blocks per course, and the
## material of each course from the bottom.
const BUILDINGS := {
	"hut": {"title": "Hut", "style": "thatch", "cols": 5, "courses": ["stone", "wood", "wood", "wood"]},
	"wall": {"title": "Wall", "style": "battlements", "cols": 7, "courses": ["stone", "stone", "stone", "stone", "stone"]},
	"tower": {"title": "Tower", "style": "spire", "cols": 4, "courses": ["stone", "stone", "stone", "stone", "stone", "planks", "planks"]},
	"shed": {"title": "Shed", "style": "thatch", "cols": 4, "courses": ["wood", "wood"]},
	"sawmill": {"title": "Sawmill", "style": "workshop", "cols": 6, "courses": ["stone", "wood", "wood"], "workshop": "sawmill"},
}

const BUILD_ORDER := ["hut", "wall", "tower", "shed", "sawmill"]

## Workshops: what a crafter takes from the stockyard, makes, and how long
## one takes. A finished workshop has a bill: make until the stockyard holds
## `keep` of the output (the player sets it; 0 stops it).
const WORKSHOPS := {
	"sawmill": {"bill": "Saw planks", "input": "wood", "output": "planks", "time": 4.0, "keep": 10},
}

## Needs: hunger and tiredness grow from 0 to 100 over these many seconds.
## Past the "need" mark a peasant left to themselves stops work to eat or
## sleep; at 100 they work at STARVED_PACE (also when an order keeps them going).
const HUNGER_TIME := 180.0
const TIRED_TIME := 260.0
const HUNGER_NEED := 60.0
const TIRED_NEED := 80.0
const EAT_TIME := 3.0
const SLEEP_TIME := 22.0
const SLEEP_TIME_BED := 12.0
const STARVED_PACE := 0.6

## Day and night: a day lasts DAY_LENGTH seconds and starts at 08:00.
## Night is from NIGHT_FROM to NIGHT_TO (hours). With the Night work policy
## off, peasants left to themselves sleep at night; with it on they work on,
## at NIGHT_PACE and tiring NIGHT_TIRING times as fast.
const DAY_LENGTH := 240.0
const NIGHT_FROM := 21.0
const NIGHT_TO := 6.0
const NIGHT_PACE := 0.85
const NIGHT_TIRING := 1.5
const NIGHT_TINT := Color(0.42, 0.46, 0.72)

## Raids come by themselves: the first on FIRST_RAID_DAY at RAID_HOUR,
## then every RAID_EVERY days, with RAID_BASE raiders plus one more each time.
const FIRST_RAID_DAY := 2
const RAID_HOUR := 17.0
const RAID_EVERY := 2
const RAID_BASE := 3

## Beds in a finished Hut; the hurt get better faster in one.
const HUT_BEDS := 2
const HEAL := 0.15
const HEAL_IN_BED := 0.6

## How many peasants work one thing at a time when choosing for themselves.
## Orders from the player ignore these.
const CAPACITY := {"deer": 1, "tree": 1, "rock": 2, "item": 1, "site": 4, "fire": 3}

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
const PLANK := Color("#d8b07a")
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
