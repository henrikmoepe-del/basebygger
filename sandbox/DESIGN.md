# The job system in the sandbox: why it works this way

Henrik's brief (2026-10-06): peasants keep jobs they do by themselves, but the
player can take more control: click someone and send them to help in a raid,
fetch a resource, chop a tree, put out a fire. "Think RimWorld, but with
assigned jobs." This note explains the choices made, and what is still open.

## 1. Jobs are presets, priorities do the work

RimWorld has no jobs, only a grid of work priorities per colonist. That is very
flexible but a lot to manage, and it hides who *is* what. The old main game has
the opposite: a job is all a peasant can do.

The sandbox does both: **a job is a preset of priorities**. Making someone a
Builder sets Fires 1, Rescue 1, Build 1, Haul 3. Most players only ever pick
jobs; someone who wants more opens the Work overview and changes single cells
(a builder who also mines when there is nothing to build: Mine 2).

- The job still shows in the silhouette (art direction: "read the job from the
  silhouette"): apron, axe, pick, straw hat, helmet and spear.
- Emergency work (Fires, Rescue) is priority 1 in every civilian job, so
  everyone helps without being told; Guards are the ones who fight.

## 2. Free will: the same rule as RimWorld

A peasant left alone takes the lowest number first; among work with the same
number, the column further left in the Work grid comes first (Fires, Fight,
Rescue, Build, Chop, Mine, Food, Craft, Haul); then the best target, mostly the
nearest. Before that rule, a log lying nearby beat a hurt friend far away
(a real bug found by the tests), which is why the column order matters.

On top of the priorities:
- **Fleeing:** anyone with Fight "never" runs from raiders who come close.
- **Needs:** hunger and tiredness interrupt work past a mark; at night everyone
  sleeps unless the Night work policy is on.
- **Spreading out:** builders prefer a site with fewer builders on it, and only
  so many may pick one tree, rock, bush or fire by themselves.
- **No pile-ups:** a gatherer stops where 4 loose things already lie, so they
  turn to hauling (found by the long test run: 100+ logs lay on the ground).

## 3. Orders come first, and end by themselves

Right-clicking gives an order that beats everything, even fleeing and needs
(RimWorld does the same for drafted colonists; the player is responsible).
An order ends when its work is done (the tree is gone, the fire is out, the
raider is beaten, the building is finished); then the peasant goes back to free
will. So an order is "do this, then carry on", not "you are now a different
peasant". R releases early; Shift queues more.

Drafting (G) is the other kind of control: no work at all, stand where told and
fight what comes near. It is the right tool for a raid; a single order to fight
one raider is the light tool.

The alarm bell (L) is the third: one button for "everyone inside", without
selecting anyone.

## 4. Several jobs at once means sites, not "the job"

The main game has one build job at a time. The sandbox has many sites, each its
own job, with material lying at each site. That is what lets "3 builders on the
Tower, the rest on the Wall" happen. Urgent sites pull builders first.

## 5. The ground with depth

Peasants have a depth (y on the band) and are drawn in front of what is further
back; nothing is scaled (art direction rule). Long walks keep to the dirt path,
each peasant in a lane, which spreads them out in depth and makes the path mean
something. Buildings stand at the back edge; the hurt lie in front of the Hut.

## Open questions for Henrik

1. **Jobs or priorities in front?** Is the Work overview (W) too much? It could
   be hidden behind a "Details" button, leaving only jobs.
2. **Should orders beat needs?** Now an ordered peasant works on even when
   starving (slower). A first version of breaks is in: mood below 15 makes a
   peasant left to themselves sulk for a while, but orders and drafting still
   come first. RimWorld goes further: a break ignores orders too. Which feels
   right here?
3. **Skills or trades?** Skills grow by doing here. The main game buys trades
   with renown (a trained peasant wears a hat). Both could live together:
   trades unlock a job, skills make a person good at it.
4. **How much depth?** 80 pixels of ground is enough to pass and work side by
   side. Deeper ground would allow fields and pens in front of the castle.
5. **Raids:** with the bell, drafting and orders, raids are something the
   player plays now. Is that the direction (the "raid mechanics are undecided"
   note in CLAUDE.md)?
6. **Bringing it into the main game:** see HOOKUP.md. The smallest useful step
   is people-with-priorities, free will and orders on the existing flat ground.
