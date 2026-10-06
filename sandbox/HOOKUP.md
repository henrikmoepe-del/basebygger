# Bringing the sandbox into the main game

What it would take, roughly in order. This is a big rework, not a few lines,
which is why it is tried out on the test map first.

1. **People in charge, not counts.** The main game's job counts
   (`GameState.jobs`, `peasants`, `trained`) would go; each person in
   `GameState.people` gets `job` and `prio` (work -> 1/2/3/0) like
   `sb_peasant.gd`, saved. `_fit_people` goes away. A job is a preset from a
   table like `SbData.JOBS`; the peasants panel sets jobs per person.
2. **One node per person, kept.** Today a worker is made anew when their job
   changes (`worker.gd` subclasses per job). The sandbox has one peasant script
   that can do every kind of work. The main game's job scripts (`builder.gd`,
   gatherers, `crafter.gd`, `soldier.gd`) would become "work givers" + task code
   a person runs, instead of being the person.
3. **Several build jobs at once.** `GameState.job_*` (hauled, formed, lifted,
   taken, placed) is one job. It would become a list of jobs, one per site, each
   with its own `BuildPlan`, yard, benches and hoist; builders claim a job like
   `find_work("build")` does here.
4. **Work givers.** A function per work type that finds the best target for a
   person (`sandbox.gd` `find_work`), with a cap of workers per target when they
   choose by themselves. New work (cook, saw planks, bake, tend the grove,
   stand guard) is one more work type and one more entry in the job presets.
5. **Orders and selection.** Selecting (click, Shift, box, the bar of names),
   right-click orders, Release, and the order mark: `sandbox.gd` input and
   `sb_hud.gd` panel. The main game's build mode keeps left-click; orders would
   use right-click so the two do not clash.
6. **Ground with depth.** The hardest part for the main game: `castle.route`
   and `worker._go_to` assume one line of ground (y = 0) plus floors. The band
   would be added as the ground (x, depth), with floors and stairs still starting
   from the back edge of the band (depth 0) where the buildings stand. Peasants
   need to be y-sorted, and everything that stands on the ground (stockyard,
   trees, sites) gets a depth.
7. **Fire, raids, hauling loose things.** Fires already exist as an event
   (`event_data.gd` "fire"); with this system they become something peasants put
   out by work instead of a click. Raiders that steal and drop loot, and loose
   logs and stones that are hauled, are new.

8. **Things added later in the sandbox, and where they meet the main game:**
   - *Needs (hunger, sleep) and day/night:* the main game already has food, hunger,
     nights and beds in the keep (`Workers.bed_spot`). The sandbox's per-person
     hunger and tiredness, and "Night work" as a policy, would go into
     `GameState.people` and `policy_data.gd` (Henrik's list has "work during the
     night" as a policy idea).
   - *Workshops and bills:* the main game's workshops (`workshop_data.gd`,
     `crafter.gd`) work like this already; a bill ("keep N in stock") would be a
     number per workshop in `GameState`, shown when the workshop is clicked.
   - *Skills:* would sit beside the main game's trades: a trade unlocks a job, a
     skill makes a person good at it (see DESIGN.md, open question 3).
   - *Traits and dozing:* the traits are the main game's (`people_data.gd`);
     dozing is one of Henrik's "small things to click".
   - *Hunting:* the main game has a hunter job and a badger event at the wilds;
     deer would be a new kind of thing there.
   - *Raids:* the alarm bell, drafting and torches are new; the main game's raids
     (`raiders.gd`, `soldier.gd`) have posts, a palisade and archers instead.
     Which way raids go is undecided (CLAUDE.md).
   - *Forbidding, hover info, the character card, the Work overview, pause:* HUD
     and input only.
   - *Events* (travellers, the hooded man, cave-ins, werewolves, strikes, the
     traitor, storms): the main game has an event system (`event_data.gd`,
     `GameState.events`, "effects", "schedule", "needs"). Most of these would be
     entries there; what is new is that they create *work* (dig someone out, put
     a fire out, catch a thief) or *questions* for the player (the sandbox's
     `ask`, a small dialog with buttons), instead of only effects and clicks.
   - *Children and Child labour:* the main game has children and a "Have
     children" policy (`people_data.gd`); Child labour would be one more policy.
   - *Mood:* the main game has village happiness (`GameState.happiness`). The
     sandbox's mood is per person, from thoughts; the two could meet as "the
     village's happiness is the average of its people's moods".
   - *Light at night:* `sb_light.gd` (PointLight2D under a CanvasModulate) would
     work the same way in the main game, which already darkens at night.

A smaller first step for the main game: keep the line of ground, and bring in
only people-with-priorities, free will and orders (1, 2, 4, 5).
