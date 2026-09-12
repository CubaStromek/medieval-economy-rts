# Implementace objektu: dřevorubec — PixelLab chůze v1

Datum: **2026-09-10** · ID: `lumberjack` · typ: jednotka.
Stav: **dílčí animační zkouška, neuzavřený S krok; hra nezapojena**.
Podle [implementační šablony](../object-integration-template.md) a
[společného postupu](../object-implementation-workflow.md).
[QA](../qa/lumberjack-pixellab-walk-v1/README.md).

## 1. Zadání a data

Požadována PixelLab chůze v osmi směrech. Uživatel upřesnil jeden vlastní
[pohled S](../animation-references/lumberjack-without-log/S.png) → osm
PixelLab rotací → animace. Identita a původní kontrakty:
[zadání postavy](lumberjack-v1.md),
[chůze bez klády](lumberjack-walk-without-log-kam-v2.md).

Skutečně dodáno osm statických rotací a jediný klip S s devíti snímky.
Ostatní klipy nejsou hotové. S nevrací původní fázi kroku a N statický
pohled nemá viditelnou sekeru. Výstupy ani styl nejsou schváleným etalonem.
[Souborový a produkční záznam](../animations/lumberjack-pixellab-walk-v1/README.md).

## 2. Geometrie a registrace

| Údaj | Skutečnost / důkaz |
|---|---|
| Canvas S | 9 × 128 × 128 px; měřeno v `qa.json` |
| Alfa | Všech 9 snímků obsahuje viditelné i skutečně transparentní pixely; žádný neprůhledný pixel na hraně canvas |
| Tělesné měřítko náhledu | 108 zdrojových px od vrchu čepice po nejnižší botu ve vstupu S → 33 px; jediná společná škála, nezávislá na přesahu sekery |
| Obrazová kotva / trim | Celé původní canvas; žádný ořez ani posuny podle nejnižší boty |
| Mapová kotva, kolize a výšková projekce | Existující herní hodnoty se nemění |
| Fyzická kotva nohou, řazení, stín a UI | Nový atlas není integrován; neověřeno |
| Kontakt se zemí a svahy | Neověřeno; plochý náhled není terénní zkouška |

## 3. Klipy a stavy

Stavební fáze: N/A — jednotka. Skutečná dodávka je chůze S bez klády,
sekera v pravé ruce. API požadavek uvádí 8 snímků, odpověď obsahuje 9
odlišných RGBA obrázků. Uchováno a přehráváno všech 9. Devátý není kopie
prvního. Osm rotací není osm hotových animačních klipů.

Přehrávač nabízí 5/10 fps. Není to schválené herní časování. Pauza,
stop/rozběh a přechod směru v runtime, nesení klády, interiér a předávání
zboží touto zkouškou implementovány nejsou.

## 4. Soubory a převod

PixelLab endpointy: `/generate-8-rotations-v3`, `/animate-with-text-v3`.
Vstupní převod v `inputs/provenance.json`, skutečná zadání/odpovědi
v `rotations/` a `jobs/S/`. Jediná původní vlastní reference uvedena výše;
osm starších vlastních směrů není osmi vstupy služby.

[preview_pixellab_walk.py](../../../tools/preview_pixellab_walk.py) vytvořil
[náhled](../animations/lumberjack-pixellab-walk-v1/preview.html), atlas,
GIF a měření. Zdrojová PNG mají po převodu stejné SHA256. Každá z devíti
atlasových buněk zpětně ověřena proti úplnému RGBA vstupu. HTML vkládá
původní PNG; GIF je kontrolní kopie na pozadí s 256barevnou paletou.

[qa.json](../animations/lumberjack-pixellab-walk-v1/qa.json) obsahuje
skutečné rozměry, alfa meze ≥1/16/128 (pravá/dolní hrana výlučná), PNG a
RGBA SHA256, souřadnice buněk, duplicity a GIF metadata. Hra tato data
zatím nečte.

## 5. Napojení a kompatibilita

Hra, renderer, simulace, mřížka, uložené pozice ani stávající atlasy nejsou
měněné. Běžná herní cesta, import v Godotu, klikání, řazení, tónování,
mlha, cache a pozemní stín pro nové snímky: **neověřeno**.

## 6. Předání a omezení

[QA](../qa/lumberjack-pixellab-walk-v1/README.md) odděluje technický
výsledek a vizuální vady. Základ pohybu je čitelný, ale S má neuzavřený
krok a N nemá viditelnou sekeru. Další API uploady pro opravu a navázání
zastavila automatická schvalovací kontrola kvůli výkladu „jeden obrázek“;
podrobnosti v [README sady](../animations/lumberjack-pixellab-walk-v1/README.md).
Není to dokončená osmisměrná animace. Uživatelské přijetí: neuděleno.
