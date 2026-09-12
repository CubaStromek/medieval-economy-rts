# QA — rozšířený půdorys dřevorubecké chaty v2

Datum **2026-09-10**, ověřil Codex. Změna geometrie stávající vlastní kresby,
ID `lumber_hut`. Autority: [integrace v2](../../briefs/lumber-hut-footprint-v2-integration.md),
[stavební brief](../../briefs/lumber-hut-construction-v1.md),
[zásobní integrace](../../briefs/lumber-hut-stock-v1-integration.md).
Výtvarný směr zůstává v0.2 bez uživatelského schválení etalonu.

## 1. Rozsah a měření

Nové chaty obsazují devět polí v obalu 4 × 3, maska
`.### / .##E / ###.`. Volný jihovýchodní zářez je venkovní vstup.
V porovnávacím světě má původní v1 kotvu `(14,12)`, nová v2 `(13,13)`;
obě mají fyzické dveřní pole `(16,12)` a vstup `(16,13)`.
Naměřený obdélník bitmapy se shoduje přesně, včetně všech 33 stavebních kroků.

Pět kontaktních bodů uvedených v integraci leží uvnitř skutečných polygonů
obsazené země na rovině a na vyvýšeném srovnaném základu: **10/10**.
Hodnoty obsahuje [manifest](capture-manifest.json). Jde o měřené kontakty,
nikoli tvrzení o každém pixelu na libovolném svahu. Střešní přesahy se
nepřevádějí na další obsazenou zem. První koncept před výrobou variant je
N/A: tato oprava nevyrábí novou kresbu.

Canvas 640 × 640, práh `(568,410)`, měřítko `0.225` a samostatný bod řazení
zůstávají podle původního manifestu. **13 obrazových souborů a manifestů má
shodný SHA-256** s dokončenou zásobní opravou, viz
[otisky zachovaných podkladů](verification/preserved-art.sha256).
Žádný PNG ani stavební maska nebyly upraveny či generovány.

## 2. Běžná herní cesta

Nativní běh otevřel hlavní menu, vybral Relief a sledoval skutečného
dřevorubce: cesta se sekerou, kácení, sebrání klády, cesta s nákladem,
předání do vlastní chaty v ticku **117**. **7 fází, 17 snímků, 0 selhání**;
[záznam běhu](natural/report.json), [předaná kláda](natural/09-delivered-2_4x.png).
Zásoba se zvětšila až po fyzickém předání, nikoli při rezervaci stromu.
Testovací session používá dočasný slot; hráčovy uložené hry se nepřepisují.

Druhý běh používá skutečnou scénu `main.tscn` s pozastavenými QA světy.
Stavební práce, počty klád a světelné kontexty v něm jsou výslovně nastavené
vzorky. Skutečný pohyb pracovníků a placená výstavba jsou ověřené samostatně
v testech, nikoli odvozené z těchto obrázků.

V QA světě bylo myší najeto na kotvu `(6,19)` a skutečně kliknuto.
Umístěných devět polí i vstup se přesně shodují s předchozím náhledem:
[náhled](placement-preview.png), [po kliknutí](placement-committed.png),
[stejná poloha s nastaveným dokončením](placement-finished-fixture.png).

## 3. Prohlédnuté nativní snímky

Godot **4.7.2**, macOS, Compatibility / OpenGL 4.1 Metal, **Apple M4**.
Nové procesy načetly aktuální zdroje; žádný starý běžící svět nesloužil jako důkaz.
Celkem **61 snímků včetně šesti přehledových archů**, seznam a otisky
jednotlivých rámců v manifestu.

