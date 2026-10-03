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
- Done: click-to-gather, peasants, plantable trees that regrow, save/load with offline progress,
  castle as four upgradable parts (walls, towers, gate, keep) with a castle rank that caps levels,
  builders that haul materials from the stockhouse and hammer them in, scaffolding and rope hoist
- Design notes:
  - Castle parts are defences. `scripts/castle_data.gd` holds each part's defence per level;
    the later 3D wave defence reads the part levels from `GameState`.
  - Henrik's design ideas are starting points: explore and expand on them, then explain the choices.
- Agreed order for what comes next:
  1. Skill tree, first version (about 15 nodes, Peasant and Builder branches, paid with a
     separate currency earned from castle levels); replaces the three upgrade buttons
  2. Trades as big skill-tree unlocks (woodcutter, mason, builder roles)
  3. Day/night and hunger (hunter, cook)
  4. Thirst, boredom, traits: hold until the wave defence prototype exists
  5. Milestone 2: 3D wave defence, which also acts as the prestige loop
- Known balance issue: stone income is about 8x wood late on (rock is endless, trees are capped at 8).
  Trades (step 2) are the planned fix.
- Testing: run Godot with `--headless` and `-- --save=user://test_save.json` so tests
  open no window and never touch the real save (`user://save.json`).
