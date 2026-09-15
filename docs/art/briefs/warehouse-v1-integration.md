# Implementační záznam: skladiště v1

Datum **2026-09-13** · ID `warehouse` · stav **herní pilot integrován;
perspektiva k opravě v rozpracované [v2](warehouse-v2.md)**.
[Brief](warehouse-v1.md) · [QA](../qa/warehouse-v1/README.md) ·
[šablona záznamu](../object-integration-template.md).

## 1. Rozsah a rozhodnutí

Uživatel po pozitivním přijetí architektury autorizoval implementaci
otevřených denních a zavřených nočních vrat, světla v obou oknech a kouře.
Výslovně vyloučil vizuální zásoby a interiérové postavy. V1 tento rozsah
zapojuje do normální hry bez nového obyvatele, receptu, stavební obrazové
sady nebo změny simulace, katalogové kolize, kamery a formátu save.

## 2. Geometrie a registrace

Herní maska a vstup zůstávají podle [briefu](warehouse-v1.md).
[Podklad](../sources/warehouse-v1/geometry.json) předchází konceptu;
[produkční export](../qa/warehouse-v1/production-export.json) měří skutečný
výsledek. Starší šikmý práh konceptu opravil centrální kamenný nástup.
Zdroj 1254² má práh `(615,1161)` a měřítko 0,098 world px na zdrojový px.
Export 800² je jednotný v obou osách a pro oba dveřní stavy.

[Manifest v1](../../../game/art/buildings/warehouse/v1/manifest.json)
vede výsledný práh, měřítko, samostatnou hloubkovou a popiskovou kotvu,
obě okna, přesné masky jejich tabulek a ústí komína. Alfa maska odvozená
z importované bitmapy slouží výběru mimo obsazenou zem. Kouř a světelný
přesah nemají vlastní klikací obdélník. Výška terénu, fyzický práh,
registrace obrazu, řazení a stín zůstávají oddělené veličiny.

## 3. Produkční vrstvy a čtenáři

`game/art/buildings/warehouse/v1/finished.png` a `day-open.png` jsou
skutečné **800 × 800 RGBA**. Liší se pouze v omezeném otvoru vrat;
mimo něj export eviduje nula změněných bajtů. Rozměry, silueta a registrace
se při přepnutí nehýbou. Původní RGB koncept není runtime textura.

`WarehouseSpriteLibrary` načítá obě varianty a jejich alfa masky.
`main_view.gd` ji používá pro normální kreslení, výběr, zakrytí a stavbu.
Samostatný `WarehouseLife` čte skutečné nouzové noční ubytování; nepřebírá
předpoklad výrobního pracovníka z `ProductionBuildingLife`.

Dveře sledují den/noc nezávisle na přítomnosti. Světlo a domácí kouř
vyžadují fyzicky přítomného spícího nocležníka se správným `sleep_home_id`
a vlastníkem. Dvě samostatné okenní masky zachovávají původní příčky.
Pauza zmrazí simulační čas efektů, neodstraní je. Nedokončená a cizí
soukromá budova efekty neprozradí. Žádné skladové sloty ani osoby uvnitř
se nekreslí; stavová matice a důvody výjimek zůstávají v briefu.

## 4. Původ a evidence

Vestavěný ImageGen, vlastní chata a pila jako prohlédnuté reference,
vlastní ground guide. Historický konceptový původ:
[provenance.json](../sources/warehouse-v1/provenance.json).
Produkční zdroje a zadání v `docs/art/sources/warehouse-v1/`, skutečné
převody a otisky v [production-export.json](../qa/warehouse-v1/production-export.json).
První falešná šachovnice není produkční alfa. Starší konceptové měření
se nepřepisuje výsledkem následné opravy prahu.

## 5. Ověření a omezení

Před perspektivní revizí v2 dne 2026-09-13 prošlo **17/17 cílených**
(7 sprite + 10 život budovy) a **876/876 úplných headless testů**.
Nativní [report](../qa/warehouse-v1/runtime/report.json) zaznamenal
**65 kontrol, 17 snímků a 1 chybu** `Fixture places existing lumber_hut`.
Není to úplný úspěch nativní srovnávací scény.

Normální menu→Relief část skutečně vykonala simulační ticky, pozorovala
zásobování a noční příchod, provedla vlastní dočasný save/load a ověřila
pauzu kouře. Druhá část s ručně nastavenými stavy a vyvýšeným půdorysem
je výslovně izolovaná fixture; její chybné umístění chaty omezuje porovnání
celé trojice. Hráčovy uložené pozice nebyly použity.

Následný vizuální audit zjistil plošší perspektivu skladiště proti chatě.
Uživatel autorizoval opravu ve [v2](warehouse-v2.md); tato revize není
pokryta výsledky v1. Architektura v1 byla pozitivně přijata, shoda její
perspektivy ani použití jako etalonu sady schváleny nejsou.
