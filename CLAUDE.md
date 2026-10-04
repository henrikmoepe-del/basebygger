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

## Current status
- Stage: Milestone 1 (2D incremental builder), expanding the builder before the 3D part. Placeholder art.
- The player never clicks to gather. Peasants do all the work; the player hires them, gives
  them jobs, trains them, points at the world to build, and buys skills.
- World layout: the castle is in the middle (x = 0). Defence is to the west, where raiders come
  from (palisade, watchtower). The stockhouse, quarry, grove, wilds, mine and village are to the east.
- Done:
  - Start with 3 generalist peasants. Jobs: chop wood, mine stone, find food, build, cook,
    stand guard (needs a garrison), mine iron (needs a mine), tend the grove (needs the Foresters skill)
  - Trades: big skill-tree unlocks that let peasants in a job be trained (twice as good, wear a hat)
  - Castle: eight parts (walls, towers, gate, keep, garrison, court, palisade, watchtower);
    a castle rank caps levels; castle levels 4+ need iron. Village: houses, well, tavern, quarry, mine
  - Stone comes from a quarry site that refills over time (faster with Quarry levels)
  - Cows (Cattle skill) wait with carts at gathering sites and haul loads home
  - Hover to build: point at a part or a signpost for a card (cost, benefit, drawback), click to order
  - Building: builders haul materials from the stockhouse and hammer them in; scaffolding and rope hoist
  - Skill tree: a pannable node map with four arms, levels per skill, hidden "?" nodes; paid with renown
  - Day and night, food and hunger, trees that run out and regrow, raids every 3 days
  - Pass the crown (prestige) with lasting legacy; save/load with offline progress; New game
  - Camera: drag or A/D to pan, mouse wheel to zoom out
  - Dev shortcuts (editor runs only): F2 speed, F3 skip 10 min, F4 resources, F6 peasants, F1 hide
- Henrik's list from the last round is built. Wanted later: more minerals than iron, better food
  from trained cooks, buildings only trained builders can raise, individual peasant traits
- Known balance issues: food and iron pile up late (cows make hunting very effective; iron costs
  are low); the grove draws as one green block when full
- Design notes:
  - Castle parts and soldiers are defences. `GameState.total_defence()` and the part levels are
    what the later 3D wave defence will read; raids are the 2D stand-in for it.
  - Data lives in `scripts/*_data.gd` (castle parts and village buildings, jobs, skills); adding
    an entry there is usually all it takes to get new content on screen.
  - Everything built should have a benefit and, where it makes sense, a real drawback
    (see the drawback constants in `castle_data.gd`).
  - Henrik's design ideas are starting points: explore and expand on them, then explain the choices.
- Then Milestone 2: 3D wave defence, which would replace raids and tie into passing the crown
- Testing: run Godot with `--headless` and `-- --save=user://test_save.json` so tests
  open no window and never touch the real save (`user://save.json`). After changing
  `game_state.gd`, run the game once headless first: a parse error there makes test scripts hang.
