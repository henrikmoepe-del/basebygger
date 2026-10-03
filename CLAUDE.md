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
- The player never clicks to gather. Peasants do all the work; the player hires them,
  assigns them to jobs, orders castle parts and buys skills.
- Done:
  - Jobs: woodcutter, quarryman, hunter, builder, soldier (needs a garrison), forester and cook (skills)
  - Castle: six upgradable parts (walls, towers, gate, keep, garrison, court); a castle rank caps levels
  - Building: builders haul materials from the stockhouse and hammer them in; scaffolding and rope hoist
  - Skill tree: four tabs (Peasants, Builders, Village, Defence), 47 skills, paid with renown
  - Day and night (peasants sleep), food and hunger, trees that run out and regrow
  - Raids every 3 days, checked against the castle's defence; win renown or lose stores
  - Save/load with offline progress, and a New game button
- Design notes:
  - Castle parts and soldiers are defences. `GameState.total_defence()` and the part levels are
    what the later 3D wave defence will read; raids are the 2D stand-in for it.
  - Data lives in `scripts/*_data.gd` (castle parts, jobs, skills); adding an entry there is
    usually all it takes to get new content on screen.
  - Henrik's design ideas are starting points: explore and expand on them, then explain the choices.
- Ideas not built yet: thirst, boredom and peasant traits; houses and other village buildings
  (needs a wider, scrolling world); real pixel art; sound
- Then Milestone 2: 3D wave defence, which also acts as the prestige loop
- Testing: run Godot with `--headless` and `-- --save=user://test_save.json` so tests
  open no window and never touch the real save (`user://save.json`).
