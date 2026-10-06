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

## Claude's recommendation: what to bring over, in what order

The sandbox grew big on purpose (Henrik: "use your own imagination"), but the
main game should take it a piece at a time, each one played and liked first.

1. **Priorities, free will and orders** (the core). Jobs as presets, the Work
   overview, right-click orders, Release, the order mark. Without depth at first
   (on the main game's flat ground). This is what Henrik asked for, and
   everything else hangs on it. Pause comes with it: orders want a pause.
2. **Several building sites at once**, with haulers bringing material. This is
   the biggest change in the main game (one build job today), but it is what
   lets "3 builders on the Tower, the rest on the Wall" happen.
3. **Emergencies as work:** fires put out with buckets, the hurt rescued to
   beds. They make the priority columns matter (Fires and Rescue first).
4. **Needs and mood per person,** replacing village-wide happiness, with the
   card to read them. Strikes and sulking come from this.
5. **The ground with depth,** when the art for it is ready (it touches walking,
   stairs and every building's position).

Lower priority, or try again later:
- *Drafting and the bell* depend on how raids end up (undecided).
- *Skills* overlap with the main game's trades; decide on one (DESIGN question 3).
- *The many events* (werewolves, traitor, storms, the hooded man...) are content:
  each is small on its own, and the main game's event system can take them one
  at a time once the people are in charge.

What I would not bring over as it is: the sandbox's simple "carry a block, set
it" building (the main game's building is far richer), and its numbers (nothing
is balanced).

## Henrik's feedback after playing it (2026-10-06, his words, unedited)

> 1. I like this, but I do not like the exact copy of the Rimworld priority system. I believe their priorities should be incorportated in what their job is, for example, a builder will always want to build unless ordered to do something else, a drunk cook will want to cook or drink alcohol, but can haul if you force him. If theres something like a fire, people will want to take it out, no matter their job (so in life and death situations people abandon their job, unless you press a toggle that forces them to do their job until death). There should be an option to have everyone of a certain job to always perform their job in certain emergencies, like builders will always build even if theres a raid. Then if you force someone to do something that isnt their job, they can do it but worse, so it is more like a last resort type of thing/not ideal. I am still not sure how you decide peoples job. Perhaps when kids are grown, you can choose what their job would be, people who join your colony in events etc can have certain jobs already, or they can be a good at 3 things, and you decide which one of those things you want them to become.
> 2. Several buildings at once is good, but there should be a priority system for this. Two buildings can have the same priority, and then people will work at both at them at the same time.
> 3. Emergencies are good and should be there as parts of events. See (1) for more info about behavior (people can abandon their jobs in certain situations unless you have forced them to always do their job.
> 4. I dont like detailed needs and moods for specific persons, as there will be a lot of peasents. It can perhaps be simpler ("happy because of x", "sad because of y"), and it can often reflect a job type as a whole, or the whole village as a whole, unless something specific has happened to that one person (sad because of wifes death). Most of the village can be angry because of lack of food, or afraid because of a storm.
> 5. Good, I think I will want this in the main game. However, buildings, expect the castle, should be able to be placed depth wise, so perhaps one building over the road, and one under, then certain smaller buildings such as flower beds can be placed over the road but under the building.

## Plan for step 1: jobs first (not started, waiting for Henrik's OK)

Done in the sandbox first, so Henrik can play it before anything goes into the
main game. It replaces the RimWorld priority grid (point 1 above).

**How a peasant chooses what to do, in this order:**
1. **An order** from the player. Always obeyed.
2. **An emergency**, if their job is set to help with that kind (see below).
3. **Their own job's work.** A builder builds, a woodcutter chops, a cook
   cooks. Each job also carries its own goods: a woodcutter takes logs home,
   a builder fetches material for the site.
4. **Nothing to do for their job:** rest, chat or stroll near their work. They
   never take up another job's work by themselves.

**Work that isn't their job** is only done when ordered, at half speed, and
it doesn't train their skill. The card and the order line say "not their job".
That makes it a last resort, as Henrik asked.

**Emergencies.** The Work overview (W) becomes an **Emergency rules** table:
one row per job, one column per emergency (Fire, Raid, Hurt, Cave-in). Each
cell is either **Help** (the default; for a raid it means hide or fight) or
**Keep working** (stay at the job no matter what, e.g. builders build through a
raid). One click on a job's name sets the whole row. Emergencies keep coming
from events, as now.

**Removed:** the priority numbers 1-3 and the Fight/Rescue/Haul columns. The
Hauler job stays, as a job whose work is carrying.

**Not in step 1** (later steps, so this one stays small):
- How jobs are chosen (a grown child picks one, newcomers bring one, "good at
  3 things"). For now jobs are changed as today (keys 1-8, the card).
- Site priorities (point 2), simpler mood (point 4), buildings placed in depth
  (point 5). Each is a step of its own.
- Traits that pull away from work (the drunk cook).

**Question for Henrik:** when a builder has no site, should they rest (the plan
above), or help the haulers carry? Resting is closer to "only their job";
carrying keeps the village busier.

**Tests:** the logic test gets checks for each rule: nobody takes another job's
work unasked; an order off the job works at half speed; a fire pulls everyone
with Help and nobody with Keep working.
