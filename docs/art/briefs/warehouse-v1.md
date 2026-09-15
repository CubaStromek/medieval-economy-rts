# Skladiště v1 — obecní sýpka

Datum **2026-09-13** · ID `warehouse` · asset v1 · výtvarný směr
[v0.2](../building-style-guide.md). Stav: **herní pilot integrován; perspektiva
určena k opravě ve [v2](warehouse-v2.md), která je nyní rozpracovaná**.
[Postup objektů](../object-implementation-workflow.md) ·
[integrační záznam](warehouse-v1-integration.md) · [QA](../qa/warehouse-v1/README.md).

## Rozsah a odezva uživatele

Centrální skladiště různých druhů zboží a stávající nouzový noční úkryt.
Uživatel 2026-09-13 přijal navrženou architekturu slovem „super“, následně
výslovně požádal o **otevřená vrata přes den, zavřená v noci, světlo z oken
a kouř z komína** a autorizoval implementaci. Ta byla ve v1 provedena.
Dřívější stav „pouze koncept“ už nepopisuje tuto dodávku.

Pozdější kontrola na jeho pokyn odhalila proti chatě plošší perspektivu:
čelní vodorovné hrany méně stoupají doprava a hloubkové hrany levého boku
jsou plošší. Uživatel poté autorizoval opravu podle chaty a pily ve
[v2](warehouse-v2.md). V1 není schválena jako shoda perspektivy ani jako
obrazový etalon celé sady. Pozitivní odezva na architekturu zůstává platným
historickým rozhodnutím, nikoli schválením každého herního detailu.

## Identita a vlastní reference

Kompaktní dvoupodlažní objem, mohutná polovalbová šindelová střecha,
malý nakládací vikýř s krátkým pevným zdvihacím trámem a široká nákladová
vrata. Horní otvor není druhý herní vstup. Teplá nepravidelná kamenná
podezdívka, silné trámy, prkenné výplně a střídmá světlá omítka.
Velké malované skupiny šindelů, tlumené přírodní barvy a střídmé kování;
žádný otevřený výrobní přístřešek. Komín a dvě rámovaná okna patří k malé
vytápěné části stávajícího úkrytu, nikoli k výrobnímu stroji.

Přímé vlastní reference byly skutečně prohlédnuté
[pila v2 a chata ve stejném záběru](../qa/sawmill-v2/dynamic-native/full-pair-zoom-2_4.png),
`game/art/buildings/sawmill/v2/finished.png` a
`game/art/buildings/lumber_hut/v1/finished.png`.
Jejich pozitivní přijetí 2026-09-13 není plošným schválením katalogu.
Originální KaM pixely nejsou obrazovým vstupem skladiště.

## Geometrie a registrace

Autorita: `game/data/buildings.json` → `warehouse` a
`game/scripts/simulation/building_footprints.gd`. Půdorys **3 × 3**, všech
9 polí obsazených; sever→jih `###/###/#E#`. Pole má 40 world px, půdorys
120 × 120 world px. Kotva je levé dolní pole, dveřní pole `(1,0)`,
venkovní vstup `(1,1)`. Fyzický práh určuje
`project_grid_position(door_cell + Vector2(0,0.5))`; terén posouvá obraz
vzhůru o 8 world px za úroveň. Půdorys ani herní vstup se kvůli kresbě nemění.

[Ground guide](../sources/warehouse-v1/ground-guide.png) a
[geometrický kontrakt](../sources/warehouse-v1/geometry.json) vznikly před
kresbou s reálným přibližně 33px člověkem. Cílem vrat bylo nejméně 30 world px
šířky a přibližně 36–38 world px výšky. Zemní zdi, patky a blokující prvky
patří do obsazené země; střešní přesahy se hodnotí samostatně.

