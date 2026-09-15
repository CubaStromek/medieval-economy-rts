# Skladiště v1 — koncept a následný herní pilot

Aktualizace **2026-09-13**, Codex.
[Brief](../../briefs/warehouse-v1.md) ·
[integrační záznam](../../briefs/warehouse-v1-integration.md) ·
[rozpracovaná oprava perspektivy v2](../../briefs/warehouse-v2.md).

## 1. Skutečný stav a rozsah

V1 byla po pozitivním přijetí architektury a následném výslovném pokynu
uživatele integrována do hry. Má otevřená denní a zavřená noční vrata,
dvě svítící okna a animovaný kouř podle skutečných spících nocležníků.
Vizuální zásoby a postavy uvnitř jsou N/A podle uživatele.

Následná cílená kontrola zjistila **plošší perspektivu proti chatě**.
V1 proto není schválenou shodou pohledu ani etalonem celé sady; uživatel
2026-09-13 autorizoval její opravu ve v2. Níže uvedené výsledky se týkají
v1 a nelze je přenést na rozpracované nové obrázky.

## 2. Historický koncept a produkční oprava

Původní [koncept](../../concepts/warehouse-v1.png), zdroj `concept-04.png`,
je 1254² RGB na bílém pozadí, SHA-256
`78470ea97013667ed225bf051ee0cb90b699b92b67da4e34d676248c6a19ecf3`.
[Provenance](../../sources/warehouse-v1/provenance.json) zachovává skutečné
prompty, vstupy a odmítnutý první pokus s falešnou šachovnicí. Nástroj byl
vestavěný ImageGen; konkrétní model nebyl oznámen.

Katalogový kontrakt 3 × 3, 120 × 120 world px, maska `###/###/#E#`,
dveřní pole `(1,0)` a vstup `(1,1)` byl ověřen před tvorbou.
[Ground guide s reálným člověkem](../../sources/warehouse-v1/ground-guide.png)
byl skutečným obrazovým vstupem. [Geometrie podkladu](../../sources/warehouse-v1/geometry.json)
není zaměnitelná s registrací vygenerovaného PNG.

Konceptové [měření](concept-measurements.json) a [ground-fit.png](ground-fit.png)
dokumentují starší příliš jižní kontakt šikmého prahu. Tato původní evidence
zůstává beze změny. Následný produkční zdroj přidal krátký **centrální
kamenný nástup** a opravil tento kontakt bez zvětšení herního půdorysu.
Jeho práh je `(615,1161)` ve zdroji 1254², měřítko zdroj→world **0,098**.

[Produkční export](production-export.json) zaznamenává jednotný převod
na **800 × 800 RGBA**, skutečnou alfu a společnou registraci obou stavů.
[Manifest v1](../../../../game/art/buildings/warehouse/v1/manifest.json)
vede výsledné kotvy a přesné masky okenních tabulek. `day-open.png`
mění pouze omezený otvor vrat; mimo něj bylo změněno **0 bajtů**.

## 3. Výsledky v1 k 2026-09-13

| Kontrola | Skutečný výsledek |
|---|---|
| Architektura a rozpoznatelná silueta | Uživatel návrh pozitivně přijal; valbová střecha, vikýř a nákladová vrata rozlišují sklad |
| Perspektiva vedle chaty | **K opravě ve v2**: plošší čelní i hloubkové vodorovné hrany; první obecná prohlídka tuto neshodu nezachytila |
| Produkční RGBA, registrace a dveře | Dodány oba 800² stavy se společnou siluetou a prahem; aktivní assety eviduje runtime report |
| Stavové a sprite testy | **17/17 cílených prošlo**: 7 sprite + 10 život budovy |
| Úplná headless sada | **876/876 prošlo před zahájením v2**; nejde o test nových obrázků |
| Nativní běh | **65 kontrol, 17 snímků, 1 chyba**: `Fixture places existing lumber_hut` |
| Běžná herní cesta | Skutečné menu→Relief, přesuny zboží, postup všech ticků a noční příchod nocležníků |
| Světlo a kouř | Noc se skutečnými nocležníky aktivuje obě okna a komín; den a prázdná noc efekty nemají |
| Pauza / save-load | Zaznamenán stabilní obraz kouře při pauze, změna po 25 ticích a noční stav po načtení |
| Zásoby a interiérové jednotky | N/A podle uživatele; obraz skladu se nemění při změně inventáře |
| Mlha a nedokončená budova | Cílené testy kryjí neutrální cizí stav před čtením obyvatel a absenci dokončených efektů při stavbě |
| 0.75× / 1× / 2.4× a vyvýšený základ | Snímky existují; izolovaná srovnávací fixture má chybu umístění chaty, proto není celá trojice odškrtnuta jako úspěšná |
| Nová stavební obrazová sada | N/A, nebyla zadána; zachována stávající stavební prezentace |

## 4. Důkazy a hranice interpretace

Nativní [report.json](runtime/report.json) a [log](runtime/native.log)
obsahují skutečné výsledky, chybu fixture, stavy a otisky v1 před i po běhu.
[Popis runneru](runtime/README.md) rozlišuje přirozenou herní cestu
od ručně nastavené izolované scény. Počet kontrol neznamená počet
nezávislých úspěšných vizuálních porovnání.

- [Den, otevřená vrata vedle chaty v normální hře](runtime/natural/day-open-2_4.png).
- [Noc před příchodem](runtime/natural/night-away.png),
  [noc se skutečnými nocležníky](runtime/natural/night-home.png)
  a [stav po načtení](runtime/natural/loaded-night-home.png).
- [Detail obou oken a komína](runtime/fixture/night-home-detail.png) je
  izolovaná stavová fixture, nikoli doklad přirozeného příchodu.
- [Kouř před pauzou](runtime/motion/smoke-before.png),
  [při pauze](runtime/motion/smoke-paused.png) a
  [po 25 ticích](runtime/motion/smoke-after-25-ticks.png).
- [Vyvýšený půdorys a přístup](runtime/fixture/raised-edge-door-approach.png)
  pocházejí z oddělené fixture.

Přirozený běh nepřepisoval hráčovy save; použil vlastní dočasný soubor.
Noční stav sleduje skutečné `sleep_home_id`, `inside_building_id`,
vlastnictví a `world.is_worker_sleeping()`. Nepřidává obyvatele ani
neodvozuje efekt z návštěvy nosiče, zboží či pouhého začátku noci.
Samostatný `WarehouseLife` skutečně vykresluje dvě okna a komín;
nejde již o nezapojený plán pro jedno okno výrobního helperu.

**Výsledek v1:** implementovaný funkční pilot s doloženým chováním;
neshodná perspektiva a chyba srovnávací fixture zůstávají výslovně
zaznamenané. Následná v2 má vlastní ověření, které tento historický
záznam ani původní snímky nezmění.
