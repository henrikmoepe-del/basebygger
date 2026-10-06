# Sandbox: a test map for the new job system

A separate test map, kept apart from the main game: nothing in `scripts/` or
`scenes/` is changed by it (it only borrows the UI look from `scripts/ui_theme.gd`).
Open `sandbox/sandbox.tscn` in Godot and press **F6** (Run Current Scene).

## Try this first (about five minutes)

1. Press **Space** to pause. Drag a box around the three builders on the left.
   Right-click the **Wall**: they go there (gold `!`). Space again to unpause.
2. Click **Freya** in the bar of names, then right-click a **log** lying by the
   trees: she hauls it. Shift + right-click a rock and then the ground: queued
   orders (numbered lines).
3. Press **W**: the Work overview. Click a cell to change a priority, or a job to
   change the job. Close it with W.
4. Press **T** for a raid. Select the builders, press **G** (draft) and
   right-click near the raiders: they stand and fight. Or press **L** (the bell)
   and everyone hides in the castle.
5. Press **F** for a fire and watch the bucket line from the well.
6. Click **Build**, pick a Hut, and place it with a left-click. Left-click the
   site and make it **Urgent**.
7. Click a single peasant and read their **card**: needs, mood and its reasons,
   skills, trait.
8. Click the **Sawmill** and change its bill (keep N planks).
9. Leave it running at **Speed 4x**: night falls, people go to bed, a traveller
   asks to join, a child is born, the hooded man comes on day 3...
