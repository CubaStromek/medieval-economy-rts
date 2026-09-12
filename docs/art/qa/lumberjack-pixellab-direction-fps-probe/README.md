# Godot QA · fps jednotlivých směrů

2026-09-10. **Izolovaný test časování, nikoli nový produkční balík.**
Doplňuje [reader a API](../../briefs/lumberjack-pixellab-v2-godot-reader.md)
a [historický jižní pilot](../lumberjack-pixellab-v2-S-pilot/README.md).
Hlavní hra ani její simulace se nespouštěly a neměnily.

## Předmět, zdroje a registrace

Nové pole `clips.walk_axe.directions.<směr>.fps` přebije klipové `fps`.
Pokud chybí, používá se klipové fps; neplatný přítomný override se odmítá.
Čas zůstává společný v sekundách, počet a pořadí zdrojových fází se nemění.

Probe použil skutečná raw PNG S a W, výslovný výběr 1–24 u obou směrů,
kotvu `(128,205)`, tělo `163→33 px`. Klipová výchozí hodnota je 12 fps,
S má override 10 fps a W 15 fps. Odpovídá to zadané délce dvojkroku
8/10 = 12/15 = 0,8 s, při odlišném počtu opakování ve zdrojových sekvencích.
Celé smyčky mají S 2,4 s a W 1,6 s. Fyzický pohyb jednotky se zde neověřuje.

Packer změnil pouze časová metadata. PNG kopie, atlasová pole a APNG jsou
ověřené proti původním RGBA. [Kontrola packeru](pack-validation.json),
[probe manifest](probe-manifest.json), [rozsah, zdroje a hashe kódu](scope.json).
Probe vznikl v `/private/tmp/pixellab-direction-fps-probe`; jeho balík nebyl
zkopírován do `game/art`. Historický runtime manifest S/12 fps zůstal
bitově shodný s oddělenou kopií jižního pilotu.

## Provedené kontroly

| Kontrola | Skutečný výsledek |
|---|---|
| Import a čtenář | 48/48 skutečných snímků S/W: alfa, atlasový hash, region, pevná registrace, časový index, wrap a klid; [log](frames.log) |
| Časová metadata | 18/18 podmínek: fallback 12, override 10/15, očekávané indexy ve společném čase 0,35 s a 0,8 s, různé konce smyček, chybějící override, odmítnutí 0/−1/text/null/bool/nekonečna, nové platné načtení; [log](checks.log), [test](fps_probe.gd) |
| Ovládání prohlížeče | 8/8 podmínek: přesná pauza společného času, krok podle nejrychlejšího směru, různé správné indexy S/W, stejný explicitní klidový index i při různých fps, návrat do přehrávání; [log](ui-timing.log), [test](ui_timing_probe.gd) |
| Native fallback | Nový prohlížeč načetl starý skutečný S/12 fps pilot a uložil pět nativních PNG do samostatné testovací složky; [manifest](fallback/native-capture-manifest.json) |
| Native override | Nový prohlížeč načetl S/10 a W/15 a uložil pět PNG; každá karta uvádí skutečné fps a snímek ve společném čase; [manifest](override/native-capture-manifest.json) |
| Pozitivní vizuální kontrola | Prohlédnut [fallback při 12 fps](fallback/walk_axe-dark-3x-phase-25.png) a [S10/W15 ve stejném čase](override/walk_axe-dark-3x-phase-25.png). Oba skutečné sprity se vykreslily. |

Nativní prostředí: Godot 4.7.2, Apple M4, OpenGL Compatibility, 1240×880.
Prohlížeč vypíná pouze svůj viewport stretch; 1× odpovídá jednomu world px
na jeden pixel zachyceného obrázku. Manifesty obsahují hashe, skutečné
časové hodnoty a `fps_by_direction`. Vzniklo deset nativních PNG, ale
výslovná vizuální kontrola výše se vztahuje ke dvěma uvedeným snímkům.

## Výsledek a omezení

**Technická změna prošla** na starém i novém formátu metadat. Historická
QA ani její assety se nepřepsaly. Skutečné herní tempo, kontakt s terénem,
mlha, řazení, přechody mezi činnostmi a úplná výtvarná plynulost celé sady
zůstávají neověřené. Tento probe není schválení uživatelem ani výtvarný etalon.
