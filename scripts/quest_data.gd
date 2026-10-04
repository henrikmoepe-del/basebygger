extends RefCounted
## The chain of goals that guides the player, as plain data. Goals come one
## at a time, in this order; finishing one gives its renown and shows the next.
##
## "kind" says what is checked (see GameState._quest_done):
##   "part"      part "id" is at least level "amount"
##   "parts"     every part in "ids" is at least level "amount"
##   "job"       at least "amount" peasants are doing job "id"
##   "peasants"  at least "amount" peasants
##   "skills"    at least "amount" skill levels bought
##   "trained"   at least "amount" peasants trained
##   "raids_won" at least "amount" raids beaten
##   "rank"      castle rank at least "amount"
##   "cows"      at least "amount" cows

const QUESTS := [
	{"text": "Build the walls: press B, then click the circle by the castle", "kind": "part", "id": "walls", "amount": 1, "renown": 1},
	{"text": "Hire a fourth peasant and set them to find food", "kind": "job", "id": "hunter", "amount": 1, "renown": 1},
	{"text": "Buy your first skill (the Skills button)", "kind": "skills", "amount": 1, "renown": 1},
	{"text": "Raise the towers and a gate", "kind": "parts", "ids": ["towers", "gate"], "amount": 1, "renown": 2},
	{"text": "Build a farm, east of the grove", "kind": "part", "id": "farm", "amount": 1, "renown": 2},
	{"text": "Have 8 peasants", "kind": "peasants", "amount": 8, "renown": 2},
	{"text": "Buy a trade in the skill tree and train a peasant", "kind": "trained", "amount": 1, "renown": 2},
	{"text": "Build a keep", "kind": "part", "id": "keep", "amount": 1, "renown": 2},
	{"text": "Beat a raid", "kind": "raids_won", "amount": 1, "renown": 2},
	{"text": "Build a quarry, by the loose stones", "kind": "part", "id": "quarry", "amount": 1, "renown": 2},
	{"text": "Build a house in the village to the east", "kind": "part", "id": "houses", "amount": 1, "renown": 2},
	{"text": "Build a garrison and post a guard", "kind": "job", "id": "soldier", "amount": 1, "renown": 3},
	{"text": "Give the village a well and a tavern", "kind": "parts", "ids": ["well", "tavern"], "amount": 1, "renown": 3},
	{"text": "Reach castle rank 2", "kind": "rank", "amount": 2, "renown": 5},
	{"text": "Dig a mine", "kind": "part", "id": "mine", "amount": 1, "renown": 3},
	{"text": "Buy a cow (needs the Cattle skill)", "kind": "cows", "amount": 1, "renown": 3},
	{"text": "Have 25 peasants", "kind": "peasants", "amount": 25, "renown": 6},
	{"text": "Beat 5 raids", "kind": "raids_won", "amount": 5, "renown": 6},
	{"text": "Reach castle rank 3", "kind": "rank", "amount": 3, "renown": 10},
]
