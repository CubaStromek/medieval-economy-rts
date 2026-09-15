# Implementace skladiště v2 — oprava perspektivy

Datum **2026-09-13** · ID `warehouse` · typ budova.
Stav: **v2 aktivní; 17/17 cílených testů a 66 nativních kontrol prošlo**.
[Brief](warehouse-v2.md) · [QA](../qa/warehouse-v2/README.md) ·
[postup objektů](../object-implementation-workflow.md).

## 1. Zadání a zdroje

Uživatel autorizoval opravit perspektivu skladiště, aby odpovídala vlastní
chatě a pile. Původní architektura a fungující denní/noční chování v1
zůstávají podle [briefu](warehouse-v2.md). V1 je zachována jako historická
verze, včetně jejího [QA](../qa/warehouse-v1/README.md); její testy nejsou
výsledkem této revize.

Přímé vlastní reference jsou `lumber_hut/v1/finished.png` a
`sawmill/v2/finished.png`. Skladiště v1 slouží jako reference identity,
nikoli jako závazný směr hran. Na výsledném zdroji byly měřeny vodorovné
trámy, podezdívka a okenní hrany, odděleně od sklonu střechy. Ruční měření
malované kresby nedává přesné prostorové úhly kamery.

## 2. Geometrie a registrace

Katalogová maska, mapová kotva, venkovní vstup a pravidla výšky zůstávají
podle [briefu](warehouse-v2.md). Autority výsledku:
[konceptové měření](../qa/warehouse-v2/concept-measurements.json),
[produkční export](../qa/warehouse-v2/production-export.json) a
[manifest v2](../../../game/art/buildings/warehouse/v2/manifest.json).

| Údaj | Hodnota a zdroj | Stav |
|---|---|---|
| Obsazená zem / vstup | 3 × 3, `###/###/#E#`, 120 × 120 world px; vstup podle katalogu | Zachováno |
| Finální zdroj | 1254 × 1254 RGB na technickém magenta pozadí | Skutečný source prohlédnut |
| Zdrojový práh | `(670,1190)`, přední střed centrálního kamenného nástupu | Ručně změřeno |
| Zdroj→world | 0,095 world px / source px, jednotné škálování | Zapsáno v měření a exportu |
| Produkční canvas | 800 × 800 RGBA, oba dveřní stavy bez trimu | Exportováno |
| Produkční práh a měřítko | `(427,4322; 759,1707)`, 0,1489125 world px / pixel | Odvozeno stejným převodem obou stavů |
| Alfa obal | `[16,27,772,734]` jako x, y, šířka, výška; stejný v obou stavech | Export, import a nativní snímky ověřeny |
| Dveře a člověk | Šířka otvoru přibližně 40 world px, konzervativní výška pod výztuhou přibližně 37,05; člověk 33 | Ruční měření zdroje, nikoli hotový herní důkaz |
| Zemní kontakt | Změřené viditelné kontakty uvnitř 120px masky; centrální nástup končí severně od prahu | Zdrojové měření a prohlédnutý vyvýšený herní základ |
| Hloubka / UI / stín | Samostatná pole `sort_foot`, `label_anchor`; fyzická zem a půdorysný stín se nemění | Ověřeno běžnou cestou a snímkem vyvýšeného základu |

[Technický podklad](../sources/warehouse-v2/ground-guide.png) vznikl před
kresbou. První varianta zlepšila směry hran, ale měla příliš nízká vrata.
Následně se zvýšilo přízemí a prodloužil centrální nástup, při zachování
pohledu a svislic. Finální měření má nejnižší pevný kontakt y1189 vůči
prahu y1190 a ruční toleranci přibližně ±4 source px. Skryté kontakty
nejsou změřené; střecha a komín se posuzují samostatně.

## 3. Vrstvy a skutečné stavy

Jde o grafickou revizi; žádná nová stavební sada, simulace, obyvatel nebo
formát save se nepřidávají. Zachová se existující stavební prezentace
nedokončené budovy. Počet nových stavebních fází: **N/A — nezadány**.

| Vrstva | Zdroj a pravidlo | Registrace |
|---|---|---|
| Zavřený dům | `finished.png`, noc nebo neutrální cizí stav | Společný produkční práh |
| Otevřená denní vrata | `day-open.png`, dokončená oprávněně známá budova přes den; nezávisle na obsazení | Jen vymezený otvor vrat, stejná silueta |
| Světlo obou oken | Skutečný spící nocležník se shodným `sleep_home_id`, `inside_building_id` a vlastníkem | Nové `life.windows` a `life.window_panes` |
| Komínový kouř | Stejný skutečný noční pobyt; animace ze simulačního ticku a jeho zlomku | Nové `life.chimney` |
| Zásoby / vnitřní postavy | N/A — výslovná výjimka uživatele | Žádné vrstvy ani kotvy |

[Ruční okenní měření](../sources/warehouse-v2/life-measurements.json)
vychází přímo z finálního 1254² zdroje: dva otvory, tři konzervativně
vymezené tabulky každého okna a ústí komína `(316,119)`.
Zvětšené diagnostické výřezy a skutečné pixely ověřily, že masky nepřepisují
rámy, svislé příčky ani dřevěná ostění. Levá první tabulka je úzká kvůli
hlubokému ostění. Všechny body se převádějí stejným měřítkem jako dům.

