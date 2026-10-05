## About the game
- Name: Game_1
- Genre: Incremental Builder Wave Defence
- Core idea in one sentence: Incremental 2DCastle Builder that turns into 3D for wave defence
- Main mechanic:Incremental Builder/wave defence
- Target platform: PC (Windows)

## Tech
- Engine: Godot 4, using GDScript
- Version control: Git, with the github plugin

## Installed plugins
- godot@ai-game-dev-plugin: project setup, engine and code
- game-design@gamedev-claude-plugins: mechanics, levels, balance
- thinking@gamedev-claude-plugins: brainstorming and planning
- juice@gamedev-claude-plugins: game feel and polish (audits, recipes)
- github@claude-plugins-official: version control

## Adding plugins when needed
- When we start on audio, shaders, multiplayer, rendering,
  shipping, procedual, multiplayer, art, ai systems, or anything else that could use a plugin,or check the claude-code-game-development marketplace
  for a matching plugin.
- Ask me before installing. If I say yes, install it with
  `claude plugin install <plugin>@claude-code-game-development`
  and tell me to run /reload-plugins.
- Never install a second general Godot plugin.

## How to work with me
- I'm learning game development, so briefly explain what you
  did and why after each change.
- Work in small steps: one feature at a time, and make sure it
  runs before the next.
- Before a bigger change, describe the plan and wait for my OK.
- After each working feature, make a Git commit.
- If something breaks, tell me plainly what went wrong and how
  to undo it.
- If I suggest something that makes the game much bigger, point
  it out and suggest a smaller version first.
- After finishing a feature, update "Current status" below.
- If you believe a tool/program/pluggen would be of good use, for example to create pixel 2d art, to create sound, etc, then say so 

## Where we left off (2026-10-05)
- Next task, already approved by Henrik: let the player CHOOSE the rooms of the keep. Each new
  storey offers a pick of what to build there, and rooms start doing something of their own
  (e.g. a store that holds more, an armoury that makes soldiers hit harder). Today the rooms come
  with the keep's levels in a fixed order (`CastleData.keep_rooms`) and only the kitchen and the
  beds are used.
- Open questions Henrik has not answered: should the keep need a click or held key to turn
  see-through, instead of fading whenever the mouse passes over it? Which buildings count as
  "fine" and need planks early (now: court and tavern)?
- Nothing is balanced on purpose (building is slow, raids and planks are first guesses).
- How to work: after any change to how building or peasants look, run `tests/screenshot.gd`
  and LOOK at the pictures, both the close-up and the `_wide` one, then run the three tests.

## Future ideas (Henrik's list, 2026-10-05)
Not started. Keep them in mind when building features, so new systems can connect to them later.
- Events: traders; raids; a mystical man who wants to give you dark gifts; werewolves; a traitor
  in the base; fire; fall accidents; people getting stuck in the mines; strikes; nature catastrophes.
- Buildings: wells; a moat; different kinds of towers; mines; bath house; whore house; windmills;
  temples; torture and punishment; flowerbeds; smith; tanner; bakery.
- Policies (the player chooses): work during the night; smaller rations; child labour; everyone
  must bathe; religion allowed or not; cults allowed or not.
- Peasants come from children: apart from travellers joining and bandits converted, the only way
  to get peasants is peasants having children. Parents get a small sum to raise the child and work
  less while raising it. A policy decides whether people should have children.
- An area to the right of the village (a forest or similar) to hunt wild animals, meet bandits, etc.
- Boosts you can buy that raise the effectiveness of various things.
- Expeditions? A world map?
- Choosing where to place houses: maybe there isn't room for every house type and you must
  choose, or you can expand into the forest on the right.
- Small things to click for small bonuses: wake a sleeping worker, chase off a badger that ruins
  the crops.
- Seasons.
- Materials: planks are a resource of their own, on top of wood. Basic buildings need only wood;
  more luxurious ones and later upgrades need planks. (Bricks from a brickworks the same way, later.)
- Rooms inside the main castle building that you build, seen through see-through walls.

