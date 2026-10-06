# Sandbox: a test map for the new job system

A separate test map, kept apart from the main game: nothing in `scripts/` or
`scenes/` is changed by it. It only borrows the main game's UI look
(`scripts/ui_theme.gd`) and sound effects (`scripts/sfx.gd`).
Open `sandbox/sandbox.tscn` in Godot and press **F6** (Run Current Scene).

Why it exists, the choices behind it and the open questions: `DESIGN.md`.
What it would take to bring it into the main game: `HOOKUP.md`.

## Try this first (about five minutes)

1. Press **Space** to pause. Drag a box around the three builders on the left.
   Right-click the **Wall**: they go there (gold `!`). Space again to unpause.
2. Click **Freya** in the bar of names, then right-click a **log** lying by the
   trees: she hauls it. Shift + right-click a rock and then the ground: queued
   orders (numbered lines).
3. Click **Work**: the Work overview. Click a cell to change a priority, or a job
   to change the job.
4. Press **T** for a raid. Select the builders, press **G** (draft) and
   right-click near the raiders: they stand and fight. Or press **L** (the bell)
   and everyone hides in the castle.
5. Press **F** for a fire and watch the bucket line from the well.
6. Click **Build**, pick a Hut, and place it with a left-click. Left-click the
   site and make it **Urgent**.
7. Click a single peasant and read their **card**: needs, mood and its reasons,
   skills, trait.
8. Click the **Sawmill** and change its bill (keep N planks).
9. Leave it running at **Speed 4x**: night falls and people go to bed, a
   traveller asks to join, a child is born, the hooded man comes on day 3...
10. Point at anything with nobody selected to see what it is.

## The job system (the point of the map)

**Jobs are presets of work priorities.** Every peasant has a priority for each
kind of work: 1 = first, 2, 3 = last, - = never. Giving someone a job sets them;
single cells can be changed in the Work overview.

| Job | Fires | Fight | Rescue | Build | Chop | Mine | Food | Hunt | Craft | Haul |
|---|---|---|---|---|---|---|---|---|---|---|
| Builder | 1 | - | 1 | 1 | - | - | - | - | - | 3 |
| Woodcutter | 1 | - | 1 | - | 1 | - | - | - | - | 3 |
| Miner | 1 | - | 1 | - | - | 1 | - | - | - | 3 |
| Forager | 1 | - | 1 | - | - | - | 1 | - | - | 3 |
| Hunter | 1 | - | 1 | - | - | - | - | 1 | - | 3 |
| Crafter | 1 | - | 1 | - | - | - | - | - | 1 | 3 |
| Hauler | 1 | - | 1 | 3 | - | - | - | - | - | 1 |
| Guard | 2 | 1 | 1 | - | - | - | - | - | - | - |

**Free will.** Left alone, a peasant takes the lowest number first; with the
same number, the column further left first (Fires before Rescue before Build...),
as in RimWorld; then the best target, mostly the nearest. After each piece of
work (a block set, a log chopped) they look around again.
- Builders prefer a site with fewer builders on it, and an urgent one first.
- Only so many pick the same tree, rock, bush or fire by themselves.
- Gatherers stop where 4 or more loose things already lie, and haul instead.
- Anyone with Fight "-" runs from raiders who come near.
- Hungry or tired past a mark, they eat or sleep first.

**Orders** come before all of that. Select peasants and right-click something:
they do it until it is done (the tree is gone, the fire is out, the building is
finished), then go back to free will. Shift + right-click queues orders. R
releases. Orders also work while paused.

**Drafting** (G) is for fighting: no work, stand where sent, fight any raider who
comes near. **The bell** (L) sends everyone who is not a guard, drafted or under
orders inside the castle gate. **Forbidding** (X) keeps everyone off something
unless ordered to it.

**Hauling** is taking loose things to the stockyard (up to 3 of a kind lying
together in one trip) and bringing building material to the sites, where it lies
in a pile for the builders.

**Skills** (Build, Chop, Mine, Food, Hunt, Craft, Fight) grow by doing the work:
level 0 works at 60%, 5 at 100%, 10 at 140%. Shown as "·n" in the Work overview.

## The colony around it

