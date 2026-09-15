# Kontrola skladiště v2 — sjednocení perspektivy

Datum **2026-09-13**, Codex.
[Brief](../../briefs/warehouse-v2.md) ·
[integrační záznam](../../briefs/warehouse-v2-integration.md) ·
[postup objektů](../../object-implementation-workflow.md).
Stav: **v2 aktivní a importovaná; 17/17 cílených testů a
66 nativních kontrol prošlo; společné herní snímky prohlédnuty**.

## 1. Přesný rozsah

Revize kresby existujícího `warehouse` opravuje plošší perspektivu v1
podle vlastní chaty a pily. Nemění katalogový půdorys, herní kameru,
simulaci, save ani pravidla denních/nočních vrstev. Bez vizuálních zásob
a osob uvnitř podle výslovné výjimky uživatele. V1 i její
[historické výsledky](../warehouse-v1/README.md) zůstávají zachované.

Vlastní obrazové vstupy, generované pokusy a skutečné prompty jsou
v [provenance.json](../../sources/warehouse-v2/provenance.json);
nástroj vestavěný ImageGen.
Finální zdroj `closed-key-master.png` je **1254² RGB na magenta pozadí**,
SHA-256 `1cc484d32c122504405fef05dceb3e79d0a68d6fad2d63bd8c19dfd6cf9599e1`.
Není zaměnitelný s produkčními PNG.

Dodané `finished.png`, `day-open.png` a
[manifest v2](../../../../game/art/buildings/warehouse/v2/manifest.json)
jsou pod `game/art/buildings/warehouse/v2/`. Obě bitmapy mají **800² RGBA**.
Přesné otisky, vymezení dveřního výřezu a alfa měření vede
[produkční export](production-export.json). Finální import a skutečné
načtené pixely **v2 ověřily cílené testy**; výchozí cesta v
`WarehouseSpriteLibrary` používá manifest v2. Nativní běh ověřil tuto
verzi ve vlastní herní instanci: všechny fáze mají manifest v2 a shodné
načtené RGBA otisky, podklady mají stejné otisky na začátku a konci běhu.

## 2. Měření před derivátem

[Ground guide](../../sources/warehouse-v2/ground-guide.png) a
[jeho kontrakt](../../sources/warehouse-v2/geometry.json) předcházely kresbě.
Finální [měření](concept-measurements.json) a [ground-fit.png](ground-fit.png)
se týkají skutečného zavřeného zdroje po zvýšení přízemí a prodloužení
centrálního nástupu; nejsou screenshotem hry.

| Kontrakt | Naměřený údaj a omezení |
|---|---|
| Půdorys a přístup | Zachované 3 × 3, `###/###/#E#`, 120 × 120 world px; prostřední venkovní vstup |
| Práh a jednotné měřítko | Zdroj `(670,1190)`, 0,095 world px / source px; produkce 800² beze změny poměru os |
| Dveře / člověk | Přibližně 40 world px šířky, konzervativně 37,05 výšky pod výztuhou proti 33px postavě; celá šířka není průchozí v každé výšce |
| Viditelné kontakty | Změřené kontakty uvnitř masky, pevný jižní kontakt y1189; skryté kontakty neměřeny |
| Směr čelní / levé základny | Přibližně −0,266 / +0,834 jako `Δy/Δx` v obrázku, nikoli prostorové úhly kamery |
| Tolerance | Ruční body přibližně ±4 source px; kontakt a okraje následně prohlédnuty v nativním snímku |
| Alfa a dveřní registrace | Export obou stavů má shodný obal `[16,27,772,734]` (x,y,šířka,výška); 0 změněných bajtů mimo dveřní oblast |

Nezávislá prohlídka zdroje potvrdila výrazné přiblížení směru vodorovných
hran referencím a zachování svislic po zvýšení přízemí. Teplý kámen,
silné dřevo a skupiny šindelů drží původní materiálový jazyk. Referenční
chata a pila samy nemají všechny malované hrany geometricky totožné;
„shoda“ zde neznamená odvození přesné společné 3D kamery.

