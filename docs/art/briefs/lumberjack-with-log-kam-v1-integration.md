# Implementace objektu: dřevorubec s kládou — KaM v1

Datum: **2026-09-10** · ID dodávky: `lumberjack-with-log-kam-v1` · herní role: `lumberjack` · typ: jednotka.
Stav: **cílená revize kontinuity SE ve fázích 7/8 je zabalená; shoda souborů a logika náhledu ověřeny; herní integrace není součástí zadání**.

Založeno podle [implementační šablony](../object-integration-template.md) a [společného postupu](../object-implementation-workflow.md).
[QA této verze](../qa/lumberjack-with-log-kam-v1/README.md).

## 1. Co je zadáno a odkud bereme data

Revize 2026-09-10 řeší uživatelem označenou výměnu identity nohou při SE
**6→7**. Starší izolovaná oprava `06.png` je překonaná; její zadání chybně
zaměnilo bližší levou a vzdálenější pravou nohu a neprokázalo kontinuitu.
Správně je bližší **pravá kyčel pod zvednutou pravou paží na levé straně
obrazu**. Nový společně kreslený pár sleduje pravou nohu zezadu v 6 přes
pokrčený průchod před levou v 7 a rozvinutí dopředu v 8 až ke kontaktu v 1.
Levou oporu v 7 střídá levá noha vzadu v 8. Po opravě příliš dlouhých nohou
se použije [zdroj dvojice](../animations/lumberjack-with-log-kam-v1/sources/SE-phases-07-08-proportions-normalized.png)
a náhrady `final-frame-overrides/SE/06.png` a `07.png` po registraci podle
čepice. Rozsah změny je pouze těchto dvou fází; shodu ostatních 62 ověří
aktuální balení. Nová kresba dosud není přijata uživatelem ani ověřena ve hře.

- Nový klip vlastní malované postavy: nesení jedné klády, osm směrů a osm původních fází pro každý směr. Nynější rozsah je výtvarná výroba a samostatný náhled.
- Existující [brief postavy](lumberjack-v1.md) dokládá vzhled a historii konceptů; [brief poslední chůze](lumberjack-walk-without-log-kam-v2.md) určuje návaznost postavy a tělesného měřítka. Starší nesjednocené koncepty nesení nejsou schválením tohoto klipu. Aktuální pohybová předloha je původní KaM `uaWalkTool2`.
- Vlastní výchozí kresba: [poslední chůze bez klády](../animations/lumberjack-without-log-kam-v2/README.md). Výtvarné ani herní schválení nového klipu zatím není.
- Původní pohybová data: [manifest úplného exportu](../../../original_game_data/kam-reference-export/lumberjack-full-set/manifest.json), akce index 11, `uaWalk` tělo + `uaWalkTool2` překryv. U všech 64 fází jsou tělesné sprite ID a pivoty stejné jako u chůze bez klády.
- Původní data pocházejí z lokální vlastněné instalace GOG Knights and Merchants (`unit.dat`, `units.rx`, `pal0.bbm`); přesné cesty a otisky jsou ve zdrojovém manifestu. Jde o externí referenci uloženou v ignorovaném `original_game_data`, nikoli o vlastní distribuované assety.
- Měřeno: počty, plátna, převody a shoda pixelů při přípravě vstupů. Vlastní návrh: malovaný vzhled. Dosud neověřeno: úplná věrnost nového nesení, fyzické došlapy, sladění s herním časováním a chování ve hře. Předchozí technická kontrola není výsledkem nynější výměny dvou fází; aktuální výsledek je v [záznamu balení](../animations/lumberjack-with-log-kam-v1/pack-validation.json).

## 2. Geometrie a registrace

| Údaj | Hodnota a zdroj | Stav |
|---|---|---|
| Původní společné plátno | 52×54 px, kotva [26,46], rozsah [-26,-46,26,8] vůči původu; manifest KaM | Doloženo zdrojem |
| Připravená buňka / směrový arch | 448×544 px / 1792×1088 px, mřížka 4×2 | Změřeno u vstupů |
| Společná obrazová kotva | [216,400] px; původ jednotky, nikoli zamknutá jednotlivá bota | Ověřeno v aktuálním balení včetně obou náhrad SE; herní kontakt neověřen |
| Převod původní předlohy | 8× nearest-neighbor, vložení na [8,32]; [26,46]×8+[8,32]=[216,400] | Provedeno u předloh |
| Převod vlastní chůze | Každý finální snímek 384×512 vložen na [32,32]; stará kotva [184,368]+[32,32] | Provedeno bez převzorkování |
| Tělesné měřítko | Navazuje na registrovanou vlastní chůzi a původní tělo při 8×; měřítko nesmí určovat kláda | Kalibrace změřena; vizuální a herní shoda není zaručena |
| Ořez a trim | Vstupní buňky bez ořezu; vlastní pixely pouze posunuté o celé pixely | Zkontrolována shoda 64 vstupních výřezů |
| Přesah původní klády | Původní úplný obal v nové buňce [8,32,424,464], pravá/dolní mez výlučná | Změřeno, vejde se bez změny měřítka |
| Alfa | Připravené archy RGB na bílém; vlastní chůze má téměř bílé neprůhledné pozadí | Předchozích 64 finálních PNG je RGB; nová revize rovněž necílí na produkční alfu |
| Mapová kotva, kolize, výška, řazení, UI a stín | Nezměněny; herní převod této kresby se nyní nezavádí | Neověřeno ve hře |
| Vchod a stavební přesahy | N/A — jednotka není budova | N/A |

