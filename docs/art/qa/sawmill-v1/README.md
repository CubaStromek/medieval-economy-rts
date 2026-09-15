# Pila v1 — kontrola a předání

Datum **2026-09-12**. Technická integrace **prošla**; finální herní kresba
je předána uživateli k prohlédnutí. Přijetí konceptového směru ani úspěšné
testy nejsou schválením etalonu celé sady.

Pozdější doplnění **2026-09-12** přidalo skutečné zásoby a pracujícího
tesaře; má [vlastní finální QA](../sawmill-operation-v1/README.md).
Níže uvedené snímky a výsledky nadále dokládají původní denní/noční revizi.

## 1. Ověřená verze a prostředí

| Údaj | Hodnota a důkaz |
|---|---|
| Objekt | Budova `sawmill`, verze v1; komín, levé okno, domácí odpočinek tesaře |
| Autority | [Brief](../../briefs/sawmill-v1.md), [integrace](../../briefs/sawmill-v1-integration.md), výtvarný směr v0.2, [společný život výrobních budov](../../production-building-life-pattern.md) |
| Prostředí | macOS, Godot 4.7.2, OpenGL Compatibility / Apple M4, zvuk Dummy |
| Běžná hra | `game/scenes/game_session.tscn`, nabídka Nová hra → mapa Relief; skutečná pila ID 4 na (10, 5), tesař ID 20 |
| Ověřený kód | Pracovní strom nad `c965329c077111c6732c5f3153e39c4900159d3f`; dotčené runtime soubory a SHA-256 jsou v [manifestu běžného průchodu](natural/report.json) |
| Původ | Vlastní imagegen podklady, přesné prompty a reference v briefu a [záznamu tesaře](../../briefs/carpenter-rest-v1-integration.md); KaM pouze pro prohlédnutí projekce |
| Identita exportu | [asset-validation.json](asset-validation.json): hashe zdroje, RGBA masteru, PNG a raw RGBA; manifest snímků obsahuje také hash runtime manifestu |
| Import | Čerstvé samostatné Godot procesy; importované pixely ověřeny proti raw hashi. `fix_alpha_border=false` zachovává přesná RGBA data |

## 2. Změřená geometrie

| Kontrakt | Výsledek |
|---|---|
| Canvas | 800 × 800 px; viditelný obal při alfa > 25/255: x68, y196, šířka655, výška387 px |
| Měřítko | 0.2508 world px na produkční pixel; tesař 165 px × 0.2 = 33 world px |
| Fyzická zem | Zachované 4 × 2 buňky po 40 px, maska `#### / #E##`; 160 × 80 world px |
| Registrace | Skutečný jižní práh zdroje (488, 912) → produkce (311.3238, 581.8182); samostatný sort anchor zde leží na stejném místě |
| První koncept | První příliš široký pokus opraven před odvozením provozních vrstev; finálních 11 ručně odečtených kontaktů je uvnitř masky, tolerance ±3 zdrojové px |
| Zem a střecha | [footprint-check.png](footprint-check.png) odděluje konstrukční kontakty a střešní přesahy: západ 0.64, východ 3.36 world px |
| Přístup | Vstupní koridor x40–80, y80–120 vůči severozápadnímu rohu země zůstává volný; odpočívající člověk stojí u levého sloupku |
| Dveře | Světlá výška kresby 32.32 world px proti tělu 33 px. Stylizovaně těsné; původní cíl 35–38 px není splněn a není vydáván za změřený výsledek |

Půdorys, kolize ani projekce hry se kvůli obrázku nerozšiřovaly. Měření
viditelných kontaktů není rekonstrukcí skryté zadní stěny ve 3D.

## 3. Skutečná běžná herní cesta

Runner `game/tests/sawmill_life_game_runner.tscn` otevřel skutečné menu,
stiskl Novou hru a spuštění mapy Relief. Existující tesař a nosiči prošli
normální simulací bez přepsání jejich stavu, zásob nebo hodin. Den běžel
zrychlením hry, pozdější průchod do noci vykonal každý skutečný tick
v dávkách po 32. Test ukládá do vlastní dočasné pozice; hráčovy save soubory
nebyly otevřeny ani přepsány.

| Fáze | Tick | Skutečný děj a důkaz |
|---|---:|---|
| Po spuštění mapy | 0 | Tesař venku, bez domácí kopie; [initial.png](natural/initial.png) |
| Odpočinek doma | 3 | Skutečný `inside_building_id=4`, dveře a okno otevřené, samostatný odpočinek; [day-rest.png](natural/day-rest.png) |
| Výroba | 238 | Dovezená kláda spotřebována, `working/operate`, odpočinek zmizel; [actual-production.png](natural/actual-production.png) |
| Dokončená dávka | 296 | Dvě skutečná prkna a návrat k odpočinku; [produced-planks.png](natural/produced-planks.png) |
| Večer doma | 3750 | Tesař spí uvnitř, zavřené dveře, teplé okno a kouř; [night-home.png](natural/night-home.png) |
| Uložit a načíst | 3750 | Stejný obyvatel, produkční mezistav, zásoby a domácí vzhled; [loaded-night-home.png](natural/loaded-night-home.png) |

Výsledek: **6 dosažených fází, 8 snímků, 0 selhání**, návratový kód 0.
[Report](natural/report.json) obsahuje přesné stavy, hashe, rozměry a rozlišení
1280 × 800; [log běhu](natural-run.txt) je uložený vedle tohoto protokolu.
Denní odpočinek a večerní návrat prohlédl hlavní agent na skutečných snímcích.

