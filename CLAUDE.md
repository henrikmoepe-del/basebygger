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
- Stage: Milestone 1 (2D incremental builder), early prototype with placeholder art
- Done: project setup, click-to-gather (wood, stone), build castle pieces in order,
  hireable peasants that walk and gather automatically
- Design note: castle pieces are defences. Each has a `defence` value in
  `scripts/castle_data.gd`; the later 3D wave defence reads the built castle from `GameState`.
- Next step: trees that peasants plant, which grow over time and are chopped for wood
- After that: builders and upgrades, save/load, then Milestone 2 (3D wave defence)