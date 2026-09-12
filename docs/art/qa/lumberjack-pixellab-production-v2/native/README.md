# Dřevorubec PixelLab v2 — úplná nativní kontrola

## 1. Co přesně se ověřuje

2026-09-10 · agent animation_services. Jednotka `lumberjack-pixellab-v2`:
samostatný importovatelný balík a jeho Godot prohlížeč. Autoritativní rozsah
určuje [integrační záznam](../../../briefs/lumberjack-pixellab-production-v2-integration.md),
API popisuje [reader brief](../../../briefs/lumberjack-pixellab-v2-godot-reader.md)
a budoucí herní napojení [runtime notes](../../../briefs/lumberjack-pixellab-production-v2-runtime-notes.md).

| Údaj | Skutečnost |
|---|---|
| Balík | `game/art/units/lumberjack-pixellab-v2/`, 3 klipy × 8 směrů, 439 vybraných animačních PNG a 24 zdrojových referencí. |
| Scéna | `res://tools/preview_pixellab_lumberjack.tscn`; samostatné nové spuštění pro kontrolu, nikoli běžná herní mapa. |
| Prostředí | Godot 4.7.2-stable official, macOS, Apple M4, OpenGL Compatibility, nativní viewport 1240×880. |
| Přesná verze | Manifest SHA-256 `7aa01262a49e4e682f87c9a8445f6fc79ec1fd6f18154f34d8a11a320a43fa64`. Kód je necommitnutý WIP; jeho hashe a všech 472 souborů balíku jsou v [provenienci](package-provenance.json). |
| Původ | Skutečné PixelLab výstupy, výslovné výběry a opravy uvedené v dodacím manifestu. Zdrojové pixely se při tomto QA neměnily. |
| Kopie a archiv | Všech 472 podkladů je byte-identických s výrobním `package`. Původní runtime S-only byl před přenosem porovnán se zachovaným `pilot-walk-S/package`: všechny podklady shodné, další duplicitní archiv nebyl potřebný. `.import` jsou generovaná data Godotu. |

| Měřený kontrakt | Hodnota / důkaz |
|---|---|
| Plátno | Každý animační region je celé plátno 256×256, bez ořezu či automatického doplnění. |
| Měřítko | Společné `33/163 = 0,20245398773006135` world px / source px. Jde o referenční tělesnou výšku, ne přepočet každé pózy nebo nástroje podle obalu. |
| Registrace | Pevná kotva `(128,205)` source px; žádné posuny snímků, zrcadlení či přidaný bob. |
| Skutečná alfa | Reader ověřil viditelný obsah i průhlednost všech 439 atlasových regionů, rozměry a PNG hashe. |
| Čas | Každý směr používá své uložené fps. Kácení má 1,333… s včetně E/W 24/18 a N 12/9; chůze s kládou má 0,8 s včetně N 11/13,75. Walk-axe má více opakovaných dvojkroků v některých sekvencích; efektivní dvojkrok je 0,8 s podle předchozího QA zdrojů. |
| Kontakt a řazení | Fyzické nohy na terénu, řazení a kontakt s kmenem nejsou součástí samostatné scény. Křížek/čára ukazují obrazovou kotvu. |

Přesné počty, rychlosti a alfa meze jsou v
[timing-and-visible-bounds.json](timing-and-visible-bounds.json).
U stojícího kácení se dolní alfa mez v rámci každého směru nemění, ale mezi
směry leží na y=202 až 218, tedy −0,607 až +2,632 world px vůči y=205.
Tento rozdíl je vidět při 3×; dolní pixel obalu sám není fyzický pivot.
Nebylo to skryto automatickým posouváním snímků. Herní kontakt musí být
kalibrován ve skutečném terénu podle postoje a projekce.

## 2. Ověření běžnou herní cestou

**Neověřeno — hlavní renderer ani simulace tento balík zatím nepoužívají.**
Spuštěna byla výhradně samostatná ukázka. Žádné mapové příkazy, herní těžba,
sklady, výběr, mlha, save/load nebo hráčovy uložené hry se při tomto QA neměnily.
Čtyři časové řezy na klip jsou uměle zvolené prezentační stavy, nikoli herní
pracovní události. Shodná délka kácení nezaručuje shodný okamžik zásahu ve
všech kresbách; na událost těžby musí navázat budoucí integrace.

## 3. Společné kontroly

| Kontrola | Výsledek a důkaz |
|---|---|
| Čitelnost a měřítko | **Prošlo v ukázce s omezením.** Na 3× jsou vidět postoj, pohyb končetin a nástroj; na 1× je čitelná lidská silueta, směr a velká nesená kláda. Sekera a prsty už zabírají několik pixelů. Okolní osada nebyla zobrazena. |
| Alfa a filtrace | **Prošlo v ukázce.** Ve všech 15 prohlédnutých PNG není neprůhledný obdélník, zapečená šachovnice, nápadný lem či průsak sousedního atlasového regionu. Tmavé i zelené pozadí skutečně prosvítá kolem jednotek. |
| Kontakt se zemí | **Neověřeno ve hře.** Společná linka zachovává referenci, ale mez bot se podle postoje/směru liší; příklad a měření výše. Rovina/svahy nejsou v ukázce. |
| Řazení a terén | **Neověřeno.** Nejsou zde terénní vrstvy ani překrývající se herní objekty. |
| Kotvy a vrstvy | **Prošlo pro reader:** shodný celý obdélník a pevná kotva všech snímků; žádný náklad navíc nebo náhradní zrcadlené směry. Návaznost změn gameplay akcí neověřena. |
| Klikání, výběr, mlha, světlo/stíny, save/load, výkon osady | **Neověřeno v běžné hře.** Tato scéna poskytuje pouze ovládání ukázky; žádné z těchto herních chování se zde nesimuluje. |
| Čas | **Prošlo pro výběr snímků:** 439 snímků, wrap a rest index, směrová fps; viz validační log. Zachycené indexy při společném čase jsou ve screenshot manifestu. Ovládání pauzy/kroku/tempa bylo samostatně ověřeno v [předchozím cíleném probe](../../lumberjack-pixellab-direction-fps-probe/README.md), nikoli znovu jako herní čas. |

