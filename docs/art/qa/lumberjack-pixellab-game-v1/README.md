# Herní QA dřevorubce PixelLab v1

Datum **2026-09-10** · objekt `lumberjack`, jednotka · ověřil Codex a dva
nezávislí agenti. [Integrační záznam](../../briefs/lumberjack-pixellab-game-v1-integration.md)
obsahuje autority, původ a přesné registrační/časové kontrakty.

## 1. Ověřovaná dodávka

Tři klipy × osm skutečných směrů, **439 zdrojových fází**, shodné s
[produkčním balíkem](../../animations/lumberjack-pixellab-production-v2/README.md).
Manifest SHA-256: `7aa01262a49e4e682f87c9a8445f6fc79ec1fd6f18154f34d8a11a320a43fa64`.
Každý zdroj má 256 × 256 RGBA; společná kotva (128,205), měřítko 33/163.
V této integraci se obrázky negenerovaly ani nepřekreslovaly. Import tří
atlasů používá mipmapy, data jsou sdílená mezi instancemi scény.

Godot **4.7.2**, macOS, OpenGL Compatibility, Apple M4; nativní okno
1600 × 1000 pro osmisměrné QA, 1280 × 800 pro normální herní průchod. Kontakty a čitelnost jsou prohlédnuté při 0,75×, 1× a 2,4×.
Nové testovací procesy načítají aktuální projekt; manifesty snímků obsahují
otisky kódu i podkladů. Necommitnuté změny jsou identifikované těmito otisky a [souhrnem kódu](verified-code.json).

Logická mapová poloha zůstává autoritou simulace. Samostatný kontaktní bod
posouvá při práci kresbu uvnitř stejné buňky, výška se vzorkuje v tomto bodě.
Stín přijímá stejný kontakt. Pouze vizuální hloubka přidává 3,5 world px
kvůli naměřenému dosahu podrážek 3,24 world px pod společnou kotvou.
Zdrojové kotvy, alba ani kolizní pravidla se podle snímku nepřepočítávají.

## 2. Skutečná běžná hra

Reprodukce vede přes **game_session.tscn → New Game → Relief → Start**.
Na původní mapě 28 × 22 sleduje skutečného pracovníka **19**, chatu **2**
na (11,14) a strom **13** na (3,13). Svět, cesta ani pracovní stavy se
pro tento běh nevyrábějí; runner pouze řídí menu, kameru a pořizuje snímky.
Při skutečné těžbě klesne zásoba stromu 5 → 4 a po cestě a vstupu do chaty
vzroste její výstup 0 → 1. Log je součástí spritu podle fyzického nákladu,
generický symbol se nezdvojuje. Po vstupu osoba ani její stín nejsou venku.

První běh [natural](natural/) prokázal nesprávný kontakt W sekery:
postava stála uprostřed stromu a sekala vedle. Oprava pracovního odstupu
je ověřena v navazujícím běhu. Historický vadný náhled zůstává důkazem nálezu,
není aktuálním výsledkem.

Druhý běh odhalil nesouvisející numerický okraj stínů dalšího pracovníka 24:
v ticku 87 vznikl na hranici řádku 17 odřezek vysoký 0,00397 world px.
[Přesná diagnostika](natural-contact-v3-probe/report.json) obsahuje jeho tři
vrcholy. První práh plochy nebyl dostatečný: [další běh](natural-contact-v3/report.json)
zachytil druhý trojúhelník s plochou 0,010448 px². Přesná reprodukce prokázala
ztrátu numerické přesnosti při triangulaci absolutních mapových souřadnic.
Renderer nyní kreslí stejné vrcholy relativně k prvnímu bodu a vrací je
na místo transformací kreslicího plátna; žádný takový platný stín se nezahazuje.
Regrese používá oba přesně zachycené vadné trojúhelníky, ověřuje jejich
platnost v lokálních souřadnicích a přesné obnovení všech původních vrcholů.
Blízký nezávislý platný trojúhelník se ověřuje v obou orientacích.

## 3. Společné kontroly

| Kontrola | Výsledek a konkrétní důkaz |
|---|---|
| Čitelnost / měřítko | Prohlédnuté všechny 24 kombinace v běžném MainScene při třech zoomech; [visual](visual/). Výška člověka se nemění podle sekery/klády. |
| Alfa / filtrace | Skutečné zdrojové masky všech 439 fází, bez černého/šachovnicového podkladu; mipmapy v nativních snímcích. |
| Zem / pracovní kontakt | Osm pevně prohlédnutých kontaktních bodů čepele, rovina, zvýšená a šikmá zem; plynulý příchod a odchod ve všech osmi směrech. |
| Řazení / spodní pixely | Nezávislá nativní nezakrytá reference a pozitivní kontrola bez spritu, popis níže. Sousední střechy a koruny nadále zakrývají osobu podle pořadí. |
| Klikání | Skutečný neprůhledný pixel aktuální animace vybírá osobu, průhledné okraje ne; neprůhledná koruna vpředu blokuje výběr a její otvor jej dovolí. |
| Mlha / interiér | Pixelové porovnání se světem bez pracovníka, skutečný vstup/výstup, cizí osoba na prozkoumaném místě; bez kresby, ukazatelů i klikacího cíle. |
| Světlo / stín | Rodičovské tónování zůstává aktivní, umělý noční obraz ověřuje vzhled; skutečný cyklus dne a HUD kontroluje stávající rozšířená solar sada. Stín sleduje kontakt, ne hloubkovou rezervu. |
| Čas / stav | Pauza zmrazí fázi i obdélník. Směr a náklad drží krokovou fázi. Kreslení neprovádí práci; zpomalený produktivní tick fázi drží. |
| Save/load | Skutečná cesta MainScene._load_game s izolovaným souborem zachová náklad a buňku, resetuje historii. Původní save neukládá rozpracovanou pózu ani pracovní offset; identická póza po load se neslibuje. |
| Výkon / kompatibilita | Jedna sdílená sada atlasů a připravené alfa masky; žádný readback GPU při kliknutí. Ostatní profese a fallback zachovány, terénní cache neregeneruje animace. |