## 4. Obrazové a stavové kontroly

| Kontrola | Výsledek a přesný rozsah |
|---|---|
| Čitelnost | Prošlo: [context.png](visual/context.png), zoom 0.75×, 1×, 2.4×; široká nízká střecha a otevřená dílna odlišují pilu od chaty |
| Alfa a filtrace | Prošlo: skutečná RGBA, [světlý/tmavý/zelený podklad](alpha-check.png), ověřený import a mipmapy; bez magentového lemu při prohlídce |
| Kontakt a výška | Prošlo v měřeném rozsahu: rovina, vyvýšená rovina 4 × 2, tři skutečné úrovně terénu; práh a postava používají stejnou výškovou projekci. Všechny možné konfigurace přilehlých svahů neověřeny |
| Řazení | Prošlo: přední strom zakrývá dílnu a její life vrstvy; spodní pixely pily srovnány s nezakrytým kontrolním vykreslením při dni i noci |
| Kotvy a hlava | Prošlo: tři skutečné směry; každý RGBA pixel tesaře od řádku79 dolů shodný, všech 96 nativních snímků drží totožný `rest_rect` |
| Výběr | Prošlo: 8 obsazených buněk, skutečná alfa mimo půdorys i alfa tesaře; prázdný okraj nepřidává jednotku ani budovu |
| Mlha a soukromí | Prošlo ve focused testech: cizí skrytá budova vrací neutrální život před čtením obyvatele; počet lookupů 0. V hlavní scéně zachované zakrytí a výběr |
| Světlo | Prošlo: denní okno tmavé, noční obydlené teplé a s kouřem; prázdný dům bez svitu a kouře. Kouř není ukazatelem výrobní aktivity |
| Čas a stav | Prošlo: skutečná práce a náklad vylučují odpočinek, osobní pauza/noc dovedou skutečného pracovníka domů, obyčejný venkovní idle jej neteleportuje; kreslení nic nesimuluje |
| Save a pravidla | Prošlo: placená stavba Builderem a dvěma Carriery, JSON roundtrip i normální večerní save/load; zachována ekonomika a geometrie |
| Běžná scéna | Prošlo: skutečná Relief s okolní osadou, bez chyb skriptů a asset warnings. Samostatné výkonnostní měření velké osady neprovedeno |

[Přehled stavů](visual/states.png) a [vizuální protokol](visual/README.md)
dokládají dalších 12 řízených nativních scénářů. Ty doplňují běžnou hru,
nejsou za ni zaměňovány. [Video rozhlížení](visual/resting-carpenter.mp4)
má 96 skutečných snímků při 8 fps, 12 sekund; [manifest](visual/capture-manifest.json)
mapuje obrazy na stav a produkční podklad. Oba finální přehledové archy
byly prohlédnuté; nebyl posuzován jen úspěch exportu.

## 5. Testy a použitelné větve

- Nová pila: **8/8 bez okna + 8/8 nativně**. Nativní spodní pixely používají
  nezávislé kontrolní vykreslení stejného spritu, RGB toleranci 0.025 a
  pozitivní kontrolu skutečné neprůhledné plošky; podrobnosti v [runtime protokolu](runtime-tests.md).
- Společný život výrobních budov: **12/12**, včetně normální produkční dávky,
  návratu domů, mlhy a skutečných importovaných obrázků tesaře.
- Dřevorubecká chata: **33/33 bez okna + 33/33 nativně**, přítomnost, stavba a zásoby.
- Úplná povinná sada: **829/829**, exit 0, bez chyb skriptů a asset warnings;
  [finální log](full-suite.txt). Dřívější chybný test nebe a jeho úzká oprava
  jsou doloženy samostatně v runtime protokolu.
- Budova/stavba: dokončení skutečné placené stavby ověřeno; nové rastry
  stavebních fází tato dodávka nezavádí, používá se existující staveniště.
- Budova/provoz: přítomnost, odpočinek, dveře, okno a kouř dodány. Zásoby
  mají oddělený stavový kontrakt a volné plochy; nové grafické vrstvy zásob
  ani animace samotného řezání nejsou součástí této verze.
- Jednotka: ověřené tři pohledy domácího odpočinku; nové chodecké/pracovní
  směrové klipy nejsou dodány. Strom/statická rekvizita: N/A.

Reprodukce běžné hry: `godot --path game --windowed --resolution 1280x800
--audio-driver Dummy res://tests/sawmill_life_game_runner.tscn`.
Focused a úplné příkazy jsou v runtime protokolu. Distribuční export hry
nebyl proveden; kontrola se vztahuje ke skutečnému projektu v editorovém runtime.

## 6. Výsledek

Integrace a uvedené nativní kontroly **prošly 2026-09-12**. Uživatel přijal
směr čistého konceptu a zadal doplnění i implementaci. Finální herní obrazy
jsou výsledkem této dodávky, dosud bez následného výslovného vizuálního
přijetí. Pila tedy není automaticky schválený etalon pro zbytek katalogu.
Známá proporční mez je těsná výška dveří; neověřené oblasti jsou výše
oddělené od prošlých kontrol. Společný vzor chování je připraven k vědomému
použití u dalších výrobních budov s jejich vlastními měřenými kotvami.
