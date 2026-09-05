# Basic unit sprites — 2026-09-05

Original generated raster artwork for the current Medieval Economy RTS prototype.
Created with the built-in imagegen tool; no original Knights and Merchants
artwork was used or imported.

## Assets and scope

- `civilians-basic-v1.png` — 15 civilian roles, five columns by three rows.
- `military-basic-v1.png` — 14 military roles, five columns by three rows; bottom-right cell intentionally empty.

Both source sheets retain their original transparent alpha. The import locates
empty row gutters near the nominal grid so long spear tips stay with their
owner. The source PNG files are not painted over, cut apart or re-encoded. The game takes one
trimmed atlas region per role and anchors its feet to the relief surface. Simple
horizontal facing and a subtle movement treatment are presentation only;
simulation, pathfinding, production and saved games are unchanged.

This is a basic one-pose-per-role art pass, not a finished directional walking,
working, fighting or death-animation set. Those can replace the atlas regions
later without rewriting the simulation. Weapons, hats and clothing prioritize
recognition at small in-game size.

The runtime maps every current civilian and soldier catalog ID to its own
sprite. Carrying and hunger indicators remain dynamic, not baked into the art.

## Source prompts

### Civilian sheet

```text
Use case: stylized-concept.
Asset type: ONE production-ready 2D character sprite atlas for a medieval economy strategy game.
Create a clean, BASIC, low-detail sprite sheet on a genuinely transparent RGBA background. This is game sprite artwork, NOT a concept-art poster, NOT a scene.
Layout: exactly 5 equal columns and 3 equal rows across the entire canvas, exactly one character centered per occupied cell, row-major order described below. Prefer 1536x1024 landscape canvas. All cells have generous transparent gutters. Full bodies and all tools visible, no crossing cell boundaries. No labels, letters, numbers, frames, grid lines, ground planes, decorations, scenery, shadows, watermark or checkerboard drawn into the image.
Style: charming small hand-painted medieval RTS sprites, simplified chunky silhouettes, about 3.5 heads tall, broad flat color shapes with only 2-3 shading tones per material, a subtle dark outline for readability at 32 pixels tall. A single simple three-quarter standing pose facing diagonally toward the viewer's RIGHT (southeast), camera looking down about 35 degrees. Head, tunic, arms, distinct two legs and boots. No facial detail except a tiny nose/shadow. Not photorealistic, not ornate, not highly detailed. Soft consistent upper-left lighting. All humans use the same body scale, the same view and comparable head-to-foot height. Boots on a consistent baseline near 85% of each cell height, centered horizontally. Everything isolated in true transparent alpha.
Each profession or troop should be visually clear through clothing and one tool, but keep everything basic and original. No copied game characters.
Sheet content in EXACT row-major order (5 figures each row; total 15):
Row 1:
1 Lumberjack: ochre yellow tunic, short brown hair, brown boots, simple iron axe held low beside body.
2 Carrier: muted sky-blue tunic, small blue cloth cap, brown belt and boots, empty hands ready to carry cargo, NO permanent crate or sack.
3 Gardener / forester: green hood and green tunic, short spade held low and a very small leafy sprig tucked in belt.
4 Farmer: mustard tunic, broad pale straw hat, small hand sickle held near hip, brown boots.
5 Baker: cream tunic and white apron, soft round white medieval baker cap (NOT tall chef hat), short wooden bread paddle held low.
Row 2:
6 Stonemason: pale gray work tunic, gray cap, brown leather apron, short mallet.
7 Miner: dark slate hood and tunic, short iron pickaxe on one side (no modern hardhat, no electric lamp).
8 Metallurgist: terracotta/rust tunic, brown leather apron, short black metal tongs held low.
9 Smith: charcoal tunic, darker heavy leather apron, bare arms, small forging hammer.
10 Butcher: dusty rose sleeves, clean cream apron, small broad cleaver held safely low, no blood.
Row 3:
11 Animal breeder: olive-brown tunic, brown cap, small feed pouch on belt, empty hands.
12 Fisherman: muted teal tunic and rolled sleeves, soft cream cap, small folded tan fishing net held by side (NO long fishing rod).
13 Carpenter: warm tan tunic, brown leather apron, small handsaw held low beside body.
14 Builder: sand/beige tunic, pale linen cap, tool belt, small trowel held low.
15 Recruit / watchman: muted burgundy padded tunic, simple dull iron cap, brown boots, NO weapon, empty hands.
Check: all FIFTEEN distinct figures, only one figure per cell, no missing or repeated cell, EXACT 5-column/3-row arrangement. Large empty alpha margins.
```