`WarehouseLife` zůstává zdrojem existujících pravidel: návštěva nosiče,
rezervace noclehu ani inventář efekty nezapnou; pauza zachová světlo a
zastaví čas kouře. Cizí stav při mlze se vrací neutrální ještě před čtením
obyvatel. Efekty nemají vlastní rozšířenou klikací oblast.

## 4. Produkční soubory a původ

Vestavěný ImageGen; konkrétní neoznámený model se neodhaduje. Vlastní
reference, technický podklad, jednotlivé pokusy a skutečná zadání jsou
v [provenance.json](../sources/warehouse-v2/provenance.json).
Magenta zdroj není vydáván za přímou alfu;
technické odstranění pozadí a skutečné výstupní otisky zaznamenává
[production-export.json](../qa/warehouse-v2/production-export.json).

| Soubor | Role | Formát / evidence |
|---|---|---|
| `closed-key-master.png` ve zdrojích v2 | Zvolený zavřený master po opravě výšky a nástupu | 1254²; SHA-256 `1cc484d32c122504405fef05dceb3e79d0a68d6fad2d63bd8c19dfd6cf9599e1` |
| `game/art/buildings/warehouse/v2/finished.png` | Zavřený neutrální dům | 800² RGBA; přesný otisk v manifestu |
| `game/art/buildings/warehouse/v2/day-open.png` | Otevřená vrata | 800² RGBA; přesný otisk v manifestu |
| `game/art/buildings/warehouse/v2/manifest.json` | Textury, registrace, alfa obaly, okna a komín | Schema 1, asset v2; čtenář `WarehouseSpriteLibrary` |

Export uvádí 178341 zdrojových pixelů ve vymezené dveřní oblasti a
**0 změněných bajtů mimo ni** mezi denní a zavřenou variantou. Obě mají
stejný alfa obal a 413586 pixelů v evidovaném alfa měření.
[Finální alfa kontrola](../qa/warehouse-v2/alpha-report.json) po odstranění
zbytkových odpojených pixelů potvrzuje **0 viditelných sytě magenta pixelů**
a nejvyšší alfu **0 na všech okrajích** obou obrázků.
[Světlý/tmavý diagnostický arch](../qa/warehouse-v2/alpha-light-dark.png)
byl prohlédnut; neobsahuje změněné produkční pixely. Tato technická kontrola
sama nedokládá nativní terénní kontakt.

## 5. Zapojení a kompatibilita

Normální cesta používá `WarehouseSpriteLibrary`, větev skladiště
v `main_view.gd` a existující `WarehouseLife`. Výchozí manifest je nyní
**v2**. Cílené testy načetly její finální importované pixely a ověřily,
že cache předchozí v1 nepřebíjí novou verzi.
Výběr obsazené země, alfa test mimo ni, terénní zakrytí, světlo, stíny,
mlha a načtení stávající hry musejí projít stejnou cestou jako dříve.

**Prošlo 17/17 cílených testů:**
[7 sprite případů](../qa/warehouse-v2/sprite-tests.log) a
[10 případů života budovy](../qa/warehouse-v2/life-tests.log), Godot 4.7.2.
Zahrnují reálné textury, registraci, výběr, stavové hranice, skutečné
nocležníky, soukromí, nedokončení, pauzu a save/load.

**Nativní běh 2026-09-13 prošel: 66 kontrol, 17 snímků, 0 chyb**,
Godot 4.7.2 / Apple M4. [Report](../qa/warehouse-v2/runtime/report.json)
dokládá menu→Relief, skutečné přesuny zboží, nocležníka ve skladu v ticku
3755 a obnovené tři nocležníky po načtení v ticku 3780. Pauza udržela
stejný hash kouřového výřezu; po 25 vykonaných ticích se obraz změnil.
Všechny fáze mají aktivní manifest v2 a načtené RGBA otisky odpovídají
finálnímu manifestu. Otisky podkladů na začátku a konci jsou shodné.

Byly prohlédnuty denní trojice při 0.75×/1×/2.4×, noční detail a trojice,
normální den/noční pobyt i vyvýšený základ. Čelní a levé konstrukční směry
jsou soudržné s oběma referencemi při zachované vlastní siluetě; bez
zjevného barevného lemu, useknuté podezdívky nebo zablokovaného přístupu.
Světelné plochy zachovávají příčky, kouř vychází z ústí komína.
Jemné odchylky jednotlivých malovaných hran zůstávají; výsledek není
tvrzením o přesné společné 3D kameře.

Úplných 876/876 z v1 se nepřebírá
jako výsledek v2 a pro tuto bitmapovou/manifestovou revizi se celá sada
neopakovala; rozsah tvoří cílené testy a následné nativní ověření.

## 6. Předání

Technický výsledek: v2 je aktivní; export/import, **17/17 cílených testů
a 66 nativních kontrol prošly**, bez chyb v zaznamenaném rozsahu.
Vizuální výsledek: perspektiva opravena při zachované identitě; společné
nativní snímky, oba dveřní stavy, okna, kouř a vyvýšený základ prohlédnuty.
Podrobné důkazy a omezení vede [QA](../qa/warehouse-v2/README.md).
Uživatelské schválení konkrétní finální v2 ani etalonu sady **neuděleno**;
autorizovaná integrace tím není pozastavena.