What this means for the design now (Claude's notes):
- Peasants will become individuals (parents, children, sleeping, bathing, striking, traitors), so
  avoid new code that treats them only as a count per job. `workers.gd` re-making peasant nodes
  when jobs change will have to go.
- Events and policies need one place to live: plan for a small event system and a policy list in
  `GameState` rather than one-off timers like the raid.
- Buildings will be many and placed by choice: keep building data in `castle_data.gd` style
  entries, and don't hard-code more x positions than needed.

## Current status
- Stage: working on the 2D builder (make it better, more realistic, more fun) and on raids.
  The 3D wave defence is a first prototype; it now starts by itself when raiders reach the castle.
  Placeholder art.
- The player never clicks to gather. Peasants do all the work; the player hires them, gives
  them jobs, trains them, points at the world to build, and buys skills.
- World layout: the castle is in the middle (x = 0) and about 980 wide. Defence is to the west, where
  raiders come from (palisade, watchtower). The stockhouse, quarry, grove, wilds, mine and village are to the east.
- The castle is a side view with the front wall cut away: the curtain wall and gate are at the back,
  and the court, keep and garrison stand in the courtyard in front of it, between two end towers.
  Towers adds wall towers at level 3 and gate towers at level 5; the keep gets corner turrets at 4
  and a great tower at 7; pointed roofs come at higher levels (`CastleData.towers`, `shapes`).
- Done:
  - Start with 3 generalist peasants. Jobs: chop wood, mine stone, find food, build, cook,
    stand guard (needs a garrison), mine iron (needs a mine), tend the grove (needs the Foresters skill)
  - Trades: big skill-tree unlocks that let peasants in a job be trained (twice as good, wear a hat)
  - Castle: eight parts (walls, towers, gate, keep, garrison, court, palisade, watchtower);
    a castle rank caps levels; castle levels 4+ need iron. Village: houses, well, tavern, quarry, mine
  - Goals: a chain of objectives in `scripts/quest_data.gd`, one at a time, each paying renown
  - Stone and food come from sites that refill over time (faster with Quarry and Farm levels)
  - Planks: a resource of their own, on top of wood. The Sawmill (village) gives the "Saw planks"
    job, 2 sawyers per level (`sawyer.gd`): they carry logs from the wood stack, saw them, and
    stack planks in the stockyard; one log makes one plank. Basic building costs only wood;
    from level 3 every part also costs planks, and the finer buildings (`CastleData.FINE`: court,
    tavern) from level 2 and twice as many (`GameState.part_cost`). Bricks are not started.
  - Stockyard (just east of the castle, drawn by `workers.gd`, see `STORES`): a shed with a store
    for each resource beside it. Each store is a stack that grows with the amount, with the number
    above it. Gatherers deliver to the right store and builders fetch from it (`store_x`).
    No storage limits yet. Ideas for later: stores as things you build and enlarge, limits,
    stores inside the castle walls.
  - Scenery: parallax hills, clouds, grass; peasants' legs move; numbers float up at the stockhouse
  - Game feel: chips fly and trees shake when worked, the stockhouse bumps and shows log and stone
    piles, finished castle parts flash with dust and a small screen shake, messages pop in
  - Sound: placeholder effects generated in code (`scripts/sfx.gd`), M to mute. No music yet.
  - Interface: one theme in `scripts/ui_theme.gd` (dark wood panels, parchment text). Top bar with
    resource chips, a goal and raid line, a foldable peasants panel, a message banner, a bottom
    bar, and a Menu for Pass the crown and New game. Details live in tooltips.
  - Cows (Cattle skill) wait with carts at gathering sites and haul loads home
  - Build mode: B (or the Build button) shows a circle per part; pointing at one shows a card with
    a round preview, cost, benefit and drawback; click to order. Nothing can be ordered outside it.
  - Building: nothing appears out of thin air. `build_plan.gd` turns a job into a list of pieces
    (scaffold bays, then stone blocks a course at a time, then each fitting: window, door,
    battlement, roof step). Every piece is carried from the stockhouse to the yard at the foot of
    the site, shaped at the bench there, pulled up by the rope, picked up at the top, carried to its
    place and set in. `GameState` counts how far the pieces have got (`job_hauled`, `job_formed`,
    `job_lifted`, `job_taken`, `job_placed`); `builder.gd` picks which step to do; `castle.gd` draws
    the yard, piles and hoist and says where to stand. Two benches and one rope per site.
    How a section goes up: walls a course at a time, laid from the top of what is built so far
    (its "deck"). Builders reach the deck by the building's own stairs (in at the door, out on
    top) or the wall's stair ladder; a section with neither gets one whole ladder, removed at the
    end. Battlements, roofs and flags are set from the deck, doors from the ground. Scaffolding
    is only for details on the face (windows, arrow slits): put up a lift at a time with one
    ladder, then taken down and carried back. Old battlements and flags stay until new stone is
    laid over them. Pieces follow their material (`item_for`): stone blocks, planks for timber
    parts (thin courses), daub panels, thatch, roof tiles.
    Builders reserve a piece before walking to it, and wait by the yard when there is nothing to do.
    The benches in the yard and the hoist on the deck are pieces too: carried in, set up, and
    taken away at the end. Anything set up or taken down, or set from a scaffold platform, is done
    one piece at a time in order (`castle.needs_turn`); stone laid from the deck can go side by side.
    A deck is only as wide as the section's main body, so nobody stands beside a roof peak.
  - Stairs inside: towers, keep and garrison have a stair door on the roof (`_stair_door`) and a
    column of windows on the stairs; peasants climbing inside show through those windows
    (`workers.gd` `_draw_inside`). While a deck is being raised there is a hatch where they come up.
  - Known and intended: peasants on the curtain wall pass behind the courtyard buildings, so they
    are out of sight for a moment there.
  - Courses are counted from the top of what already stands, so a new course sits exactly on the
    old wall. A deck has a step in it: builders stand on the stretch of the course already laid
    (`castle._deck_step`, `surface_at`), not in front of it.
  - While a level is added, what the new level replaces (battlements, turrets, roofs, flags) is
    first knocked down by builders standing on the old wall, a piece at a time, and falls to the
    ground (`Kind.DISMANTLE`, `plan.gone`). Nobody strolls or stands guard on a part being rebuilt.
  - Crew work (`builder._choose_task`): while there is work up on a deck, part of the crew stays
    up (1 of 2-3 builders, 2 of 4-6, 3 of 7+): one at the hoist hauling, the rest setting pieces.
    The others stay on the ground fetching, shaping, and tying each shaped piece on the rope
    (`GameState.job_hook`); the rope lifts nothing until someone below has tied it on. A lone
    builder does it all and saves the climb until four pieces are ready.
  - Blocks: the bottom course of a stone building is of big foundation stones ("boulder", 1.5
    blocks wide) that take two to carry. Doors are marked `CastleData.FITTING` so they are made
    and set in whole, not laid as wall.
  - Ideas Henrik wants next (not started): materials made in their own buildings (bricks from a
    brickworks, planks from a sawmill) and carried to the site; rooms inside the keep, with walls
    that turn see-through when hovered or by a button.
  - The keep has storeys and rooms: you step up into the entrance storey, and each level adds a
    storey (`KEEP_STOREY`). A staircase runs up the middle with a room either side on every storey
    (`CastleData.keep_rooms`): kitchen and great hall at the bottom, store and armoury above,
    bedchambers above that, the lord's chamber at the top. Every storey is a floor marked
    "inside" (`CastleData.floors`), so peasants walk into the rooms, out of sight unless the
    keep is see-through. Cooks work in the kitchen once there is a keep; peasants within reach
    sleep in the keep's beds, lying down, while the beds last (`Workers.bed_spot`); idle peasants
    wander through the rooms. Rooms are drawn by `castle._draw_rooms`. Not yet: choosing which
    rooms to build, and rooms that do something of their own.
  - A building with stairs inside is reached by a short ladder until its walls are a storey high
    (`BuildPlan.START_LADDER`); after that builders come up through an open stairwell in the wall top.
  - Looking inside: pointing at a building with stairs inside (towers, keep, garrison, also while
    it is being built) makes its front see-through, showing the back wall, the landings, the
    flights of stairs and the peasants on them; X or the Inside button does it for all of them
    (`castle.interiors`, `_draw_interior`, `_paint`). Rooms to build inside are not started.
  - Stairs inside buildings go up in flights, back and forth (`castle.route` turns hidden steps
    into flights); a peasant finishes a flight before changing their mind. Until the stair door is
    built there is an open trapdoor in the deck.
  - Carrying: each item has its own shape on the shoulder (`builder._draw_item`). Ladders, benches
    and the hoist (`BuildPlan.HEAVY`) take two builders to carry from the stockyard; with nobody to
    help, one drags it slowly. The hoist stays on the deck until it is taken down and carried off.
  - Leisure (`worker.gd` `_relax`): nobody stands and waits. A peasant with no job, or a builder or
    gatherer with nothing to do right now, strolls, walks the lands, visits another to talk
    (speech bubbles) or play ball, or sits in the tavern. Builders stay near their yard.
  - Movement rule: peasants only move along the ground, along a floor, or up and down a stair
    (`castle.route`). A target with no floor under it is not reachable; the way ends on the ground
    below it. Anything a peasant must stand on has to be a floor (`CastleData.floors`, or
    `castle.job_floors` for decks and scaffold platforms). The build test checks for this.
  - Wanted next for building (Henrik): pieces that must be made first, e.g. a window made at a
    workstation from gathered materials and then carried to the site. The hook is `BuildPlan.ITEMS`
    ("item" per piece kind): give an item a recipe and have builders fetch it from the workstation.
  - Walkable castle: `CastleData.floors()` lists floors and stairs per part; `castle.gd` finds the way
    (`route`), and `worker.gd` `_go_to` walks it. Soldiers patrol the wall walk, tower tops and roofs;
    idle peasants stroll around the castle; at night everyone sleeps behind the nearest door.
    Stairs inside towers, keep and garrison are hidden: peasants go in at the door and come out on top.
  - Skill tree: a pannable node map with four arms, levels per skill, hidden "?" nodes; paid with renown
  - Day and night (a day is 5 minutes; Menu > Nights turns night off for playtesting), food and
    hunger, trees that run out and regrow, raids every 3 days
  - Pass the crown (prestige) with lasting legacy; save/load with offline progress; New game
  - Camera: drag or A/D to pan, drag up/down or W/S to look up at the castle, mouse wheel zooms out
    to a quarter size (the whole world); the world's sounds fade as the view zooms out
  - Dev shortcuts (editor runs only): F2 speed, F3 skip 10 min, F4 resources, F6 peasants, F1 hide