## 4. Větev jednotka

| Klip | Prohlédnuté nativní soubory | Konkrétní nález |
|---|---|---|
| Chůze se sekerou | [3× 00](walk_axe-dark-3x-phase-00.png), [25](walk_axe-dark-3x-phase-25.png), [50](walk_axe-dark-3x-phase-50.png), [75](walk_axe-dark-3x-phase-75.png), [1× zelené](walk_axe-green-1x.png) | Všech osm skutečných směrů, čitelné střídání nohou v řezech, jedna sekera a volná druhá ruka. Žádné prázdné karty ani rozbitý atlas. |
| Obouruční kácení | [3× 00](chop-dark-3x-phase-00.png), [25](chop-dark-3x-phase-25.png), [50](chop-dark-3x-phase-50.png), [75](chop-dark-3x-phase-75.png), [1× zelené](chop-green-1x.png) | Čitelný nápřah a sek. Opravené E/W drží jednu sekeru před tělem; nepřidávají FX. Postoj stojí stabilně. Směry mají různé pózy i okamžik úderu, přesný kontakt s kmenem ukázka neověřuje. |
| Chůze s kládou | [3× 00](walk_log-dark-3x-phase-00.png), [25](walk_log-dark-3x-phase-25.png), [50](walk_log-dark-3x-phase-50.png), [75](walk_log-dark-3x-phase-75.png), [1× zelené](walk_log-green-1x.png) | Jedna dobře čitelná kláda, směr její projekce se mění, volná ruka a nesená zátěž se v řezech nerozpadají. U W je kláda vysoko za hlavou a přesný zakrytý kontakt s ramenem zůstává omezením zdroje; na 1× jej nelze rozhodnout. |

**Všech 15 uvedených PNG bylo skutečně prohlédnuto.** Každý obsahuje všech
osm směrů: 120 nativních zobrazení, z toho 24 při 1×. Jde o čtyři řezy,
nikoli o ruční posouzení každého z 439 snímků v nativním okně nebo nepřetržitě
pozorované animace. Úplné zdrojové smyčky mají své samostatné posudky v
produkčních job/qa složkách. Budovy, stromy a statické rekvizity jsou N/A.

## 5. Důkazy a běhy

Příkazy z kořene projektu:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game res://tools/preview_pixellab_lumberjack.tscn -- --validate-only --require-complete
/Applications/Godot.app/Contents/MacOS/Godot --path game res://tools/preview_pixellab_lumberjack.tscn -- --require-complete --capture=/Users/openclaw/AI-Projects/medieval-economy-rts/docs/art/qa/lumberjack-pixellab-production-v2/native
```

| Běh | Skutečný výsledek |
|---|---|
| Import | Exit 0, [import.log](import.log). Sandbox hlásí nedostupné systémové CA a nemožnost uložit globální nastavení editoru; žádná chyba skriptu či atlasového importu. |
| Úplná validace | Exit 0, `loaded=true`, `complete=true`, 439/439, `errors=[]`, `warnings=[]`, [validate-complete.log](validate-complete.log). Stejná platformní CA zpráva nebrání načtení. |
| Nativní grafický běh | Exit 0, Apple M4/OpenGL Compatibility, 15/15 PNG, [capture.log](capture.log). Žádná chyba v nativním logu. |
| Provenience snímků | Všech 15 SHA-256 odpovídá [native-capture-manifest.json](native-capture-manifest.json), který obsahuje skutečné indexy, fps, čas, měřítko, rozměry i hash runtime manifestu. `simulated_gameplay=false`. |
| Ostatní testy hry | Nespouštěny: hlavní renderer/simulace se touto dodávkou nemění. |

Pozitivní kontrolou jsou neprázdné skutečné jednotky ve všech 24 kartách,
odlišné fáze podle zachycených časů, manifest aktuálního úplného balíku a
shoda jeho 472 souborů s předaným produkčním výstupem. Nativní capture běžel
v nové instanci po importu; nejde o screenshot starého jižního pilotu.
Měřítko 1× je 1 world px na 1 pixel PNG, bez zvětšení viewport stretch.

## 6. Výsledek této verze

| Rozhodnutí | Výsledek |
|---|---|
| Technická integrace | **Prošla v samostatném importéru a ukázce:** celý skutečný balík 24/24, 439/439. Běžná herní integrace zůstává neprovedena. |
| Vizuální kontrola | Provedena u všech 15 přesně uvedených nativních PNG; čitelnost, alfa a zobrazení fází bez základního poškození. Jemné anatomické detaily při 1× nejsou dostatečně rozlišitelné. |
| Vizuální přijetí uživatelem | **Neuděleno pro tuto přesnou verzi.** Tento posudek je technické a vizuální QA, ne schválení stylu. |
| Otevřené oblasti | Skutečný kontakt nohou/terénu, pracovní dosah a okamžik zásahu kmene, herní řazení, přechody akcí, potlačení obecného nákladu, světlo/mlha/save a výkon osady. Žádná z nich není prokázána izolovaným prohlížečem. |
| Společný výtvarný etalon | Ne; samostatná technická dodávka nedává schválení pro jinou sadu. |