Stavební fáze, výrobní vrstvy budov a statické rekvizity: **N/A**, jde o jednotku.
Stromy používají stávající kresbu/růst/těžbu; změněn je pouze alfa hit-test
přední koruny při výběru osoby. Hudba: **N/A**, projekt nemá hudební stopu;
efekty se kvůli této kontrole nevypínaly.

## 4. Nezávislé obrazové kontroly

[visual/report.json](visual/report.json) rozlišuje uměle nastavené QA stavy
od normálního pracovního cyklu. Kontrola spodní hrany používá skutečný
`walk_axe/NW`, frame index 1 (zdroj raw2), jehož alfa dosahuje y=221.
Porovnává stejné vykreslení včetně filtrace/světla s nezakrytou referencí
na ROI obrazovky (947,501,60,11). Výsledek je **0 odlišných pixelů**. Žádný test nesmí projít na prázdné ploše:
samostatný render bez spritu dal **170 odlišných pixelů** právě pod kotvou.

Skryté stavy se porovnávají se stejnou mapou bez jednotek. Kamera QA má
vypnuté vyhlazování, aby oba nezávislé obrazy vzorkovaly stejná místa;
produkční kamera není kvůli snímání upravená.

## 5. Závěrečné běhy

| Běh | Skutečné pokrytí a výsledek |
|---|---|
| `./tests/run-headless.sh` | **735/735 prošlo**, návratový kód 0, [úplný log](headless-regression.log). Z toho nové knihovní případy 6, prezentační stav 10, MainScene integrace 13 a jeden nový případ stínu; ostatní jsou skutečně zopakované regrese. |
| Nativní MainScene osmisměrné QA | **22 PNG, 0 selhání**, [záznam a prohlídka](visual/README.md). Boty: 0 odlišných pixelů od nezakryté reference, pozitivní kontrola 170 pixelů; interiér: 0 odlišných pixelů od prázdné kontroly a pozitivní venkovní kontrola 3320 pixelů. |
| Finální běžná hra | [natural-contact-v4/report.json](natural-contact-v4/report.json): **7 skutečných fází, 17 stavových PNG, 60 po sobě pozorovaných animačních snímků, 0 selhání**, žádná neplatná kreslená geometrie stínů. [Nativní log](natural-contact-v4/run.log) bez chyb. |
| Rychlá běžná simulace 4× | [natural-fast4x/report.json](natural-fast4x/report.json): 7 skutečných fází včetně předání v ticku 94, 0 selhání, logický headless běh bez obrázků. |

Úplný headless běh a editor import nemají chyby skriptů; omezené prostředí
hlásí macOS systémové certifikáty, import navíc nemůže ukládat globální
nastavení editoru. Tyto zprávy jsou v přiložených nezkrácených logách.
Hráčovy uložené hry se nepřepisují. Native QA i úplné testy běžely nad
finální opravou relativních souřadnic stínu.

[Animovaná ukázka skutečného sekání](natural-contact-v4/chop-excerpt.apng.png)
pochází z 60 skutečně vykreslených pozorování, ne z opětovně spuštěné
simulace nebo vymyšlených stavů. Je to krátký výňatek práce; tempo a délku
včetně poslední výdrže dokládá přiložený záznam exportu.

## 6. Přijetí a meze

**Technická integrace prošla k 2026-09-10** v uvedeném rozsahu. Prohlídku
všech osmisměrných stavů a normálního cyklu provedli root a nezávislí agenti.
Aktuální záběry sekání a chůze s kládou se shodují s uvedenými stavy.

Vizuální přijetí uživatelem této herní verze: **neuděleno**; požadavek na
implementaci není tvrzením o schválení nového výtvarného etalonu. Postava
využívá dodané dvourozměrné fáze, které se nemění na fyzikální 3D model.
Přesný úchop zadní ruky je v některých směrech zakrytý a drobné rozdíly kresby
zůstávají vlastností dodané sady. Běžný pracovní cyklus a všechny směry se
hodnotí podle doloženého rozsahu, nikoli jako důkaz každého terénu celé hry.