### Military sheet

```text
Use case: stylized-concept.
Asset type: ONE production-ready 2D character sprite atlas for a medieval economy strategy game.
Create a clean, BASIC, low-detail sprite sheet on a genuinely transparent RGBA background. This is game sprite artwork, NOT a concept-art poster, NOT a scene.
Layout: exactly 5 equal columns and 3 equal rows across the entire canvas, exactly one character centered per occupied cell, row-major order described below. Prefer 1536x1024 landscape canvas. All cells have generous transparent gutters. Full bodies and all tools visible, no crossing cell boundaries. No labels, letters, numbers, frames, grid lines, ground planes, decorations, scenery, shadows, watermark or checkerboard drawn into the image.
Style: charming small hand-painted medieval RTS sprites, simplified chunky silhouettes, about 3.5 heads tall, broad flat color shapes with only 2-3 shading tones per material, a subtle dark outline for readability at 32 pixels tall. A single simple three-quarter standing pose facing diagonally toward the viewer's RIGHT (southeast), camera looking down about 35 degrees. Head, tunic, arms, distinct two legs and boots. No facial detail except a tiny nose/shadow. Not photorealistic, not ornate, not highly detailed. Soft consistent upper-left lighting. All humans use the same body scale, the same view and comparable head-to-foot height. Boots on a consistent baseline near 85% of each cell height, centered horizontally. Everything isolated in true transparent alpha.
Each profession or troop should be visually clear through clothing and one tool, but keep everything basic and original. No copied game characters.
Sheet content in EXACT row-major order:
Row 1 (5 soldiers):
1 Militia: dusty red simple peasant tunic, no armour, simple hand axe.
2 Axe fighter: reddish-brown leather armour, small round wooden shield, short iron axe, soft brown cap.
3 Sword fighter: simple gray iron breastplate and open helmet, muted red cloth accent, gray iron shield and short sword.
4 Bowman: brown leather vest over muted red sleeves, simple short wooden bow held upright close beside body.
5 Crossbowman: simple iron helmet and gray breastplate over red sleeves, compact wooden crossbow across waist.
Row 2 (5):
6 Lance carrier: brown leather vest, red tunic, a short simple wooden spear held upright close to body, spear only slightly above head.
7 Pikeman: gray iron armour and open helmet, red tunic, upright steel-tipped pike close to body, pike only slightly above head.
8 Scout: ONE mounted scout sitting on a small brown horse; simple brown leather armour, red scarf, wooden shield and small axe. Full horse and rider, same isometric view, no extra separate soldier.
9 Knight: ONE mounted knight on a small dark gray horse; simple iron armour and open helmet, muted red surcoat, iron shield and short sword. Full horse and rider. No elaborate horse armour or plume.
10 Rebel: moss-brown rough peasant clothing, red headband, simple wooden pitchfork held close to body.
Row 3 (4 soldiers then a fully empty cell):
11 Rogue: dark green hood and brown vest, small short bow, no mask or glowing effects.
12 Vagabond: ONE lightly equipped mounted traveler on a small tan horse, ochre cloak, simple short spear, no heavy armour.
13 Barbarian: stocky bare-armed adult, dark brown fur vest, burgundy trousers, short heavy axe, no horned helmet.
14 Warrior: stocky adult in simple dark leather/iron cuirass, muted burgundy cloth, round shield and short heavy sword.
15 EMPTY transparent cell. Do not put anything here.
Check: EXACTLY fourteen troop sprites, THREE of them mounted (scout, knight, vagabond), one whole mounted unit fits inside its own cell; final bottom-right cell blank. Exact 5 columns and 3 rows. No labels or drawn backgrounds.
```
