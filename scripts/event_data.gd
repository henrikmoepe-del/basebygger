extends RefCounted
## Events: things that happen to the castle and village by themselves. Every
## CHECK_TIME seconds there is a CHANCE that one starts, picked at random
## (by "weight") from those allowed today. GameState keeps the ones going
## (GameState.events) and ends each after "lasts" seconds; events.gd shows
## them in the world.
##
## Each event:
##   name        what it is called
##   start_text  the message when it starts
##   end_text    the message when it ends by itself
##   from_day    the first day it can happen
##   weight      how likely it is, next to the others
##   lasts       how many seconds it goes on
##   effects     what it does while it goes on: effect -> amount, read with
##               GameState.effect_total (the same effects policies use)
##   site        where in the world it happens: a gathering site's node name
##   click       optional: clicking it in the world ends it early, for
##               "reward" (resources) and with "click_text"
##
## Adding an entry here, and drawing it in events.gd, is all a new event needs.
## The raids still run on their own timer in GameState; they could move here.

const CHECK_TIME := 45.0
const CHANCE := 0.3

const EVENTS := {
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
}