10. Point at anything with nobody selected to see what it is.

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
   - **Light at night** (art direction): only warm light shows in the dark: fires,
     raiders' torches, lanterns at the stockyard and the well, the lit window of a
     finished Hut and the Sawmill's lamp (`sb_light.gd`).
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
   - **Flowerbeds and the watchtower** (Build menu): each finished flowerbed is a
     good thought for everyone ("A pretty village", up to three). With a finished
     watchtower, guards wait at its foot; while a guard keeps watch there, the bell
     rings by itself when raiders (or a werewolf) come in sight, and the all clear
     follows when they are gone.
   - **Raids:** they come by themselves: the first on day 2 at 17:00, then every 2
     days, one raider more each time (the top bar counts down the last day; T
     starts one at once). Raiders walk in from the west, fight anyone near, and head for the
     stockyard to steal (dropped loot can be hauled back). Each carries a torch and
     may set one building alight as they pass it: fires knock blocks off until put
     out (a fire with nothing left to burn dies down).
   - **Travellers:** from day 1 at 14:00 and then every day and a half, a
     traveller walks in from the east and asks to join (a small dialog shows
     their trait). Taken in, they start as a Hauler and get a place in the bar of
     names; sent away, they walk off. (From Henrik's next steps: "a traveller asks
     to join".)
   - **Storms** (Henrik's "nature catastrophes"): from day 2, a storm may roll in
     for a minute and a half: rain, a darker sky, work 20% slower, and lightning
     that may set a building alight or bring a tree down (its logs to collect).
   - **Werewolves** (from Henrik's list): from day 4, each night has a 25% chance
     of a werewolf coming out of the wood: much tougher and faster than a raider,
     after people, not goods. At dawn it slinks back into the wood. Drawn as deep
     shadow and red, as the art direction asks. The bell, a drafted group or the
     guard are the answers.
   - **Cave-ins** (Henrik's "people stuck in the mines"): each stone mined has a
     small chance of a cave-in that buries the miner. Anyone with Rescue work
     comes to dig (up to 3 at once; a bar shows how far). Trapped, the miner
     loses health now and then; dug out, they remember it (a bad thought).
     Right-click the rubble to send someone to dig.
   - **The hooded man** (Henrik's "mystical man with dark gifts"): from day 3,
     every 3 days, a hooded stranger waits at the edge of the wood and offers a
     gift: strange fruit (+25 food), black planks (+15), or making someone far
     better at their trade (+3 skill levels). Take it, and a while later the
     price comes, unannounced: someone falls ill, a cold blue fire starts, or
     everyone has dark dreams (a bad thought).
   - **Children:** at each dawn, while there are fewer children than finished Huts,
     a couple may have a child (everyone is glad: a good thought). Children are
     small (10 high, as the art direction says), have no job, follow a parent
     around, and grow up after 3 days as Haulers. The **Child labour** policy
     (top bar, from Henrik's list) lets them haul and pick berries at half pace;
     every grown-up minds it (-4 mood).
   - **Mood:** each peasant's mood drifts towards 55 plus their thoughts: needs
     (hungry, tired), states (in pain, drafted, Night work) and memories that
     fade (ate a meal, slept in a bed or on the ground, was hurt, saw someone go
     down, a raid beaten). The card shows the mood bar, where it is heading (a
     tick) and the strongest thoughts. At 75 and up they work 10% faster. Below
     15, someone left to themselves has had enough and sulks for 30 seconds (a
     little dark cloud), then feels better; orders, drafting and the bell still
     come first.
   - **The traitor** (from Henrik's list): from day 3, one grown-up (not a guard)
     may secretly start stealing at night: they get up, take some of the biggest
     pile from the stockyard and carry it off east, then go back to bed. Clues: a
     morning message about what went missing, and pointing at someone at night
     may show "Sneaking off with 3 planks...". A guard or someone drafted within
     reach catches them in the act; then banish or forgive.
   - **Strikes** (from Henrik's list): when the grown-ups' average mood stays under
     30 for a minute, they lay down their tools. Hold a feast (20 food; a big good
     thought) to end it, or wait it out (90 seconds without work by free will;
     fires and the hurt are still seen to). Orders still work, but being made to
     work during a strike is a bad thought.
   - **Traits** (as in the main game): Quick and Slow walk faster or slower,
     Hard-working and Lazy work faster or slower. Shown on the card.
   - **Dozing** (one of the "small things to click"): by day, someone working while
     somewhat tired (not tired enough to go to bed) may nod off where they stand (Lazy ones often, Hard-working ones rarely):
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
| Space | Pause. Everything stops, but you can still select, give and queue orders, draft and open panels; they are carried out when you unpause (the Speed button also unpauses) |
| G (or Draft) | Draft the selected: they drop their work, get a cudgel and a red shield mark, stand where you send them and fight any raider who comes near. G again to undraft |
| X (pointing at a tree, rock, bush, item or site) | Forbid it: nobody touches it by themselves (red cross). X again allows it; ordering someone to it allows it too |
| L (or Bell) | The alarm bell: everyone who is not a guard, drafted or under orders goes in through the castle gate and waits inside, out of the raiders' reach; guards go to their post or fight. Ring it again for the all clear |
| R | Release the selected: back to free will (clears the queue too) |
| 1-8 | Make the selected Builders, Woodcutters, Miners, Foragers, Hunters, Crafters, Haulers or Guards |
| Esc | Deselect |
| T / F | Start a raid / a fire (to test) |
| A / D, middle-drag, wheel | Pan, zoom (whole steps: 0.5x, 1x, 2x, 3x) |
| Point at something (nobody selected) | What it is: "A tree: 3 logs left", a site's progress, the stockyard's stock |
| J (or Log) | The message log: the last 30 messages |
| M | Mute (the main game's sounds, made in code; only what happens on screen is heard) |

The gold `!` over a peasant means they have an order. Selected peasants show a
dotted line to what they are working on (gold for an order, white for free will).

## The look

The people are the figures from the Game_1 Art Direction page's people sheet,
read pixel for pixel from its 8x picture (`tools/people_native.png`,
`tools/gen_sprites.py` makes `sb_sprites.gd`). Builder: the grey builder without
the block on the head. Woodcutter and Miner: the plain peasant in green and slate.
Forager: the straw hat. Crafter: the cook. Hunter: the archer. Guard: the
spearman. Hauler: the plain peasant. Raiders: the raider. Children: the child.
Walking lifts a foot; the hurt and sleeping lie as the same figure on its side;
someone carried lies across the carrier's shoulders. What they carry and their
tools are drawn on top.

## Files

- `sandbox.gd`: the world (map, finding work, selection and orders, test events).
- `sb_data.gd`: work types, jobs (priority presets), palette, ground size.
- `sb_peasant.gd`: a peasant: priorities, order, choosing work, doing it, drawing.
- `sb_thing.gd`: the base for anything that can be worked on or ordered to.
- `sb_site.gd`, `sb_tree.gd`, `sb_rock.gd`, `sb_bush.gd`, `sb_deer.gd`, `sb_item.gd`, `sb_fire.gd`,
  `sb_raider.gd`, `sb_stockyard.gd`, `sb_well.gd`: the things in the world.
- `sb_stranger.gd`: the hooded man (looks only).
- `sb_sprites.gd`: the people's pixels (made by `tools/gen_sprites.py`).
- `sb_light.gd`: warm lights for the night.
- `sb_backdrop.gd`: sky, mountains, the castle wall, the ground band and path.
- `sb_hud.gd`: top bar, the bar of peasants, the panel for the selected, messages.
- `tests/run_tests.sh`: loads the map once to catch script errors, then runs
  the logic test (a parse error would otherwise make the test hang).
- `tests/test_sandbox.gd`: logic test (headless):
  `godot --headless --fixed-fps 60 --path . -s sandbox/tests/test_sandbox.gd`
- `tests/test_input.gd`: plays with real mouse and key events in a window
  (click, Shift-click, double-click, box, right-click, keys); under xvfb in the cloud.
- `tests/soak.gd`: runs the map for days with no player (raids and fires now and
  then) and reports what everyone does and anything that looks stuck:
  `godot --headless --fixed-fps 60 --path . -s sandbox/tests/soak.gd -- --days=3`
- `tests/perf.gd`: times a frame with more peasants (`-- --peasants=80`). On
  2026-10-06: 10 peasants 0.6 ms, 40 peasants 1.3 ms, 80 peasants 2.1 ms a frame
  (headless, without drawing), so the job system has room to grow.
- `tests/shots.gd`: screenshots in a real window:
  `godot --path . -s sandbox/tests/shots.gd -- --plan=orders --out=<folder>`
  (plans: start, orders, raid, fire, box).
- `DESIGN.md`: why the job system works this way, and open questions.
- `HOOKUP.md`: what it would take to bring this into the main game.

## Kept simple on purpose

Building here is "carry a block, set it": no scaffolds, ladders, hoists or decks.
That system stays in the main game; this map is about *who works where* and
*how the player steers them*. Nothing is balanced.
