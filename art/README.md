Nightfort pixel art guide

Every sprite is 16x16, uses only the Nightfort 32 palette, and is exported as PNG at 1x scale.

Piskel setup (just a reminder for me latur)
1. New Sprite, size 16 x 16.
2. Palettes, Create/Import palette, load art/palette.gpl (or paste the hex list from art/palette.hex).
3. Draw. Pencil tool only, no anti-aliasing, no eraser softness.
4. Export, PNG, Zoom 1x, download. Rename the file exactly as listed below.

grass_top        top face of grass blocks (tinted slightly by the biome in game)
grass_side       side faces of grass blocks: dirt with a grass fringe along the top 3-5 rows
dirt             dirt blocks, underside of grass
stone            natural stone and the core platform
bedrock          world floor
sand             desert surface and sand
snow             snow surface and snow
coal_ore         stone with coal specks
iron_ore         stone with iron specks
wood             placed wood block
plank            placed plank block
stone_brick      placed stone brick block
sandstone        placed sandstone block
iron_block       placed iron block
fortified_brick  placed fortified brick block
workbench_side   workbench block body
workbench_top    workbench tabletop slab and handle
torch_base       torch post at the platform corners

Items (art/items/, transparent background allowed :D)
sword            hotbar, inventory and equipment icon
coal             coal material icon and ground drop
iron             iron material icon and ground drop

Rules
Tiles must tile seamlessly: the left edge continues into the right edge, top into bottom.
Block items (wood, stone, dirt, sand, snow, plank and so on) use their tile as the icon automatically.
To give a block item its own icon, add art/items/<item_id>.png.
Missing files fall back to flat placeholder colours, so partial uploads are fine.
Not in this update: Gloom skin, trees, rocks, core, UI frames.
