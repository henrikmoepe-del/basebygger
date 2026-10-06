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

A smaller first step for the main game: keep the line of ground, and bring in
only people-with-priorities, free will and orders (1, 2, 4, 5).
