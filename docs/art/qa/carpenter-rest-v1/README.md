# QA — tesař, odpočinek doma v1

Datum **2026-09-12**. Rozsah: nová samostatná odpočinková vrstva role
`carpenter` a hlavy vlevo/střed/vpravo u pily. Přípravný záznam podle
[QA šablony](../../object-qa-template.md).
[Brief](../../briefs/carpenter-rest-v1.md) · [Integrace](../../briefs/carpenter-rest-v1-integration.md).
**Dosavadní výsledek: nové assety vyrobeny a prohlédnuty; 3/3 pózy prošly
nezávislým dekódováním PNG v Godotu. Běžnou hru ověřuje QA pily.**

## Přesně ověřené podklady

Nativní `UnitSpriteLibrary` vybral aktuální roli tesaře ze skutečného
produkčního atlasu. [Výřez](../../sources/carpenter-rest-v1/current-carpenter-native.png)
a [záznam](../../sources/carpenter-rest-v1/current-carpenter-extraction.json)
jsou referencí identity, nikoli důkazem nové pózy nebo normální hry.
Oblast `[684,676,163,306]`, výška 33 world px, 2× reference vizuálně prohlédnuta.

Nový master, skutečná zadání a zdrojové hashe:
[provenance](../../sources/carpenter-rest-v1/prompts.json).
Produkční PNG/manifest/hashes: [resting_carpenter.json](../../../../game/art/buildings/sawmill/v1/life/resting_carpenter.json)
a [look.json](../../../../game/art/buildings/sawmill/v1/life/look/look.json).
Naměřené RGB pozadí bylo technicky převedeno na skutečnou alfu. Celý master
1024×1536→132×198 vložen do256² v `[62,28]`, bez trimu. Vlasy y94 a spodní
hranice nosné podrážky y1374 dávají1280→165→33worldpx. Foot je
`[133.02734375,205.1171875]`; měřítko0.2worldpx/productionpx.
Zdrojová head/neck maska je specifická pro tuto postavu; mimo ni a na y>=79
jsou všechny pixely původního těla zachované. Konkrétní import a runtime snímky
vedou [QA pily](../sawmill-v1/README.md).
Pro nové snímky zaznamenat čerstvý proces, renderer, okno, zoom, mapu, worker ID,
tick a otisky aktuálně načtených souborů. Původní zdroje nepřepisovat.

## Běžná herní cesta

Plán reprodukce: menu → nová mapa s dokončenou pilou → konkrétní tesař
přijde domů → skutečně odpočívá → odejde nebo začne pracovat → noc a návrat →
uložení/načtení a pokračování. Player save se nepřepisuje; použít QA svět.
Tato cesta ještě nebyla vykonána. Umělé fixtures označit zvlášť a nepovažovat
je za důkaz skutečného pracovníkového příchodu.

## Kontroly

| Kontrola | Očekávání | Výsledek a důkaz |
|---|---|---|
| Identita a měřítko | Hnědé vlasy bez čepice/vousů, světlá košile, hnědá dlouhá zástěra, klidné ruce bez pily/nákladu; tělo 33 world px | Prošlo pro asset: master a [33px karta](../../sources/carpenter-rest-v1/body33px-qa-4x.png) skutečně prohlédnuty, měřítko z vlastních vlasů/podrážky |
| Alfa | Opravdové průhledné pozadí/mezery, čisté okraje na světlém/tmavém/terénu, žádná šachovnice/magenta | Prošlo: [3pozadí](../../sources/carpenter-rest-v1/alpha-qa.png) prohlédnuta, base59 615 nulových/1 320 částečných/4 601 neprůhledných, 0 residual-key pixelů všech3póz |
| Kontakt/opora | Horní záda u levého předního sloupku; obě boty na zemi, žádné překrytí vstupu ani skladů; rovina i zvýšený okraj | Neověřeno |
| Pohledy | 3 skutečná natočení hlavy; tělo, ruce a chodidla pixelově totožné; žádné skoky během přechodu | Statické varianty prošly: [6×hlavy](../../sources/carpenter-rest-v1/head-qa-6x.png) skutečně prohlédnuty, levá906/pravá945 změněných pixelů pouze v `[106,37,141,77]`; pod y79 a y160 přesně0 změn. Nativní časové přechody ověřuje QA pily |
| Řazení | Správné překrytí fasádou/terénem; postava nezmizí pod rovnou zemí | Neověřeno |
| Denní spouštěč | Pouze skutečný vlastní obyvatel v dokončené pile, bez nákladu a aktivní práce/předání | Neověřeno |
| Negativní stavy | Nepřítomnost, nosič, pouhé přidělení, práce, náklad, noc, rozestavění nezobrazí odpočívající postavu | Neověřeno |
| Mlha a soukromí | Cizí pila při zapnuté mlze neodhalí živého obyvatele; pozitivní kontrola stejné vlastní viditelné scény | Neověřeno |
| Nezdvojená jednotka | Běžný skrytý sprite, náklad, stín, UI a hit target se nekreslí vedle dekorované pózy | Neověřeno |
| Den/soumrak/noc | Postava se tónuje s domem; v nočním spánku není venku; okno/kouř viz QA pily | Neověřeno |
| Pauza/rychlost | Globální pauza zmrazí celé pixely uprostřed pohledu; osobní pauza doma dovolí skutečný odpočinek | Neověřeno |
| Save a čistota dotazů | Načtení rekonstruuje aktuální stav, kresba nemění simulation snapshot | Neověřeno |
| Zoom a výkon | 0.75× / 1× / 2.4× v reálné osadě; cache bez práce s pixely v každém snímku | Neověřeno |
| Stavba/strom | Charakter nemá vlastní stavební ani růstové fáze | N/A — vrstvy jednotky |

Při pixelové kontrole mlhy/zakrytí porovnat nezávislý pozitivní viditelný
render i scénu bez postavy. Prázdný ROI není průchod testu. Pro invarianty hlavy
porovnat produkční RGBA mimo změřenou hlavu a celý cyklus v nativním výstupu.

## Provedené běhy

| Běh | Rozsah | Výsledek |
|---|---|---|
| `godot --headless --path game --script ../docs/art/sources/carpenter-rest-v1/extract-current-carpenter.gd` | Skutečný reader atlasu, pouze extrakce reference | Prošlo, návrat 0; prostředí nemohlo psát svůj user log a hlásilo dostupnost systémových certifikátů, výstupní PNG/JSON vytvořeny a prohlédnuty |
| `godot --headless --log-file /private/tmp/carpenter-assets.log --path game --script ../docs/art/qa/carpenter-rest-v1/verify-assets.gd` | Nezávislý Godot decoder:3produkční hlavy, skutečná alfa, 33px registrace, trup/podrážka jako pozitivní kontroly, body invariance | Prošlo, návrat0, [výsledky a hashe](asset-verification.json). Systémový certifikát macOS hlásil chybu při inicializaci, offline kontrola PNG ji nepotřebovala |
| Zaměřené runtime testy a regrese | Přítomnost/pauza/noc/save/mlha | Neprovedeno |
| Nativní fixtures a normální hra | Výše uvedená kontrolní matice | Neprovedeno |

## Rozhodnutí

Technická kontrola assetů: **prošla 3/3 pózy**, 2026-09-12.
Nativní herní integrace a časové přechody: **samostatné QA pily**.
Uživatelské výtvarné přijetí: **neuděleno**. Použití jako společný výtvarný
etalon: **ne**. Přípravná dokumentace nepřidává bránu autorizované implementaci.