| Kontrola | Výsledek a konkrétní důkaz |
|---|---|
| Půdorys, patky, stojan a průchod | Prošlo — [detail](footprint-complete.png), původní [v1](frames/footprint-v1-logs-6.png) a nová [v2](frames/footprint-v2-logs-6.png) při stejné kameře |
| Člověk a měřítko | Prošlo — detail 3.2×, vzorky [0.75×](frames/zoom-0-75.png), [1×](frames/zoom-1-00.png), [celá hra](game-complete.png); žádné zmenšení domu |
| Průhlednost a spodní části | Prošlo v zobrazených podmínkách — patky a stojan neusekává rovný terén; podklady mají nezměněnou skutečnou alfu |
| Zvýšený základ a okolní svah | Prošlo pro ověřenou plošinu — [kontakty](frames/raised-contacts.png); další libovolné sklony nejsou schválený výtvarný etalon |
| Den, soumrak, noc, překrytí stromem | Prošlo — [kontexty](contexts.png); společné tónování zachované |
| Mlha | Prošlo — prozkoumaný cizí dům a skryté neznámé území v kontextech; soukromé zásoby zvlášť v nativních testech |
| Obrazové kotvy a stavební stavy | Prošlo — prohlédnut stav 0 a všech 33 změn na arších níže, nezměněný obdélník a dveře |
| Zásoby a klikání | Prošlo — šest klád v detailu; nativní test kontroluje každý jednotlivý skutečný konec klády 1–6 proti nule i noční tónování; prázdný stojan v2 nadále patří obsazené zemi |

Prohlédnuté stavební archy: [0–7](stages-00-07.png), [8–15](stages-08-15.png),
[16–23](stages-16-23.png), [24–31](stages-24-31.png), [32–33](stages-32-33.png).
Tato kontrola potvrzuje registraci nové geometrie. Původní dílčí výtvarné vady
maskované výstavby, například malé oddělené fragmenty v kroku 9, se touto
změnou neopravují ani neprohlašují za schválené.

## 4. Simulace a kompatibilita

Prošlo: nová přidaná zem odmítá překrývající se stromy/stavby, vstup zůstává
průchozí a chráněný, příprava země zahrne přidanou patku, zrušení uvolní
všech devět polí. Skuteční nosiči dodají 3 prkna a 2 kameny a stavitel
dokončí 120 pracovních ticků. Dřevorubec a nosič přenesou kládu přes zářez
bez vstupu do blokovaných polí. Obě ukázkové mapy mají propojené cesty ke
všem vstupům; ekonomická mapa má 35 budov a 262 obsazených polí.

Save v21 uchová směs půdorysů 0/1/2. Přeplněný starší save v20 zachová
šestipolíčkovou chatu, dveře i okolní objekty. Chybné či nepodporované
geometrie se odmítnou před změnou běžícího světa. Staré chaty nejsou
automaticky rozšířeny; jejich původní nesoulad kresby a země tím zůstává.

Stromy, rekvizity a jednotkové klipy jsou N/A jako samostatné dodávky této
opravy; sousední strom a člověk slouží pouze jako kontrola překrytí/měřítka.

## 5. Testy a reprodukce

| Běh | Výsledek |
|---|---|
| Nová sada geometrie, dopravy, konstrukce a save | **12/12**, [log](verification/footprint-tests.log) |
| Nativní konstrukce, klády, pointer, Relief a svah | **41/41**, [log](verification/native-regressions.log) |
| Úplná sada projektu | **755/755**, bez chyb skriptů, [log](verification/full-suite.log) |
| Nativní vizuální fixture | **61 snímků, 10/10 kontaktů**, [log](verification/native-capture.log) |
| Běžné menu → těžba → doručení | **7 fází, 17 snímků, 0 selhání**, [log](verification/natural.log) |

Reprodukce z kořene projektu:

```sh
godot --headless --path game res://tests/lumber_hut_footprint_runner.tscn
godot --headless --path game res://tests/test_runner.tscn
godot --path game --windowed --script /Users/openclaw/AI-Projects/medieval-economy-rts/docs/art/qa/lumber-hut-footprint-v2/verification/native-regressions.gd
godot --path game --windowed res://tools/preview_lumber_hut_footprint.tscn
godot --path game --windowed res://tests/lumber_hut_stock_game_runner.tscn -- --capture=/absolute/QA/directory
```

Headless prostředí hlásí omezený přístup k uživatelskému logu/certifikátům;
chyby skriptů, neprovedené větve a negativní výsledky se nepovažují za úspěch.
Nativní testy kontrolují skutečné pixely, nikoli jen metadata prezentace.

## 6. Výsledek verze

Geometrie, obrazy, běžný vstup a logistika byly ověřeny výše. Závěrečná úplná
sada prošla 755/755, nativní regrese 41/41. Ověřený necommitnutý kód identifikují
[otisky](verification/code.sha256). Stylový etalon ani univerzální usazení na všech svazích
nejsou touto opravou schválené. Budoucí generované objekty musí sedět do
svého stanoveného půdorysu už v prvním konceptu podle postupu v1.1.