[Okenní měření](../../sources/warehouse-v2/life-measurements.json) obsahuje
dva otvory, tři samostatné tabulky každého okna a ústí komína `(316,119)`
ve zdroji 1254². Zvětšené diagnostické výřezy a pixelové vzorky byly
prohlédnuté: masky leží uvnitř tmavých ploch a zachovávají svislé příčky,
rámy i ostění. Úzká první tabulka levého okna odpovídá jeho hlubokému
ostění. Nativní noční detail potvrdil světlo v obou oknech při zachovaných
příčkách a kouř vycházející z naměřeného ústí.

## 3. Běžná herní cesta a izolované stavy

**Provedeno 2026-09-13:** čerstvá instance přes skutečné menu→Relief,
denní obraz v2, reálné přesuny zásob a postup všech simulačních ticků
k nočnímu návratu. V ticku **3755** už spí ve skladu jednotka 22;
po vlastním dočasném save/load v ticku **3780** jsou uvnitř tři skuteční
nocležníci a čas efektů je 378,0 s. Změna inventáře nepřidala kreslené
zboží ani interiérovou postavu. Hráčovy save nebyly použity.

Oddělená izolovaná scéna porovnala sklad s **oběma** referencemi,
ukázala prázdný i obsazený noční stav, nulový/plný inventář se stejnými
pixely, tři přiblížení a vyvýšený půdorys. Její ručně nastavené stavy
jsou označené jako fixture; nenahrazují skutečný příchod v první části.
V1 chyba umístění chaty se v tomto v2 běhu neopakovala.

## 4. Herní kontroly v2

| Kontrola | Očekávání | Aktuální výsledek |
|---|---|---|
| Aktivní verze | Čerstvě importovaný manifest a pixely v2 | **Prošlo**: cílené testy a shodné otisky všech nativních fází |
| Perspektiva a čitelnost | Vedle chaty a pily v jednom snímku při 0.75×, 1× a 2.4× | **Prohlédnuto**: konstrukční směry jsou soudržné, sklad si drží vlastní siluetu |
| Alfa a filtrace | Bez magenta lemu či falešné šachovnice na terénu i v otvorech | **Prošlo v uvedeném rozsahu**: export/import, diagnostický arch a nativní snímky bez zjevného klíčového lemu |
| Ground fit a terén | Celé patky na rovině i vyvýšeném základu, volný dveřní přístup | **Prohlédnuto**: dolní zdivo zachované, centrální přístup volný |
| Řazení a výběr | Shodná kresba a alfa výběr, neklikací průhledné okraje, zachovaný spodek na terénu | **Prošlo**: cílený výběr a prohlédnutá nativní rovina/vyvýšený základ |
| Denní / noční vrata | Den otevřeno nezávisle na obsazení, noc zavřeno; bez posunu domu | **Prošlo**: stavové hranice, registrace a skutečný den/noční příchod |
| Okna a komín | Obě okna svítí jen se skutečným nocležníkem, příčky zachovány, kouř od ústí | **Prošlo**: zdroje stavů i prohlédnutý nativní noční detail |
| Pauza a čas | Stejné pixely při pauze, pohyb kouře po skutečných ticích | **Prošlo**: shodné kouřové výřezy při pauze, odlišný po 25 ticích |
| Mlha / soukromí / stavba | Neutrální cizí stav před čtením obyvatel; žádné efekty nedokončeného domu | **Prošlo v cílených testech**; samostatné nativní snímky těchto stavů nejsou součástí běhu |
| Save/load | Zachované skutečné bydlení, inventář a čas efektů bez migrace | **Prošlo**: stavový round-trip a dočasný save/load v běžné cestě |
| Vizuální zásoby / jednotky | N/A — uživatel vyloučil | Nevyrábět |
| Nové stavební obrazy | N/A — tato perspektivní revize je nezadává | Stávající stavební prezentace se zachová |

## 5. Běhy a důkazy