Registraci nového klipu odvozovat z těla a odpovídajících fází chůze. Kláda může být nad čepicí; horní okraj celého obrysu proto není bod hlavy. Nezamykat pohybující se botu, necentrovat tělo podle nákladu. Původní odvození vlastní kotvy podle čepice neprokazuje anatomicky přesné klouby nebo neklouzání na mapě. Svahy, vyvýšený základ a hloubkové řazení jsou neověřeny.

## 3. Fáze, vrstvy a pravdivé zdroje stavů

Stavební část: **N/A — pohybující se jednotka**.

| Klip | Zdroj předlohy | Směry a snímky | Ukončení / časování |
|---|---|---|---|
| Chůze s jednou kládou | `uaWalk` + `uaWalkTool2`, původní pořadí slotů | N, NE, E, SE, S, SW, W, NW; 00–07 v každém směru, celkem 64 | Smyčka; herní tempo neověřeno |

- Zachovat pořadí z manifestu, nikoli numerické řazení sprite ID. Například S má překryvy 838,839,840,841,842,843,844,836.
- Náhled začíná pozastavený na SE ve fázi 6; výchozí tempo je 2 fps, další volby 5/10 fps. Jde pouze o posouzení kresby, nikoli sladění s rychlostí herního přesunu.
- Náklad a nesoucí paže musí odpovídat příslušnému směru původní předlohy. Žádný směr nevyrábět pouhým zrcadlením.
- Budoucí simulační zdroj nesení popisuje existující brief (`worker["carrying"] == "log"`); jeho aktuální runtime cesta zde nebyla znovu ověřena ani měněna. Rezervace a sklad chaty nenahrazují skutečně nesený náklad.
- Přechody chůze/nesení/odevzdání, skrytí uvnitř, mlha a výběr zůstávají neověřeny. Tento náhled nic nesimuluje.

## 4. Produkční soubory a převod

| Soubor / sada | Role a skutečný formát | Stav / runtime čtenář |
|---|---|---|
| [Původní guides](../../../original_game_data/kam-reference-export/lumberjack-full-set/carry-guides-8x/) `DIR.png` | 8 externích pohybových předloh, RGB PNG 1792×1088; 8× nearest-neighbor na bílém | Připravené reference, žádný herní čtenář |
| [Walk targets](../animations/lumberjack-with-log-kam-v1/walk-targets/) `DIR.png` | 8 vlastních archů pro editaci, RGB PNG 1792×1088, pouze přidané okraje | Připravené vstupy, žádný herní čtenář |
| [Manifest vlastní chůze](../animations/lumberjack-without-log-kam-v2/manifest.json) a [registrace](../animations/lumberjack-without-log-kam-v2/registration.json) | Zdrojové cesty, SHA256, měřítka a kotvy vlastní postavy | Referenční metadata |
| [Finální manifest](../animations/lumberjack-with-log-kam-v1/manifest.json) | 64 PNG 448×544, 8 archů 1792×1088, atlas 3584×4352, 16 GIFů; cesty a SHA256 | Aktuální balení obou náhrad SE technicky ověřeno; žádný herní čtenář |
| [Registrace](../animations/lumberjack-with-log-kam-v1/registration.json) a [kontrola balení](../animations/lumberjack-with-log-kam-v1/pack-validation.json) | Osm společných měřítek, 64 celočíselných posunů, měření čepic a tělesných výšek, meze siluet | Základní převod doložen; měření není důkazem nové kresby SE |
| [Aktuální dvojice SE](../animations/lumberjack-with-log-kam-v1/sources/SE-phases-07-08-proportions-normalized.png) a `final-frame-overrides/SE/06.png`, `07.png` | Zdroj fází 7/8 po opravě proporcí a jejich registrované náhrady | Náhrady po základní registraci; ostatních 62 fází se nemění |