**The ground** is a band 80 pixels deep in front of the castle wall, after the
art direction. Peasants walk along it and towards or away from the viewer;
further forward means lower on the screen and drawn in front (nothing is
scaled). Long walks keep to the dirt path, each peasant in a lane.

**Buildings** (Build menu): Hut (2 beds), Wall, Tower (its top needs planks),
Shed, Sawmill, Flowerbed, Watchtower. A planned building is a faint outline
filled in block by block. Pick a site to make it urgent or cancel it.
- *Sawmill:* click it to set its bill (keep N planks in stock; 0 stops it). The
  Crafter takes logs for up to 3 at once, saws them and carries the planks back.
- *Flowerbed:* a good thought for everyone, "A pretty village" (up to three).
- *Watchtower:* guards wait at its foot; a guard on watch rings the bell when
  raiders or a werewolf come in sight, and gives the all clear after.

**Needs and mood.**
- Hunger and tiredness grow. Peasants eat a basket of food at the stockyard
  and sleep in a free Hut bed (faster) or on the ground.
- At night everyone left to themselves goes to bed. The *Nights* policy (top
  bar) keeps them working instead: 15% slower in the dark, and tiring faster.
- Mood drifts towards 55 plus their thoughts (shown on the card):
  - needs: hungry, tired;
  - states: in pain, drafted, Night work, children made to work;
  - memories that fade: ate a meal, slept in a bed, was hurt, saw someone go
    down, a raid beaten, a feast, dark dreams.

  At 75 and up they work 10% faster. Below 15, someone left to themselves sulks
  for a while (a little dark cloud), then feels better.

**People.**
- *Traits* (as in the main game): Quick and Slow walk faster or slower;
  Hard-working and Lazy work faster or slower.
- *Dozing:* someone working while somewhat tired may nod off by day (z's,
  drooping head). Click them to wake them with a burst of effort.
- *Children:* at dawn, while there are fewer children than finished Huts, a
  couple may have a child. Children follow a parent and grow up after 3 days.
  The *Kids* policy (Child labour) lets them haul and pick berries at half
  pace; the grown-ups mind it.
- *Travellers* ask to join every day and a half: take them in (as a Hauler) or
  send them away.
- *The hurt* are carried by anyone with Rescue to a Hut bed (or the well);
  they get better faster in a bed.

**Food and materials.**
- Berry bushes, picked by the Forager.
- Deer in the wood to the east, hunted by the Hunter. They run from people;
  a kill leaves meat, which the hunter carries home.
- Rocks fill again a while after they are used up; felled trees grow back.

**Trouble**, most of it from Henrik's lists:
- *Raids* on a timetable (day 2 at 17:00, then every 2 days, a raider more
  each time). Raiders steal from the stockyard and carry torches that may set
  a building alight.
- *Fires* knock blocks off until put out with buckets from the well. A fire
  with nothing left to burn dies down.
- *Storms:* rain, slower work, and lightning that may start a fire or bring
  a tree down.
- *Werewolves* on some nights from day 4: tough, fast, after people, gone at
  dawn. Drawn as deep shadow and red (art direction).
- *Cave-ins* bury a miner; anyone with Rescue digs them out.
- *The traitor* (from day 3) secretly steals at night; a guard or someone
  drafted nearby catches them; then banish or forgive.
- *Strikes* when spirits stay low: hold a feast or wait it out.
- *The hooded man* (from day 3) offers a gift; a price comes later.

**Light at night** (art direction): only warm light shows in the dark: fires,
raiders' torches, lanterns at the stockyard and the well, Hut windows, the
Sawmill's lamp. A werewolf glows faintly red.

## Controls

**Selecting**

| Input | What it does |
|---|---|
| Left-click a peasant | Select (Shift adds or removes; a dozing one is woken) |
| Drag with the left button | Select everyone in the box |
| Double-click a peasant | Select everyone with the same job |
| Ctrl+A / Esc | Select everyone / nobody |
| A name in the bar at the top | Select that peasant |

**Orders** (to the selected)

