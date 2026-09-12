# Dřevorubec bez klády — chůze v1

Datum: **2026-09-09** · role `lumberjack` · stav: **uživatelem zamítnuto — nepoužívat pro integraci**.

Uživatel 2026-09-09 označil výsledek za velmi špatný. Generované fáze
nevytvořily přesvědčivý souvislý cyklus chůze. Další výroba touto metodou
byla zastavena; soubory zůstávají jako záznam neúspěšného pokusu.
Následující specifikace popisuje zamýšlené vlastnosti, nikoli dosaženou kvalitu.
Další rozhodování vychází ze [studie animací KaM Remake](../kam-unit-animation-study.md).

Uživatel dodal osm směrových podkladů v `../animation-references/lumberjack-without-log/`.
Navazují na vlastní [postavu v1](lumberjack-v1.md). Jde o chůzi se sekerou
v anatomické pravé ruce, bez klády; levá ruka je volná. Zachovat identitu,
oděv, přední zástěru, vyvýšenou kameru a malované materiály podkladů.

## Výrobní volba pro tuto revizi

- Osm směrů N, NE, E, SE, S, SW, W, NW; žádné zrcadlení měnící ruku se sekerou.
- Osm navazujících fází na směr: kontakt, pokles, průchod, vzestup a totéž
  s opačnou opěrnou nohou. Smyčka na místě, přirozený protiběžný pohyb paží.
- Výchozí náhled 10 snímků/s, celý cyklus 0,8 s; rychlost přehrávání nastavitelná.
  Jde o volbu této revize, ne dřívější herní standard ani schválené časování.
- Zdrojový arch 4 sloupce × 2 řady; stejné tělesné měřítko a kotva mezi fázemi.
  Cílová skutečná alfa musí být ověřena z výsledku; světlé pozadí není průhlednost.
- Připravit samostatný přehrávatelný náhled s pauzou a ručním krokováním.

## Hranice a přejímka

Tato dodávka připravuje a posuzuje animaci. Nemění herní renderer, simulaci,
mapy ani save. Současný renderer používá jednu pózu profese a pohupování;
osmisměrný přehrávač ve hře dosud neexistuje. Následná integrace musí zachovat
33 world px tělesné výšky, společnou kotvu nohou, interiéry, mlhu, řazení,
denní tónování a pauzu; měřítko nesmí určovat přesah sekery či klády.

Kontrola této revize: obsah osmi fází, střídání opěrné nohy, přechod 8→1,
stálost identity, kamera, pravá ruka, rozměry a skutečná alfa. Schválení
uživatelem **zamítnuto 2026-09-09**; QA v běžící hře **neprovedeno**.

Nástroj: vestavěný **imagegen**, bez CLI/API fallbacku. Přesná zadání,
zdroje, výsledné soubory a naměřené vlastnosti se evidují u animační sady.
