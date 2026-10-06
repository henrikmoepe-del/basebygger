# Sandbox: a test map for the new job system

A separate test map, kept apart from the main game: nothing in `scripts/` or
`scenes/` is changed by it (it only borrows the UI look from `scripts/ui_theme.gd`).
Open `sandbox/sandbox.tscn` in Godot and press **F6** (Run Current Scene).

## What it tries out

1. **A ground with depth** (after the Game_1 Art Direction page). The ground is a
   band 80 pixels deep in front of the castle wall, with a dirt path along it.
   Peasants walk along it *and* towards or away from the viewer, so they can pass
   each other and work side by side. Nothing is scaled: further forward only means
   lower on the screen and drawn in front (a y-sorted node).
2. **Several building sites at once.** The Hut, the Wall and the Tower are each
   their own job. A planned building shows as a faint outline (a blueprint) and
   fills in block by block. Builders spread out over the sites by themselves.
3. **The new job system** (think RimWorld, with assigned jobs):
   - Every peasant has a **priority for each kind of work**: Fires, Fight, Rescue,
     Build, Chop, Mine, Food, Hunt, Craft, Haul. 1 = first, 2, 3 = last, - = never.
   - A **job is a preset** of those priorities. Builder: Fires 1, Rescue 1, Build 1,
     Haul 3. Woodcutter: Fires 1, Rescue 1, Chop 1, Haul 3. Miner: Fires 1, Rescue 1,
     Mine 1, Haul 3. Forager: Fires 1, Rescue 1, Food 1, Haul 3. Crafter: Fires 1, Rescue 1, Craft 1,
     Haul 3. Hunter: Fires 1, Rescue 1, Hunt 1, Haul 3. Hauler: Fires 1, Rescue 1, Haul 1, Build 3. Guard: Fight 1,
     Rescue 1, Fires 2. You can change
     single priorities per person in the panel (click a priority to cycle it).
   - **Free will:** left alone, a peasant does the most important work there is for
     them: the lowest number first; with the same number, the work further left in
     the Work grid first (Fires, Fight, Rescue, Build, ...), as in RimWorld; then the
     nearest target (builders also prefer a site with fewer builders on it).
     After each piece of work (a block set, a log chopped) they look around again.
   - **Emergencies come by themselves:** a fire gets up to 3 peasants per fire
     running buckets from the well; guards fight raiders; anyone with Fight "-"
     runs away from raiders that come near.
   - **Hauling** means taking loose logs and stones to the stockyard (up to 3 of a
     kind lying close together in one trip), and bringing
     building material from the stockyard to the sites (it lies in a pile there,
     and builders take from it before walking to the stockyard themselves).
   - **Gatherers stop when it piles up:** when 4 or more loose things lie by a tree,
     rock or bush, nobody works there by themselves until some are hauled away, so
     the woodcutter, miner and forager turn to hauling (their priority 3).
   - **Skills** (Build, Chop, Mine, Fight) grow by doing the work: level 0 works at
     60% speed, 5 at 100%, 10 at 140%. Shown as "·n" in the Work overview.
   - **The hurt:** a peasant beaten in a fight goes down. Anyone with Rescue carries
     them to a bed in a finished Hut (2 beds each), or to the well if all beds are
     taken. They get better on the ground, faster in a bed.
   - **Needs:** hunger and tiredness grow over time. Past 60 hunger (80 tired) a
     peasant left to themselves stops work to eat a basket of food at the
     stockyard, or to sleep (in a free Hut bed, faster, else on the ground).
     Orders and drafting come first, as in RimWorld, but at 100 they work slower.
     Food comes from berry bushes, picked by the **Forager**.
   - **Day and night:** a day lasts 4 minutes (the clock is in the top bar). At
     night, peasants left to themselves go to bed. The **Night work** policy (top
     bar) keeps them working through the night instead: 15% slower in the dark,
     and they tire 1.5 times as fast. Beds are reserved by whoever heads for them.
   - **Hunting:** deer graze in the wood to the east and run from anyone who comes
     near. The **Hunter** (work type Hunt) creeps within bow range, aims and shoots;
     the Hunt skill raises the chance to hit. A miss scares the deer off, a kill
     sends the herd running. A deer leaves 2 meat (food), which the hunter carries
     home straight away; the herd slowly grows back to 4.
   - **Workshops and bills:** the Sawmill (standing at the start, or build more)
     turns logs into planks; the Tower's top needs planks. Click a finished
     workshop to set its bill: how many to keep in stock (0 stops it). The
     **Crafter** (work type Craft) takes logs for up to 3 at once, saws them at the
     bench and carries the planks back. Right-click a workshop to order someone
     to work there (ordered, they keep on past the bill).
   - **Raids:** they come by themselves: the first on day 2 at 17:00, then every 2
     days, one raider more each time (the top bar counts down the last day; T
     starts one at once). Raiders walk in from the west, fight anyone near, and head for the
     stockyard to steal (dropped loot can be hauled back). Each carries a torch and
     may set one building alight as they pass it: fires knock blocks off until put
     out (a fire with nothing left to burn dies down).
   - **Traits** (as in the main game): Quick and Slow walk faster or slower,
     Hard-working and Lazy work faster or slower. Shown on the card.
   - **Dozing** (one of the "small things to click"): by day, someone working while
     tired may nod off where they stand (Lazy ones often, Hard-working ones rarely):
     a drooping head and z's, and nothing gets done. Click them to wake them: they
     work 25% faster for a while.
   - **Orders:** select peasants and right-click something. The order comes before
     everything else (even fleeing) until it is done, then they go back to free will.
     **R** (or Release) ends the order early.

