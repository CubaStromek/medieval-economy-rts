# Dřevorubecká chata — záznam obrazové výroby

Datum: 2026-09-09. Nástroj: **vestavěný imagegen**, nikoli CLI/API fallback.
Záznam se vztahuje na [koncept v3](../concepts/lumber-hut-v3.png), ne herní sprite.
Finální PNG je RGB na světlém pozadí, bez alfa kanálu. Všechny výstupy byly
pouze zkopírovány beze změny; žádné ruční pixelové úpravy ani výřez.
Model není identifikován odpovědí nástroje; neuvádíme odhadovanou verzi.

## Reference a historie

První vstup byl vlastní herní snímek [V1 ekonomické mapy](../../previews/painted-v1-economy.jpg).
Čelní výklad zadání byl následně uživatelem opraven. V2 přidala levý bok
a prázdné stavové zóny, ale stále měla příliš nízký pohled.
Při revizi v3 byl přímo v prohlížeči prohlédnut původní
[KaM woodcutter](https://www.knightsandmerchants.net/application/files/7315/6823/6438/woodcutters.png)
z [přehledu budov](https://www.knightsandmerchants.net/information/buildings).
Snímek prohlížeče s touto 112×95 referencí byl skutečně přiložen k vyšší
kamerové revizi spolu s vlastním čistým V2 obrázkem (dvě poslední konverzační
obrazové položky). Reference byla určena pouze pro pohled; nesmí se vydávat
za naši grafiku a není přibalena mezi vlastními assety projektu.
Žádný přesný numerický úhel KaM kamery nebyl změřen.

Finální lokální oprava odstranila špalek z budoucího zásobového prostoru.
Žádné zboží, stavový znak, animace ani samostatné vrstvy zatím vyrobeny nebyly.

## Krok 1

Výstup: [lumber-hut-v1-frontal.png](../sources/lumber-hut-v1-frontal.png).
Rozměry: 1254 × 1254; PNG color type 2 (RGB, bez alfy).
SHA256: `51567e0652d6a1d19eed2c5a71e7320396db06604f22ed4c09f800535efcf22f`.
Vstup: vlastní herní screenshot V1.

```text
Use case: stylized-concept
Asset type: one original transparent-background production building sprite for our Medieval Economy RTS, style manual v0.1, an unapproved calibration pilot.
Input image 1 is ONLY our actual game's ground projection, terrain palette and human-scale guide. It is NOT artwork to copy and NOT an edit target. The brown hut immediately left of the green hut in the second row shows the existing lumberjack footprint. Do not reproduce the screenshot, UI, grid, people, other buildings or environment.

Create a single original woodcutter's workshop/hut, a hand-painted medieval craft settlement on a wooded frontier. Warm irregular local stone, practical heavy timber framing, broad weathered plank walls with one small cream clay infill, matte grey-brown wooden shingles, restrained earth colors, modest believable repairs. Inspired by the clarity and intimate atmosphere of classic medieval strategy games, but invent the architecture and arrangement. Not a trace, recolor or upscale of Knights and Merchants.

Projection is CRITICAL: the supplied game looks down from the SOUTH over an axis-aligned square ground grid. FRONT wall baseline and roof ridge are exactly horizontal. Vertical posts are screen-vertical. Receding ground edges point straight UP the image, not diagonally. Show the roof prominently and south wall below it. NO visible east or west side wall; NO rotated diamond isometry, no three-quarter camera, no vanishing-point perspective. Match the supplied viewing direction.

Original composition: a broad low OPEN WOODWORKING SHED occupying the left half, adjoining a taller enclosed one-room hut on the right. Distinct stepped roof heights, practical diagonal timber braces. A clearly legible empty wooden sawhorse under the open left shed is the main work cue, with a permanent chopping stump and one axe rack as small secondary cues. Do not include inventory piles or changing stocks. A simple wide doorway is on the RIGHT of the south/front facade, at five-sixths of the total ground footprint width. Door is dark, plainly visible and has a warm stone threshold; approach completely clear. One small shuttered window in the closed hut. A subtly replaced plank gives character. No green roof, flags, nursery plants or elaborate ornaments.

Ground registration: total footprint 3 columns by 2 rows of square ground cells, 120 x 80 world pixels. At a nominal 4x source scale this ground spans 480 x 320 pixels, NOT the entire building image. Doorway roughly 35 world pixels high, roof and wall proportions consistent with a 33-world-pixel adult in the supplied image. Small sensible eave overhang only. Keep all ground-contact fixtures inside the footprint. Return the building complete, uncropped, centered with clear padding. A square 1024 x 1024 canvas is suitable; actual delivered dimensions/pivot will be measured afterward.

Readable large silhouette and material shapes first, few crafted details second. Painterly edges, moderate contrast, subtle wood grain, NOT noisy microscopic lines, not glossy mobile-game 3D, not photorealistic or thick black-outlined cartoon. Neutral soft volume shading and restrained local occlusion, NO long cast shadow or dramatic directional highlights.
REAL transparent alpha background. No ground plane, grass island, scenery, trees, people, animals, smoke, UI, lettering, watermark, frame or fake transparency checkerboard. One single building, no alternatives or contact sheet. Preserve transparency in the output.
```

## Krok 2

Výstup: [lumber-hut-v2-checker.png](../sources/lumber-hut-v2-checker.png).
Rozměry: 1254 × 1254; PNG color type 2 (RGB, bez alfy).
SHA256: `875189ba37aedb28a6780b774706128259631a539ca79bd331b97f1e04054fc2`.
Vstup: vlastní obrázek předchozího kroku.

```text
Use case: precise-object-edit
Asset type: revised building artwork / unapproved game-art concept, Medieval Economy RTS style guide v0.2.
Input image 1: EDIT TARGET — our own previously generated woodcutter workshop. Keep this same recognizable building and painted material treatment, but correct the viewpoint and prepare physically clear places for future state-driven overlays.

Primary change: re-render the building from an ELEVATED FRONT-LEFT parallel / mildly isometric viewpoint. Camera is slightly to the building's left, not looking straight at its facade. See its roof, its dominant front facade and a modest visible LEFT end/side. Front is still dominant, side about one-fifth of the visual mass. Gentle oblique receding edges, no symmetrical 45-degree diamond presentation, no wide-angle or vanishing-point distortion. This must be a genuinely rotated spatial reconstruction of the building, NOT a skew or flat rotation of the old frontal image. Clearly expose the left side and roof depth.

Preserve: original identity of low broad open timber working shed on the LEFT adjoining a taller enclosed hut on the RIGHT, stepped roof heights, grey-brown matte shingle roofs, warm irregular stone footings, practical broad beams and braces, weathered brown planks with small cream plaster infill, little stone chimney, right-hand front entrance, one shuttered window. Retain the distinct original design rather than copying an existing KaM building. Intimate hand-painted medieval craft settlement, not photorealistic, glossy 3D or plastic cartoon. Clear large forms, moderate detail, restrained earthy palette, softer painted edge treatment.

Future-state-aware layout:
1. Reserve a prominently visible EMPTY LOW LOG STORAGE CRADLE in the left/front part of the shed, with two sturdy timber runners and low retaining end supports. It is part of the building infrastructure and should visibly look ready to hold removable logs. Keep its EMPTY loading volume broad, readable and unobstructed, so stacked log sprites can later be added on a separate layer. Do NOT paint any stored logs, pile, count, numeral, ghost logs or labels into this base artwork. Put the permanent sawhorse a little farther back/right under the working shed so it does not occupy or conceal the log bay. Retain one chopping stump as a permanent tool fixture, not inventory.
2. Beside the right-hand main entrance, provide a small clean EMPTY mounting bracket for a later removable worker-presence marker; no permanently lit lamp, colored active state, person, silhouette, number or icon. The doorway and approach must remain visually open and unobstructed. Make the doorway adult-sized.
3. Keep an uncluttered strip above the roof for future screen-space quantity/status UI, but DO NOT draw any UI in the picture. Inventory and presence are separate future dynamic layers, not static art.

Composition: one complete isolated building, no clipping, comfortable padding. Base building only, empty-storage and no-presence-marker neutral state. No terrain or grass island, no floor backdrop outside the hut, people, smoke, banner, text, watermark, diagrams, arrows or multiple variants. Request a genuine transparent alpha background. REMOVE the source image's fake checkerboard completely, including holes between posts and fixtures. Never draw another checkerboard: if genuine alpha is unavailable, use a perfectly plain solid warm-white background instead and keep clean edges.
Lighting: neutral soft diffuse volume shading, modest local contact occlusion; no long cast shadow, no dramatic sunlight, sunset grading or colored night light.
Output one polished square artwork. This is an art-direction revision for review; pixel registration and game integration will be checked separately.
```

## Krok 3

Výstup: [lumber-hut-v2-clean.png](../sources/lumber-hut-v2-clean.png).
Rozměry: 1254 × 1254; PNG color type 2 (RGB, bez alfy).
SHA256: `d3cde2bc87190ca93e74f5703ab92256c9efeed4461174f22dceec39017bece7`.
Vstup: vlastní obrázek předchozího kroku.

```text
Use case: precise-object-edit.
Image 1 is the edit target. Change ONLY the background of this exact woodcutter building concept to perfectly plain solid warm white (#F7F5F0). REMOVE ALL grey-and-white checkerboard squares, including between legs/posts and around the empty log cradle. The squares are an unwanted printed pattern, not transparency. Do not draw any checkerboard whatsoever.
Preserve the exact elevated front-LEFT viewpoint, modest visible left side, roof angle, building proportions, stepped roofs, painted wood/stone materials and colors, sawhorse, chopping stump, axe rack, EMPTY left-front log cradle, EMPTY mounting bracket at the right doorway, the doorway and all details. No added stored logs, no people, no numbers, labels, UI, symbols, activity lights, ground or landscape. Same square canvas and subject composition, complete building unclipped. No redesign and no added shadows. This is a clean visual concept for review on a flat neutral background, not a request for a fake transparency preview.
```

## Krok 4

Výstup: [lumber-hut-v3-before-clearance.png](../sources/lumber-hut-v3-before-clearance.png).
Rozměry: 1254 × 1254; PNG color type 2 (RGB, bez alfy).
SHA256: `09a314cce10960b840c17f3d0873819e8b645c171a4a6a2127ca75f15a984e75`.
Vstupy: vlastní V2-clean a prohlédnutý snímek původní KaM chaty.

```text
Use case: precise-object-edit
Two images: Image 1 is the EDIT TARGET, our own modern woodcutter workshop on a warm-white background. Image 2 is ONLY a CAMERA REFERENCE: the original Knights and Merchants woodcutter sprite, the small green-roofed hut centered in the browser screenshot. Ignore its surrounding black browser background. Use that original ONLY to understand its higher viewing elevation and oblique direction; do NOT copy its log-cabin architecture, green roof, flag, people, pixels or palette.

Reconstruct OUR building in image 1 from a noticeably HIGHER elevated front-LEFT parallel camera, matching the high-angle game-sprite feeling of the original in image 2. The current target still resembles a frontage illustration; correct that. Look DOWN onto the roof and the working/storage surfaces. Show significantly more roof DEPTH and the upper surfaces of the sawhorse, stump, storage runners, and threshold; shorten the screen-height of vertical front walls naturally through elevation. Keep a modest but clear left end/side visible. The front eaves should recede gently upwards toward the right instead of being almost horizontal. Avoid eye-level elevation and avoid merely stretching the roof, skewing the picture, or flattening the front facade. It must be the SAME building reconstructed at a higher camera angle, no vanishing-point perspective.

Preserve its recognizable own architecture and material identity: low broad open working shed LEFT, adjoining taller enclosed timber hut RIGHT with modest stone chimney, stepped matte grey-brown shingle roofs, warm irregular stone footing, wood braces/planks and cream plaster patch, right-hand main doorway, shuttered window. Hand-painted medieval wooded-frontier craftsmanship, restrained earthy colors, medium detail and clean softened painted edges; not green-roofed original KaM hut, not a flat cartoon, not glossy 3D.

Preserve the future-state-ready layout: EMPTY log-storage cradle visibly placed at left/front under the edge of the shed, EMPTY volume exposed to the higher camera for later removable log overlays. Keep the permanent sawhorse behind/right of that storage bay, one permanent chopping stump and axe rack. Do not put stored logs in the base art. Keep right main threshold and approach free; preserve empty small wall-mounted bracket beside the doorway for future presence indicator. No worker, occupancy icon, glowing lamp, smoke, number, text or status UI. Roof must not completely hide the stock bay; slightly forward open loading space is allowed while keeping it part of this compact building.

Composition: one complete isolated building on a perfectly plain solid warm-white background (#F7F5F0), ample margin, same painterly palette, NO checkerboard, no terrain or grass island, landscape, labels, arrows, split views, watermarks. Neutral soft shading, no long directional cast shadow. Deliver one higher-viewpoint concept only.
```

## Krok 5

Výstup: [lumber-hut-v3.png](../concepts/lumber-hut-v3.png).
Rozměry: 1254 × 1254; PNG color type 2 (RGB, bez alfy).
SHA256: `35c287bf83ceaeb905a20939c736a765392e9434a348696df325df659194674b`.
Vstup: vlastní obrázek předchozího kroku.

```text
Use case: precise-object-edit.
Image 1 edit target is our final elevated front-left woodcutter hut concept. Make one local edit ONLY: REMOVE the tree-stump chopping block and its embedded axe from the interior/back-left of the EMPTY LOG STORAGE CRADLE at the bottom-left/front of the building. That removable-looking vertical stump obstructs the future stock slots. Cleanly reconstruct the empty plank runners/floor behind where it stood. The full log bay must be visibly EMPTY and ready to receive dynamic log sprites.
Keep everything else unchanged: the now-correct higher elevated front-LEFT camera, roof depth, relative left-side/front visibility, entire building shape and position, ALL stone foundations and structural timber posts (do not remove a structural post), sawhorse behind the bay, axe rack at back wall, right-hand doorway, blank indicator bracket, earthy painted materials, neutral lighting and plain warm-white background. No new objects, logs, people, text, labels, icons, checkerboard or markings. Preserve image composition and dimensions.
```
