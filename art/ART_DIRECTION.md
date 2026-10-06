# Art direction: "The Castle in Cross-Section"

Concept art: `art/concept/` (PNGs, `_x3` / `_x8` scaled for viewing, layered `.aseprite`
files to edit). It is painted in code by `art/tools/paint_concepts.py`, so it can be repainted
after a change: `python3 art/tools/paint_concepts.py`.

## The idea in one line
A warm, hand-made pixel storybook of a castle cut open like a doll's house, where you can always
see the little people inside working, sleeping and climbing the stairs; seasons, night and raids
change the mood by changing the palette, not the drawings.

## Pillars
1. **The cutaway is the hero.** The keep has no front wall. Rooms are the most detailed and the
   warmest-lit part of the screen; outside walls are plainer and cooler so the eye goes inside.
2. **Every pixel is a world unit.** Art is drawn at the game's own scale, 1 unit = 1 pixel:
   peasants 16 high (children 10), a stone block 24 x 12, a keep storey 48, a room about 104 wide.
   No scaling of single sprites, no rotation, no blur. The camera zooms the whole picture only.
3. **Read the job from the silhouette.** At 16 pixels a face is two pixels, so a peasant's job is
   told by what they carry and wear: a block on the head (builder), a log on the shoulder
   (woodcutter), an apron (cook), a straw hat (trained), a helmet and spear (spearman), a hood and
   bow (archer). Tunic colour backs it up.
4. **Materials you can count.** Stone shows its courses and joints, timber shows its frame,
   thatch shows its rows. A finished level looks like the pieces the builders carried.
5. **One palette, swapped.** 39 colours (`game1_palette.gpl`). Night, winter and raids are palette
   swaps of the same picture: night maps every colour to a darker, bluer one, except in warm,
   dithered pools around flames; winter maps greens to snow and puts snow on everything the sky
   touches. In Godot this is one small palette-swap shader on the world, which also suits
   `season_data.gd` and the day and night cycle.

## Rules
- **Light** comes from the upper left by day: lit edges on the top and left of blocks, darker
  right faces on roofs and mountains. At night, light comes only from fire, candles, windows and
  torches, and it is always warm (fire, gold, light).
- **Outlines:** no black outline around everything. Darkest ink (`ink`) only for eyes, feet,
  doorways, windows and slits. Shapes are told apart by value.
- **Dithering:** a 4 x 4 ordered (Bayer) dither for the sky, haze, light pools and smoke. Never
  noise; never anti-aliasing.
- **Depth:** three bands. Far (mountains and hills, low contrast, blue), middle (the castle, full
  contrast), front (people, trees, the stockyard, the strongest contrast).
- **Colour roles:** stone greys tilt purple; wood is red-brown; the only saturated colours are
  people's clothes, banners, the red of danger (raiders, fire) and gold (light, renown, rewards).
  Gold in the UI means the same thing it means in the world.
- **Interface:** the existing dark wood and parchment theme (`scripts/ui_theme.gd`) fits this
  direction; keep it, and take its colours from this palette over time.
- **Tone:** cosy on the surface, darker underneath. Henrik's later themes (dark gifts, werewolves,
  torture, traitors) arrive as palette and lighting first (reds, deep shadow), not as gore.

## Turning it into the game
The game draws everything in code today (`castle.gd`, `worker.gd`). Two ways forward, smallest first:
1. Move the code-drawn colours to this palette (one `palette.gd`), and add the night/winter swap.
2. Replace the drawn people with sprite sheets made in Aseprite on this palette (16 x 16 frames,
   walk cycle of 4, carry poses), then rooms and furniture as tiles.

## Tools
- **Aseprite** to draw sprites: import `game1_palette.gpl` (Palette > Load), work in Indexed mode,
  export sprite sheets as PNG + JSON; Godot imports them with filtering off.
- The concept `.aseprite` files have layers (sky, far, castle, front) to repaint over.
