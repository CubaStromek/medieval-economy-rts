# Vlastní reference tesaře — 2026-09-12

`current-carpenter-native.png` je nezměněná oblast role `carpenter` získaná
skutečným `UnitSpriteLibrary` z produkčního vlastního atlasu
`game/art/units/civilians-basic-v1.png`. `current-carpenter-atlas-cell.png`
uchovává celou jeho logickou buňku. `current-carpenter-reference-2x.png`
je pouze 2× nearest-neighbor zvětšení pro obrazovou referenci.

Reprodukovatelné vytažení: [extract-current-carpenter.gd](extract-current-carpenter.gd).
Oblasti, skutečná herní velikost a hashe: [JSON](current-carpenter-extraction.json).
Všechny tři PNG jsou odvozené kopie; atlas nebyl upraven.

Reference byla skutečně prohlédnuta: hnědé vlasy bez čepice a vousů,
okrově krémová košile, hnědá dlouhá zástěra, tmavé kalhoty a hnědé boty.
Stávající ruční pila je identifikace běžné profese; do nové odpočinkové pózy
nepatří. Nový obličej bude čitelný střídmě, starý atlas má rysy zjednodušené.

Technické vlastnosti raw výřezu nejsou vzorem pro novou alfu: 163 × 306 RGBA,
15 113 plně průhledných pixelů, 34 765 částečně průhledných a 0 plně neprůhledných.
RGB pod průhlednými rohy je hnědé. Nový master proto nesmí převzít nahnědlé
okolí či celkovou poloprůhlednost jako výtvarnou vlastnost. Aktuální reference
je pouze pro identitu/kameru; finální alfu nové postavy změřit nezávisle.

Stávající technický exporter dřevorubce používá Sharp. Bundled závislost ověřena
2026-09-12: `/Users/openclaw/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp`.
Lokální `node` ji načte přes `NODE_PATH` nebo `SHARP_PATH`. Není potřeba
instalovat balíček ani přepisovat původní exportery. Pro nový asset vlastní
změřené hranice/klíč a vlastní exportní skript, žádná kopie čísel chaty.

Nové generované zdroje jsou zachované zde: `resting-carpenter-key-master.png`,
`head-left-key.png`, `head-right-key.png`. Přesná zadání, skutečné vstupní
role a hashe: [prompts.json](prompts.json), původní master prompt je také
v nezměněném [center-prompt.txt](center-prompt.txt). Vestavěný imagegen,
model neidentifikovaný nástrojem; žádná placená CLI výroba.

[Technický exporter](export-resting-carpenter.cjs) vyrobil skutečné RGBA,
jedinou registraci celého těla a tři varianty. Produkce je v
`game/art/buildings/sawmill/v1/life/`; [naměřené hodnoty](export-measurements.json)
vedou všechny otisky. Póza má vlastní vlasy y94 a spodní hranu nosné podrážky
y1374; kalibrace1280→165→33worldpx, produkční foot `[133.02734375,205.1171875]`.
Nejde o převzaté souřadnice dřevorubce.

Skutečně prohlédnuté karty: [alfa na třech pozadích](alpha-qa.png),
[hlavy6×](head-qa-6x.png), [33worldpx náhled zvětšený4×](body33px-qa-4x.png).
Levá hlava má jasně nos orientovaný vlevo a odkryté pravé ucho; pravá varianta
více ukazuje levé ucho a nos směřuje dále vpravo. Jde o natočení celé hlavy,
nikoli posun očí či zrcadlení trupu. Nové vlasové horní meze při alfa>25
se liší o1produkčnípixel (0.2worldpx); kořen krku, torso a chodidla se nehýbou.
Tělo pod y79 i boty pod y160 mají0 odlišných RGBA pixelů. U všech tří variant
nezávislý Godot decoder ověřil skutečnou alfu, viditelný trup/podrážku a nulový
zbytek magenty. Běžná hra a finální opora patří do QA pily.

[Brief](../../briefs/carpenter-rest-v1.md) · [QA](../../qa/carpenter-rest-v1/README.md).
