extends RefCounted
## Events: things that happen to the castle and village by themselves. Every
## CHECK_TIME seconds there is a CHANCE that one starts, picked at random
## (by "weight") from those allowed today. GameState keeps the ones going
## (GameState.events) and ends each after "lasts" seconds; events.gd shows
## them in the world.
##
## Each event:
##   name        what it is called
##   start_text  the message when it starts ({raiders}: the raid's size)
##   end_text    the message when it ends by itself
##   from_day    the first day it can happen
##   weight      how likely it is, next to the others (chance events)
##   schedule    instead of weight: {"from_day", "every_days"}, it comes on a
##               timetable, the next time counted from how often it has been
##   lasts       how many seconds it goes on
##   until_done  instead of lasts: it goes on until the game ends it (a raid
##               ends when it is beaten or reaches the castle)
##   effects     what it does while it goes on: effect -> amount, read with
##               GameState.effect_total (the same effects policies use);
##               "happiness" is points of happiness while it goes on
##   needs       optional: {"happy": true} only while the peasants are happy,
##               {"unhappy": true} only while they are unhappy,
##               {"season": "winter"} only in that season (see season_data.gd)
##   site        where in the world it happens: a gathering site's node name,
##               or "site_x" for a place by its x (events.gd draws it there)
##   click       optional: clicking it in the world ends it early, for
##               "reward" (resources) and with "click_text"
##   offers      a trader's offers: one is picked when it comes, {"give", "get"}
##               (resources); clicking pays "give" for "get"
##   burns       resource -> share of it lost if the event runs out unclicked
##   hurts       a peasant of this job is hurt while it goes on, and works
##               at HURT_PACE ({person} in the texts is their name)
##   needs       {"building": true}: only while something is being built
##
## Adding an entry here, and drawing it in events.gd, is all a new event needs.
## What happens during a raid is in raiders.gd and GameState's raid part.

## How fast a hurt peasant works and walks.
const HURT_PACE := 0.5
const CHECK_TIME := 45.0
const CHANCE := 0.3

const EVENTS := {
	"raid": {
		"name": "Raid",
		"start_text": "Raiders approach from the west! {raiders} of them",
		"schedule": {"from_day": 5, "every_days": 3},
		"until_done": true,
		"effects": {},
	},
	"badger": {
		"name": "Badger in the crops",
		"start_text": "A badger is digging up the food at the wilds! Click it to chase it off.",
		"end_text": "The badger has eaten its fill and wandered off",
		"from_day": 2,
		"weight": 1.0,
		"lasts": 120.0,
		"effects": {"food_site_rate": -0.6},
		"site": "Wilds",
		"click": true,
		"reward": {"food": 5},
		"click_text": "Badger chased off! The crops are safe: +5 food",
	},
	"merry": {
		"name": "Merry work",
		"start_text": "The peasants are happy and sing as they work: everyone works faster for a while",
		"end_text": "The singing has died down",
		"from_day": 2,
		"weight": 1.0,
		"lasts": 120.0,
		"effects": {"work_speed": 0.15},
		"needs": {"happy": true},
	},
	"strike": {
		"name": "Strike",
		"start_text": "The peasants are unhappy and have downed tools! Everyone works much slower for a while",
		"end_text": "The strike is over and the peasants are back at work",
		"from_day": 2,
		"weight": 1.0,
		"lasts": 90.0,
		"effects": {"work_speed": -0.5},
		"needs": {"unhappy": true},
	},
	"flowers": {
		"name": "Spring flowers",
		"start_text": "The meadows are full of flowers, and everyone is in a good mood",
		"end_text": "The flowers have faded",
		"from_day": 2,
		"weight": 1.0,
		"lasts": 150.0,
		"effects": {"happiness": 10.0},
		"needs": {"season": "spring"},
	},
	"drought": {
		"name": "Drought",
		"start_text": "A drought! The wilds and the fields dry up, and less food grows",
		"end_text": "Rain at last: the drought is over",
		"weight": 1.0,
		"lasts": 120.0,
		"effects": {"food_site_rate": -0.5},
		"needs": {"season": "summer"},
	},
	"harvest": {
		"name": "Rich harvest",
		"start_text": "A rich harvest! Food grows twice as fast for a while",
		"end_text": "The harvest is in",
		"weight": 1.0,
		"lasts": 120.0,
		"effects": {"food_site_rate": 1.0},
		"needs": {"season": "autumn"},
	},
	"cold_snap": {
		"name": "Cold snap",
		"start_text": "A bitter cold snap: everyone works slower and is unhappy until it passes",
		"end_text": "The cold snap has passed",
		"weight": 1.0,
		"lasts": 120.0,
		"effects": {"work_speed": -0.2, "happiness": -10.0},
		"needs": {"season": "winter"},
	},
	"trader": {
		"name": "Trader",
		"start_text": "A trader's cart stands by the stockyard: {offer}. Click the cart to trade",
		"end_text": "The trader has moved on",
		"from_day": 2,
		"weight": 1.0,
		"lasts": 120.0,
		"effects": {},
		"site_x": 752.0,
		"click": true,
		"offers": [
			{"give": {"wood": 40}, "get": {"planks": 25}},
			{"give": {"stone": 40}, "get": {"iron": 10}},
			{"give": {"food": 40}, "get": {"stone": 50}},
			{"give": {"wood": 30}, "get": {"food": 40}},
		],
		"click_text": "Traded {offer}",
	},
	"fire": {
		"name": "Fire",
		"start_text": "Fire in the stockyard! Click it to put it out before the wood and planks burn",
		"end_text": "The fire burned out: a quarter of the wood and planks went up in smoke",
		"from_day": 3,
		"weight": 0.6,
		"lasts": 60.0,
		"effects": {"happiness": -5.0},
		"site_x": 630.0,
		"click": true,
		"click_text": "The fire is out! Nothing was lost",
		"burns": {"wood": 0.25, "planks": 0.25},
	},
	"accident": {
		"name": "Fall",
		"start_text": "{person} fell from the scaffold and is hurt: they work at half pace for 3 minutes",
		"end_text": "{person} is well again",
		"from_day": 2,
		"weight": 0.6,
		"lasts": 180.0,
		"effects": {},
		"hurts": "build",
		"needs": {"building": true},
	},
}
