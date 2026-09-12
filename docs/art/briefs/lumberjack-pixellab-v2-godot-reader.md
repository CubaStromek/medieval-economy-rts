# PixelLab dřevorubec v2 · Godot reader a samostatná ukázka

2026-09-10. Dodávka je samostatný importér a prohlížeč animačního balíku.
Nemění hlavní scénu, pohyb, kácení, náklad, save ani herní čas.
Autoritativní budoucí napojení na simulaci popisují
[runtime notes](lumberjack-pixellab-production-v2-runtime-notes.md).
Technická kontrola není přijetím vzhledu ani důkazem fungování v běžné hře.

## Balík a import

Packer [pack_pixellab_lumberjack.py](../../../tools/pack_pixellab_lumberjack.py)
vytváří schema 1. Jeho složku `package` zkopírujte beze změny vnitřní struktury do
`game/art/units/lumberjack-pixellab-v2/`. Reader používá `manifest.json` a atlasové
PNG z `atlases/`; jednotlivé snímky a provenance lze ponechat pro kontrolu.
Žádné atlasové pořadí, ořez, zrcadlení ani počet snímků se neodhadují.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game res://tools/preview_pixellab_lumberjack.tscn -- --validate-only --require-complete
/Applications/Godot.app/Contents/MacOS/Godot --path game res://tools/preview_pixellab_lumberjack.tscn
```

`--validate-only` bez `--require-complete` připouští výslovně označený dílčí
balík. Neplatné údaje, chybějící importovaný atlas, nesouhlasící PNG hash,
prázdné či neprůhledné snímky a chybné atlasové regiony vracejí neúspěch.
Zdrojové PNG hashe se ověřují, pokud jsou PNG dostupná; v exportovaném PCK
mohou být pouze importované textury. Rozměry, regiony a alfa se ověřují i tam.
Při exportu musí být `manifest.json` zahrnut mezi exportovanými nezdrojovými
soubory (filtr `*.json`); běžný editorový import tuto exportní volbu nenahrazuje.

## Rozhraní pro budoucí vykreslování

[LumberjackAnimationLibrary](../../../game/scripts/view/lumberjack_animation_library.gd)
je samostatná `RefCounted` třída. Vlastník ji načte jednou a sdílí její textury.

```gdscript
const LumberjackLibrary = preload("res://scripts/view/lumberjack_animation_library.gd")
var animations := LumberjackLibrary.new()

func load_art() -> bool:
    return animations.load_manifest() # errors/warnings obsahují konkrétní důvod

func draw_worker(feet: Vector2, direction: String, presentation_seconds: float) -> void:
    var pose: Dictionary = animations.presentation_for(
        "walk_axe", direction, feet, presentation_seconds
    )
    if pose.has("error"):
        return # volající rozhodne o výslovném náhradním zobrazení
    draw_texture_rect(pose["texture"], pose["rect"], false)
