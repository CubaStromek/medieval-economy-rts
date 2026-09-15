# Skladiště v2 — nativní ověření

Runner `game/tests/warehouse_game_runner.tscn` čte aktuální výchozí manifest
z `WarehouseSpriteLibrary.MANIFEST_PATH`. Report uvádí skutečné `asset_version`
a hash načtených RGBA pixelů, takže čerstvou v2 nelze zaměnit za starou cache.

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --path game --audio-driver Dummy --windowed --resolution 1280x800 \
  --log-file /Users/openclaw/AI-Projects/medieval-economy-rts/docs/art/qa/warehouse-v2/runtime/native.log \
  res://tests/warehouse_game_runner.tscn
```

Volitelný výstup: `-- --capture=/absolutní/cesta`.

Skutečná část: menu → Relief → reálné přesuny zásob → noční návrat nocležníka
po vykonání každého simulačního ticku → pauza kouře → izolované save/load.
Nečte hráčovy uložené pozice. Zvukový driver Dummy zabraňuje přehrávání hudby.

Oddělená část fixture: nová scéna Main se stejnými produkčními assety, vlastní
chata/pila/skladiště vedle sebe při 0.75×/1×/2.4×, nulové/plné zásoby,
přesné noční stavy a vyvýšené skladiště s průchozím vstupem. Referenční domy
stojí na vlastních rovných podkladech; jen sklad je na vyvýšené plošině.
Umělé stavy této části nejsou vydávány za normální gameplay.

## Výsledek — 2026-09-13

**66 kontrol, 17 evidovaných screenshotů, 0 selhání, exit 0.** Godot
4.7.2, nativní Compatibility renderer na Apple M4. K tomu vznikly tři snímky
kouře pro srovnání pauzy a postupu času. [Report](report.json) a
[nativní log](native.log) zachovávají skutečné hodnoty.

Každá zachycená budova vykazuje `asset_version: v2`. Načtené RGBA pixely
odpovídají finálnímu manifestu: zavřená varianta `b05202c8…533ee4a`, otevřená
`aab6014d…246116f`; úplné otisky jsou v reportu. Assety i sledovaný kód měly
shodné hashe na začátku a na konci běhu.

| Skutečná událost v Reliefu | Tick | Ověřený stav |
| --- | ---: | --- |
| Den po skutečných přesunech zásob | 1024 | Otevřené dveře, žádný nocležník, žádné figurky či zásoby uvnitř kresby |
| Začátek noci před příchodem | 3750 | Zavřené dveře, žádné světlo ani kouř |
| První skutečný nocležník | 3755 | Pracovník 22 uvnitř spí; zavřené dveře, obě okna svítí, kouř z komína |
| Po dalších 25 ticích a save/load | 3780 | Nocležníci 22/23/25, zachované zásoby a totožná prezentace po načtení |

Pauza zachovala identické pixely oblasti nad komínem i čas efektu. Po
25 skutečných ticích se hash téže oblasti změnil. Nulové a maximální skladové
množství ve fixture vytvořilo totožné obrazové pixely. Žádný spící host neměl
duplikát ve venkovním seznamu vykreslovaných jednotek.

Nativní záběry byly prohlédnuty: [trojice ve dne při 2.4×](fixture/day-pair-2_4.png),
[1×](fixture/day-pair-1_0.png), [0.75×](fixture/day-pair-0_75.png),
[noc se světlem](fixture/night-home-detail.png) a
[vyvýšený půdorys](fixture/raised-edge-door-approach.png).
Perspektiva skladiště odpovídá směru vlastní chaty a pily, dveře mají použitelnou
výšku, podesta i podezdívka zůstávají na vyvýšené obsazené zemi a skutečný
vstup je průchozí. Okenní rámy a příčky zůstávají viditelné; kouř začíná
u komínového otvoru. Původní chyba umístění referenční chaty na okraj svahu
ve starém v1 fixture byla odstraněna pouze úpravou tohoto testovacího terénu.

Výsledek potvrzuje dodanou integraci a prohlédnuté stavy. Neprohlašuje nové
formální schválení celého výtvarného katalogu ani testování dalších, zde
nezachycených mapových konfigurací.