## Controls

| Input | What it does |
|---|---|
| Left-click a peasant | Select (Shift adds or removes) |
| Drag with the left button | Select everyone in the box |
| Double-click a peasant | Select everyone with the same job |
| Ctrl+A | Select everyone |
| Click a name in the bar at the top | Select that peasant |
| Right-click a site | Build there |
| Right-click a tree / rock / berry bush | Chop it / mine it / pick it, until it is used up |
| Right-click a log or stone on the ground | Haul it to the stockyard (several selected take one each) |
| Right-click a fire | Put it out (buckets from the well) |
| Right-click a deer | Hunt it |
| Right-click a raider | Fight it (guards hit 3, others 1.5, times their Fight skill) |
| Right-click a hurt peasant | Carry them to a bed |
| Right-click the ground | Go there and hold |
| B (or Build) | Build menu: pick a building, left-click where it goes (Shift-click: several; right-click: stop). Red outline = does not fit |
| Left-click a building site | Its progress; make it **Urgent** (builders go there first, red pennant) or **Cancel** it. On a finished workshop: its bill |
| Right-click a finished workshop | Work there |
| W (or Work) | The Work overview: every peasant's job and priorities, click to change |
| Shift + right-click | Queue the order after the ones already given (numbered dotted lines) |
| G (or Draft) | Draft the selected: they drop their work, get a cudgel and a red shield mark, stand where you send them and fight any raider who comes near. G again to undraft |
| X (pointing at a tree, rock, bush, item or site) | Forbid it: nobody touches it by themselves (red cross). X again allows it; ordering someone to it allows it too |
| L (or Bell) | The alarm bell: everyone who is not a guard, drafted or under orders goes in through the castle gate and waits inside, out of the raiders' reach; guards go to their post or fight. Ring it again for the all clear |
| R | Release the selected: back to free will (clears the queue too) |
| 1-8 | Make the selected Builders, Woodcutters, Miners, Foragers, Hunters, Crafters, Haulers or Guards |
| Esc | Deselect |
| T / F | Start a raid / a fire (to test) |
| A / D, middle-drag, wheel | Pan, zoom (whole steps: 0.5x, 1x, 2x, 3x) |
| Point at something (nobody selected) | What it is: "A tree: 3 logs left", a site's progress, the stockyard's stock |
| M | Mute (the main game's sounds, made in code; only what happens on screen is heard) |

The gold `!` over a peasant means they have an order. Selected peasants show a
dotted line to what they are working on (gold for an order, white for free will).

## Files

- `sandbox.gd`: the world (map, finding work, selection and orders, test events).
- `sb_data.gd`: work types, jobs (priority presets), palette, ground size.
- `sb_peasant.gd`: a peasant: priorities, order, choosing work, doing it, drawing.
- `sb_thing.gd`: the base for anything that can be worked on or ordered to.
- `sb_site.gd`, `sb_tree.gd`, `sb_rock.gd`, `sb_bush.gd`, `sb_deer.gd`, `sb_item.gd`, `sb_fire.gd`,
  `sb_raider.gd`, `sb_stockyard.gd`, `sb_well.gd`: the things in the world.
- `sb_backdrop.gd`: sky, mountains, the castle wall, the ground band and path.
- `sb_hud.gd`: top bar, the bar of peasants, the panel for the selected, messages.
- `tests/run_tests.sh`: loads the map once to catch script errors, then runs
  the logic test (a parse error would otherwise make the test hang).
- `tests/test_sandbox.gd`: logic test (headless):
  `godot --headless --fixed-fps 60 --path . -s sandbox/tests/test_sandbox.gd`
- `tests/soak.gd`: runs the map for days with no player (raids and fires now and
  then) and reports what everyone does and anything that looks stuck:
  `godot --headless --fixed-fps 60 --path . -s sandbox/tests/soak.gd -- --days=3`
- `tests/shots.gd`: screenshots in a real window:
  `godot --path . -s sandbox/tests/shots.gd -- --plan=orders --out=<folder>`
  (plans: start, orders, raid, fire, box).
- `DESIGN.md`: why the job system works this way, and open questions.
- `HOOKUP.md`: what it would take to bring this into the main game.

## Kept simple on purpose

Building here is "carry a block, set it": no scaffolds, ladders, hoists or decks.
That system stays in the main game; this map is about *who works where* and
*how the player steers them*. Nothing is balanced.