```

| Metoda | Kontrakt |
|---|---|
| `load_manifest(path=MANIFEST_PATH)` | Resetuje předchozí data, ověří manifest a načte atlasové regiony. |
| `is_ready()` / `is_complete()` | Načtená platná data / všechny 3 klipy × 8 skutečných směrů. |
| `clip_ids()` / `clip_metadata(id)` | Dostupné klipy; metadata včetně fps, klidového snímku, nástroje a nákladu. |
| `frame_count(id, direction)` | Skutečný počet uložených snímků, žádné odvozování z požadavku API. |
| `fps(id, direction="")` | Výslovné `clips[id].directions[direction].fps`, je-li přítomno; jinak klipové `fps`. Obě hodnoty musí být kladné a konečné. |
| `frame_index(id, direction, seconds, at_rest=false)` | Index ze zadaného času a fps; při `at_rest` explicitní `rest_frame`. |
| `presentation_for(id, direction, feet, seconds, at_rest=false)` | Textura, celý obdélník, index, počet, `flip_h=false`, metadata nákladu/nástroje. |
| `presentation_frame(id, direction, feet, index)` | Přímý výběr konkrétního snímku pro kontrolu či budoucí řízení fáze práce. |
| `sprite_rect(feet)` | Pevná kotva, celé plátno, měřítko `33/body_height_source_px`. |

Směry jsou `N, NE, E, SE, S, SW, W, NW` v obrazových osách s kladným Y dolů.
Klipy jsou `walk_axe`, `chop`, `walk_log`. Obdélník se nesmí používat jako
fyzická kolize či automatický výběrový obal: obsahuje průhledné okraje plátna.
`renders_cargo="log"` značí kládu už nakreslenou uvnitř snímku; knihovna sama
nevypíná stávající obecnou kresbu nákladu. K tomu musí dojít až v budoucím
napojení rendereru podle runtime notes.

Čas patří volajícímu. Pauza zachová jeho hodnotu a tím konkrétní snímek;
`at_rest=true` je samostatná volba klidové pózy, nikoli pauza. Při pracovním
klipu může volající použít `presentation_frame` pro fázi odvozenou ze simulace.
Knihovna nepřidává bob, root motion, posuny podle alfa obalu ani zrcadlení.

Směry mohou mít různý počet fází i různá fps, ale dostávají stejný čas
v sekundách. Klipové fps je zpětně kompatibilní výchozí hodnota;
neplatný přítomný override se odmítne, nepřekryje fallbackem. Volba fps
u směru nemění počet ani pořadí PNG. Prohlížeč ukazuje skutečná fps každé
karty; ruční krok posune společný čas o interval nejrychlejšího dostupného
směru a klid zobrazí explicitní index nezávisle na fps jednotlivých směrů.

## Nativní kontrola

[Scéna ukázky](../../../game/tools/preview_pixellab_lumberjack.tscn) ukazuje
všech osm směrů, přepínání klipu, pozastavení, ruční krok, klidový snímek,
tempo, měřítko 1–4× a tmavé/zelené pozadí. Křížek je společná kotva.

`--capture=/absolutní/adresář` uloží nativní PNG pro každý dostupný klip:
čtyři fáze na tmavém pozadí při 3× a další snímek na zeleném při 1×.
Přidá `native-capture-manifest.json` s verzí Godotu, rendererem, hashi,
skutečnými indexy a výslovným `simulated_gameplay=false`. Headless režim
capture odmítá. Změna snímků ověřuje výběr fází, ne uměleckou plynulost.

První import a vykreslení readeru prošly v izolované **syntetické** fixture
mimo projekt (4 snímky, pouze jih; Godot 4.7.2, Apple M4, OpenGL Compatibility).
Ověřeno 18 podmínek včetně odmítnutí chybného hashe, regionu, výšky těla,
počtu, klidového snímku a chybějícího atlasu; následné platné načtení vždy
odstranilo předchozí chybu. Volba `--require-complete` správně skončila
kódem 1 u dílčí fixture. Samostatná nativní scéna uložila pět kontrolních PNG
a její rozložení bylo vizuálně prohlédnuto.
Tato fixture není výrobní kresba a její snímky nejsou důkazem QA nového
dřevorubce. Následující kontroly používají skutečné dodané assety.

Následně dne 2026-09-10 prošel importem, kontrolou 24 vybraných snímků,
ovládáním času a nativním vykreslením první **skutečný jižní pilot**.
Přesná data a omezení jsou v [jeho QA záznamu](../qa/lumberjack-pixellab-v2-S-pilot/README.md).
Tento historický dílčí balík zůstává beze změny v `pilot-walk-S/package`;
shoda všech dřívějších runtime podkladů byla ověřena před jeho nahrazením.
Samostatná ukázka vypíná svůj viewport stretch, aby měřítko 1× znamenalo
jeden world px na jeden pixel zachyceného obrázku. Hlavní hru nemění.

**Aktuální runtime dne 2026-09-10 obsahuje kompletní výrobní balík:**
3 klipy × 8 směrů, 439 vybraných animačních snímků a 24 uchovaných zdrojových
referencí. Manifest má SHA-256
`7aa01262a49e4e682f87c9a8445f6fc79ec1fd6f18154f34d8a11a320a43fa64`.
Import i `--validate-only --require-complete` prošly; reader ověřil 439/439
snímků bez chyb či varování. Nativní běh Godotu 4.7.2 na Apple M4 vytvořil
15 PNG a všech 15 bylo prohlédnuto: všechny činnosti a směry ve čtyřech
fázích při 3×, plus každá činnost při 1× na zeleném pozadí.

[Úplný záznam nativní kontroly](../qa/lumberjack-pixellab-production-v2/native/README.md)
uvádí provenienci, přesné snímky a omezení. Balík je skutečně načitatelný
a zobrazitelný touto samostatnou scénou; běžná hra jej stále nepoužívá.
Společná kotva je pevná, ale fyzický kontakt se zemí, kontakt sekery s kmenem
a návaznost na herní události nebyly tímto zobrazením ověřeny. Při velikosti
33 px zůstává silueta a kláda čitelná, jemný úchop už má jen několik pixelů.
Uchované reference se samy nepřehrávají jako idle; `rest_frame` indexuje
vybranou animační sekvenci. Technická úplnost není přijetí stylu uživatelem.