Starší `concept-04.png` měl nevyhovující jižní kontakt šikmého prahu.
Produkční zdroj jej opravil krátkým **centrálním kamenným nástupem**;
nejde o zvětšení herního půdorysu. Měřený práh zdroje 1254² je `(615,1161)`,
zdroj→world **0,098**. Oba stavy jsou jednotně převedeny na 800².
Přesná produkční registrace, okenní tabulky a komín jsou v
[manifestu v1](../../../game/art/buildings/warehouse/v1/manifest.json),
postup a měření v [produkčním exportu](../qa/warehouse-v1/production-export.json).
Starší konceptové měření zůstává evidencí staršího obrázku.

## Implementované stavy a výjimky

**2026-09-13 uživatel výslovně vyloučil vizuální množství zboží i jakoukoli
postavu uvnitř skladiště.** Inventář `building["storage"]` a skuteční
nocležníci dál existují; nevznikl nový skladník, recept ani sada jednotek.

| Stav | Chování v1 |
|---|---|
| Dokončená vlastní budova přes den | Otevřená vrata bez ohledu na obsazení; tmavá okna, bez kouře |
| Noc se skutečným nocležníkem | Zavřená vrata, světlo v obou oknech, jemný pohyblivý kouř |
| Noc, nikdo ještě nepřišel nebo už odešel | Zavřená vrata, tmavá okna, bez kouře |
| Nedokončená stavba | Stávající stavební prezentace; žádné efekty hotového domu |
| Cizí budova při zapnuté mlze | Neutrální zavřený a neosvětlený stav, bez čtení skrytých obyvatel |
| Globální pauza | Zastavený pohyb kouře a blikání, zachované světlo a stav vrat |
| Zásoby / vnitřní postavy | N/A podle uživatele; do obrazu se nemapují |

Noční pobyt vyžaduje `sleep_home_id == building.id`, fyzické
`inside_building_id == building.id`, odpovídajícího vlastníka a skutečný
`world.is_worker_sleeping(worker)`. Příchod noci, přidělení místa,
návštěva nosiče, zboží ani pozastavená práce samy efekty nezapnou.
`WarehouseLife` podporuje obě okna a přesné masky tabulek zachovávající
rámy; `WarehouseSpriteLibrary` přepíná registrované denní/noční dveře.
Efekty procházejí stejným řazením a mlhou jako budova a nerozšiřují klikací
oblast. Měřené kotvy zásob nebo odpočívající postavy jsou N/A.

## Produkce a ověření

Koncept [warehouse-v1.png](../concepts/warehouse-v1.png) je historický
1254² RGB na bílém pozadí. Produkční `finished.png` a `day-open.png` v
`game/art/buildings/warehouse/v1/` jsou **800 × 800 RGBA** se společným
prahem, měřítkem a siluetou. Otevřená varianta mění jen vymezený otvor vrat;
export zaznamenává nula změněných bajtů mimo tuto oblast. Okna ani kouř
nejsou zapečené do denní bitmapy. Nová stavební obrazová sada nebyla zadána.

Vestavěný ImageGen, skutečné prompty a zdroje jsou pod
`docs/art/sources/warehouse-v1/`; neoznámený konkrétní model neodhadujeme.
[Konceptový původ](../sources/warehouse-v1/provenance.json) a
[produkční export](../qa/warehouse-v1/production-export.json) zachovávají
odlišné zdroje a otisky. První šachovnicový pokus nebyl použit jako RGBA.

Před zahájením v2 dne 2026-09-13 prošlo **17/17 cílených** a
**876/876 úplných headless testů**. Nativní průchod zaznamenal **65 kontrol,
17 snímků a 1 chybu umístění chaty v izolované srovnávací scéně**;
nejde o plný průchod všech nativních kontrol. Skutečná cesta menu→Relief,
přesuny zboží, příchod nocležníků, uložení/načtení a zmrazení kouře při
pauze jsou doloženy v [runtime QA](../qa/warehouse-v1/runtime/report.json).
Výsledky platí pro zaznamenanou v1, nikoli pro rozpracovanou v2.