Při této přípravě nebylo použito generování: převod provedl Python/Pillow, původní předlohy zvětšené nearest-neighbor, vlastní snímky vložené beze změny pixelů. Ověřena shoda 64 vlastních vložených výřezů a nezměněných SHA256 všech 128 vstupních PNG. Původní indexované zdroje zůstaly zachované; neprůhledné šachované pixely původní grafiky nebyly retušovány. Generovaná zdrojová velikost se liší od pracovní mřížky: `pack.py` nejprve normalizuje celý arch na 1792×1088 metodou Lanczos a jeho osm přesných výřezů ukládá do `raw/`. Tyto výřezy jsou pixelově totožné s normalizovaným archem, nikoli s původním rozměrem generovaného souboru. Následuje jedno tělesné měřítko pro celý směr a celočíselné posuny jednotlivých fází; žádná maska nemění kresbu. Skutečná zadání a generační pokusy zůstávají v dodávce oddělené od technického balení. Žádné tvrzení o přijetí neplyne z promptu.

## 5. Napojení a kompatibilita

Rozsah je **pouze artwork + samostatný preview**. Renderer, import do hry, cache, kolize, save, výběr, mlha, světlo, stíny, UI a simulační stavy se v této dodávce nemění. Herní čtenář nových metadat, fallback, paměť, starší uložené pozice i nová herní instance jsou **neověřeno**. Samostatný náhled nebude vykazován jako běžná herní cesta.

## 6. Předání

- Připraveno: osm externích pohybových guides, osm vlastních vstupních archů, **64 registrovaných PNG, 8 směrových archů, atlas 3584×4352, 16 GIFů a směrový přehled**. Všechny finální PNG mají RGB bílé/téměř bílé neprůhledné pozadí.
- Aktuální balení po výměně SE 7/8 technicky prošlo; výsledky jsou obnovené v [pack-validation.json](../animations/lumberjack-with-log-kam-v1/pack-validation.json). Exportní GIFy mají 8 fází při 5 fps (1600 ms) a 10 fps (800 ms). Velikost a aktuální výsledky samostatného HTML náhledu uvádí [preview-validation.json](../animations/lumberjack-with-log-kam-v1/preview-validation.json); dekódování 16 obrázků, shoda s aktuálními archy a logika 64 dvojic fází včetně 2/5/10 fps prošly v Node VM s výslovnými náhradami DOM/Image/timer. Náhled startuje na SE 6 pozastavený, s volbou 2/5/10 fps. Kontrola skriptu přes Node VM nenahrazuje skutečný běh v prohlížeči.
- [QA záznam](../qa/lumberjack-with-log-kam-v1/README.md): doplněna technická kompletace, kontrola všech osmi směrových archů a ověření skriptu náhledu; herní kontroly neprovedeny.
- Skutečná herní ukázka: není, integrace není součástí rozsahu.
- Předchozí statická kontrola všech směrů neprokázala kontinuitu každé nohy v čase; následná připomínka uživatele 6→7 je důvodem nynější revize SE. Nové balení prošlo; hlavní a nezávislý výtvarný agent staticky sledovali pravou nohu od kyčle k botě v 6→7→8→1. V 7 zůstává výraznější pokrčení kolena než v KaM; přesná věrnost pohybu se netvrdí. Vizuální přijetí uživatelem a schválení společného etalonu: **neuděleno**. Statická kontrola není přehrání celé animace ani herní ověření.

Generování: **13 volání vestavěného imagegen**, přesný model nástroj neuvedl;
8 základních směrů, oprava sekery SE, paže E, překonaná izolovaná oprava SE 7,
nový pár 7/8 a oprava jeho proporcí. Nová zadání:
[kontinuita](../animations/lumberjack-with-log-kam-v1/prompts/SE-phases-07-08-leg-continuity.txt)
a [proporce](../animations/lumberjack-with-log-kam-v1/prompts/SE-phases-07-08-proportions.txt).

### Změřená kalibrace — 2026-09-10

Pro každou čepici se měří barevná komponenta v okolí očekávané hlavy, nikoli nejvyšší pixel klády. HSV diagnostika používá H 2–13/255, S >150, V >75; u N/NE/NW H 2–17 a S >165 podle žlutější čepice. Všech osm diagnostických archů bylo prohlédnuto: vybrané komponenty leží na čepici. Zakrytí celého vrcholu čepice vyžadující domýšlení bodu nebylo v těchto vstupech zjištěno. Faktor je medián výšky čepice–spodní bota cílové vlastní chůze dělený mediánem stejné výšky nového směru. Po jednom společném převzorkování se horní bod a střed prvních 12 řádků čepice zarovnají celočíselným posunem ke stejné fázi vlastní chůze. Tím se přebírá její pohyb hlavy, nikoli údaj o kostře nebo fyzicky přesném došlapu.

| Směr | Společný tělesný faktor |
|---|---|
| N | 0.910012674 |
| NE | 0.977991747 |
| E | 0.956584660 |
| SE | 0.955947137 |
| S | 0.894594595 |
| SW | 0.856573705 |
| W | 0.983870968 |
| NW | 0.980689655 |

Přesné změřené soubory, velikosti a otisky předané verze jsou v [tabulce QA](../qa/lumberjack-with-log-kam-v1/README.md#změřené-soubory-a-otisky--2026-09-10).