| Input | What it does |
|---|---|
| Right-click a site / tree / rock / bush / deer | Build there / chop / mine / pick / hunt it |
| Right-click a log, stone or basket | Haul it (several selected take one each) |
| Right-click a fire / raider / hurt peasant / rubble | Put it out / fight / rescue / dig out |
| Right-click a finished workshop | Work there |
| Right-click the ground | Go there and hold |
| Shift + right-click | Queue after the orders already given |
| R | Release: back to free will |
| G | Draft / undraft |
| 1-8 | Job: Builder, Woodcutter, Miner, Forager, Hunter, Crafter, Hauler, Guard |

**The village**

| Input | What it does |
|---|---|
| Build | Pick a building, left-click where it goes (Shift-click: several; right-click: stop) |
| Left-click a site | Its progress; Urgent or Cancel; on a workshop, its bill |
| Work | The Work overview |
| Log (J) | The last 30 messages |
| Nights / Kids | The Night work and Child labour policies |
| Bell (L) | The alarm bell |
| X (pointing at something) | Forbid or allow it |
| Point at something | What it is (with nobody selected) |
| Space | Pause (orders can still be given) |
| T / F / Speed | Start a raid / a fire; 1x, 2x, 4x |
| A / D, middle-drag, wheel | Pan, zoom (whole steps: 0.5x, 1x, 2x, 3x) |
| M | Mute |

The gold `!` over a peasant means they have an order; a red shield, that they are
drafted. Selected peasants show a dotted line to what they are working on (gold
for an order, white for free will).

## The look

The people are the figures from the Game_1 Art Direction page's people sheet,
read pixel for pixel from its 8x picture (`tools/people_native.png`;
`tools/gen_sprites.py` makes `sb_sprites.gd`).

| Job | Figure |
|---|---|
| Builder | the grey builder, without the block on the head |
| Woodcutter, Miner | the plain peasant in green and in slate |
| Forager | the straw hat |
| Crafter | the cook |
| Hunter | the archer |
| Guard | the spearman |
| Hauler | the plain peasant |
| Raiders | the raider |
| Children | the child |

- Walking lifts a foot.
- The hurt and the sleeping lie as the same figure on its side.
- Someone carried lies across the carrier's shoulders.
- What they carry and their tools are drawn on top.

## Files

- `sandbox.gd`: the world: the map, finding work, selection and orders, events.
- `sb_data.gd`: work types, jobs, buildings, events' numbers, palette.
- `sb_peasant.gd`: a peasant: priorities, orders, choosing and doing work, needs,
  mood, drawing.
- `sb_thing.gd`: the base for anything that can be worked on or ordered to.
- `sb_site.gd`, `sb_tree.gd`, `sb_rock.gd`, `sb_bush.gd`, `sb_deer.gd`,
  `sb_item.gd`, `sb_fire.gd`, `sb_raider.gd`, `sb_stockyard.gd`, `sb_well.gd`:
  the things in the world.
- `sb_stranger.gd`: the hooded man (looks only).
- `sb_sprites.gd`: the people's pixels (made by `tools/gen_sprites.py`).
- `sb_light.gd`: warm lights for the night.
- `sb_backdrop.gd`: sky, mountains, the castle wall, the ground band and path.
- `sb_hud.gd`: the top bar, the bar of names, the panels, the card, the dialogs.

**Tests and tools** (in `tests/`):
- `run_tests.sh` runs everything and fails on any failed check:
  - it loads the map to catch script errors (one would make a test hang);
  - it runs `test_sandbox.gd`, the logic test;
  - with xvfb, it runs `test_input.gd`, which plays with real mouse and keys.
- `soak.gd` runs the map for days with no player and reports anything that looks
  stuck: `-- --days=3`.
- `perf.gd` times a frame with more peasants: `-- --peasants=80`. On 2026-10-06:
  10 peasants 0.6 ms, 40 peasants 1.3 ms, 80 peasants 2.1 ms (headless).
- `shots.gd` takes screenshots in a real window: `-- --plan=<name> --out=<folder>`
  (the plans are listed at the top of the file).

## Kept simple on purpose

Building here is "carry a block, set it": no scaffolds, ladders, hoists or decks.
That system stays in the main game; this map is about *who works where* and *how
the player steers them*. Nothing is balanced.