| Běh | Pokrytí | Výsledek v2 |
|---|---|---|
| Cílené sprite a život budovy | Skutečné finální importované textury v2, registrace, alfa a stavové zdroje | **17/17 prošlo**: [sprite 7/7](sprite-tests.log), [život budovy 10/10](life-tests.log) |
| Úplná sada | Historických 876/876 náleží v1 | Pro bitmapovou/manifestovou revizi znovu nespouštěna; ověřen rozsah cílených testů a nativního běhu |
| Nativní runner | Běžná cesta, porovnání, noční efekty, pauza a dočasný save/load | **66 kontrol, 17 snímků, 0 chyb**, [report](runtime/report.json), Godot 4.7.2 / Apple M4 |
| Ruční prohlídka nativních snímků | Denní trojice 0.75×/1×/2.4×, noční detail/trojice, normální den/noc, vyvýšený základ | **Provedena**, konkrétní snímky níže |

Spuštěny byly projektové scény `res://tests/warehouse_sprite_runner.tscn`
a `res://tests/warehouse_life_runner.tscn` s Godotem **4.7.2**, přepínači
`--headless --path game --audio-driver Dummy` a vlastními logy výše.
Logy neobsahují chyby GDScriptu; hlášení systémového certifikátu na macOS
nesouvisí s testovanými prostředky hry. Nativní
`res://tests/warehouse_game_runner.tscn` dokončil běh **2026-09-13 10:25:30**
(čas uložený reportem); příkaz a oddělení scén uvádí [runtime záznam](runtime/README.md).

[Alfa report](alpha-report.json) finálních bitmap uvádí u obou stavů
**0 viditelných sytě magenta pixelů**, maximální alfu na všech okrajích
**0** a průhledné rohy. [Diagnostický arch na světlé a tmavé](alpha-light-dark.png)
byl skutečně prohlédnut bez viditelného klíčového pozadí či šachovnice.
Arch nemění produkční pixely. Finální produkční otisky v nativním reportu
zůstaly od začátku do konce shodné. Každá nativní fáze uvádí manifest v2
a skutečný načtený RGBA hash, který odpovídá danému stavu finálního manifestu.

Skutečně prohlédnuté nativní důkazy:

- Denní trojice při [0.75×](runtime/fixture/day-pair-0_75.png),
  [1×](runtime/fixture/day-pair-1_0.png) a [2.4×](runtime/fixture/day-pair-2_4.png).
- [Noční detail](runtime/fixture/night-home-detail.png) a
  [noční trojice](runtime/fixture/night-home-pair.png): světelné plochy
  zůstávají uvnitř rámů, příčky jsou čitelné a kouř vychází z ústí.
- [Normální den](runtime/natural/day-open-2_4.png),
  [skutečný noční pobyt](runtime/natural/night-home.png) a
  [stav po načtení](runtime/natural/loaded-night-home.png).
- [Vyvýšený základ](runtime/fixture/raised-edge-door-approach.png):
  zachovaná podezdívka a volný přístup ke vratům.

Pixelová kontrola kouře používá výřez `[691,162,95,109]` (x,y,šířka,výška):
obě pauzované varianty v čase 375,5 s mají totožný hash, po 25 skutečných
ticích je odlišný. [Report](runtime/report.json) ukládá všechny tři otisky.
Prohlídka neodhalila zjevný barevný lem ani useknuté dolní zdivo. Rozdíly
jednotlivých malovaných hran zůstávají; společné konstrukční směry nejsou
tvrzením o přesné společné 3D kameře.

## 6. Výsledek této verze

Technická integrace: **v2 aktivní; export/import, cílené testy 17/17 a
nativní běh 66 kontrol bez chyb prošly**.
Provedená vizuální kontrola: finální zdroj, ruční masky, světlý/tmavý arch
a výše uvedené nativní herní snímky.
Uživatelské přijetí konkrétní finální v2: **neuděleno**; oprava a integrace
jsou autorizované. Etalon celé sady: **ne**.
V zaznamenaném rozsahu nejsou doložené nevyřízené technické chyby.
Omezení: ruční tolerance geometrie, skryté neměřitelné kontakty,
jemná variace malovaných hran a pouze cílené testové pokrytí mlhy/stavby.
Nová stavební sada ani plná série všech terénních/occlusion kombinací
nejsou součástí této dodávky. Přejímka vzhledu uživatelem zůstává samostatná.