- Henrik's list from the last round is built. Wanted later: more minerals than iron, better food
  from trained cooks, buildings only trained builders can raise, individual peasant traits
- Known balance issues: iron piles up late (costs are low); food is now tight in the mid game;
  building is slow on purpose and NOT balanced yet (Henrik: balance later, the game is meant to take
  hours): the first wall level takes one builder about 27 daytime minutes, six builders a few
  minutes per level. Knobs: `BUILDER_BASE_LOAD` (3 pieces per trip), `CastleData.BLOCK_WIDTH`,
  the times in `builder.gd`. "work" in `castle_data.gd` and the Masonry-style work skills that
  scaled it are unused or weak now; costs were not changed for the bigger castle.
  The scaffold vanishes at once when a job is done.
- Next for the castle: rooms inside it (kitchen, smithy, stores) so more jobs happen within the walls;
  lit windows at night; the two towers as separate parts.
- Design notes:
  - Castle parts and soldiers are defences. `GameState.total_defence()` and the part levels are
    what the later 3D wave defence will read; raids are the 2D stand-in for it.
  - Data lives in `scripts/*_data.gd` (castle parts and village buildings, jobs, skills); adding
    an entry there is usually all it takes to get new content on screen.
  - Everything built should have a benefit and, where it makes sense, a real drawback
    (see the drawback constants in `castle_data.gd`).
  - Henrik's design ideas are starting points: explore and expand on them, then explain the choices.
- Raids (basics, `raiders.gd`, `soldier.gd`, `Workers.battle_post`): every 3 days raiders walk in
  from the west, more and tougher each time. They are fought live in the 2D world. The palisade
  blocks them until they hack it down; spearmen behind it jab through the stakes; archers on the
  watchtower, towers and wall walk shoot from range (further from higher up). Soldiers take posts
  by themselves, an archer then a spearman in turn. A beaten spearman falls back to the garrison
  for the rest of the raid. All raiders down = raid beaten. A raider reaching the castle starts the
  3D gate fight with the share of raiders still standing (`siege_share`). Not balanced.
  Ideas next: the player choosing posts, more outer works, raider kinds, damage that lasts.
- 3D siege prototype (`scenes/siege.tscn`, `scripts/siege.gd`): SWITCHED OFF for now at Henrik's
  request (`GameState.SIEGE_ENABLED`). Raiders who reach the castle are simply gone and nothing
  is taken. When on, it starts when raiders reach the castle. A 3D fight built from the castle's part levels (boxes for now).
  Archers on towers, walls and the watchtower shoot automatically; raiders break the palisade, then
  the gate. Survive 5 waves to win the raid. Without the button the raid resolves as before (number check).
  Dev key F7 starts a siege at any time.
- Next for the siege: something for the player to do during it, enemy variety, real 3D models,
  then tie it into passing the crown
- Seeing the game: `tests/screenshot.gd` opens the game window, plays a build and saves real
  screenshots at steps through it (plans inside the file; `--plan=<name> --out=<folder>`), then
  closes the window. Henrik allows this window when it helps; always let it close. Use it after
  any change to how building or peasants look. `tests/snapshot.gd` does a rougher version headless.
- Tests: `tests/test_build.gd` (builds every part and checks no builder is ever in the air),
  `tests/test_raid.gd` (a defended and an undefended raid) and `tests/test_sawmill.gd`. Run with
  `godot --headless --path . -s tests/<name>.gd -- --save=user://test_save.json`.
- Testing: run Godot with `--headless` and `-- --save=user://test_save.json` so tests
  open no window and never touch the real save (`user://save.json`). After changing
  `game_state.gd`, run the game once headless first: a parse error there makes test scripts hang.
