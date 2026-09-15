# Pila v2: první nativní kontrola základu — 2026-09-12

**Prázdný základ v2 se ve skutečném vykreslení vejde do stávajících4×2 polí
a při společném pohledu má s chatou příbuzné natočení a kresbu materiálů.**
Jde o předběžný krok před odvozením zásob, práce a domácího života, nikoli o
hotovou integraci celé v2 nebo o nové uživatelské schválení stylu.

## Prohlédnuté obrazy

- [Obě budovy ve stejném záběru2.4×](flat-pair-zoom-2_4.png): výrazně lepší shoda
  stoupajících čelních hran a širokých zaoblených šindelů. Pila si zachovává
  jednu dlouhou střechu a velkou otevřenou pravou dílnu; chata má dvě hmoty.
- [Společné měřítko1×](flat-pair-zoom-1_0.png) a [0.75×](flat-pair-zoom-0_75.png):
  obě siluety se dají rozlišit i při běžném přehledu. Černý okraj je prostor
  mimo malou testovací mapu, nikoli chybějící alfa budovy.
- [Dveře a skutečný tesař33world](flat-door-human.png): výška i šířka dveřního
  pole odpovídají člověku; běžný ukazatel sytosti se záměrně vykresluje jako
  součást skutečné herní cesty vykreslení.
- [Zvýšený základ](raised-footprint.png) a [tatáž scéna s fyzickou mřížkou](raised-footprint-guide.png):
  viditelné patníky, zdivo, schod a stojany mají oporu uvnitř4×2. Nevidím
  odtržení spodku ani fyzický převis mimo zvýšenou plošinu. Oranžová buňka je
  skutečný volný venkovní přístup; cyan je technický překryv osmi buněk.
- [Zvýšené dveře a člověk](raised-door-human.png): člověk stojí na skutečně
  promítnutém svahu před vstupem, dům na rovném vrcholu. To není animace vstupu.

## Konkrétní běh

[capture.gd](capture.gd) instancuje skutečné `Main`, nastaví pouze v této QA
instanci `SawmillSpriteLibrary` na v2 manifest a zmrazí tick1750. Runtime default
zůstal v1. Celkem7 obrazů1400×720, Godot4.7.2, nativní Compatibility / Apple M4,
audio driver Dummy, bez GameSession, hudby a hráčských save souborů.

Na rovině jsou chata a pila v jednom framebufferu při stejné kameře a světle.
Ve zvýšené variantě má přesný vrchol pily výšku6 a okolní svah klesá o2 úrovně
na další vrchol. Chata je v této variantě mimo svah a mimo hlavní záběr. Skutečný
tesař vznikl běžným `spawn_worker` ve volné vstupní buňce a používá současný
vlastní civilní atlas. Kontrola skutečného vykreslovaného obdélníku potvrzuje
výšku33world; postava nebyla dodatečně zvětšena pro obrázek.

Finální proces skončil s kódem0 a [native.log](native.log) nemá chyby ani varování.
[Manifest](capture-manifest.json) má všech7 otisků snímků, fyzické prahy a chodidla,
načtené pixely i otisky souborů před a po běhu. Pila skutečně vykreslovala RGBA
`5fbf68bcf3df8c38c9e8f9d1e29494d605b425e4b986ec923ea2b81c3dee2cd1`.
Souborové otisky před a po se shodují. První neúspěšný pokus byl chybou
kontrolního skriptu: nová `ImageTexture` nemá `resource_path`, a srovnávací chata
byla na okraji sousedního svahu. [Zachovaný log pokusu](native-attempt-01.log)
se nepočítá jako úspěch. Kontrola byla opravena na skutečný hash dekódovaných
pixelů a správné umístění chaty; následující kompletní běh vytvořil všechny
finální záběry znovu. Produkční asset ani runtime se kvůli tomu neměnil.

## Rozsah a omezení

Aktuální [source04 měření](../concept-04-geometry.json) používá raw scale0.1195,
nav `(400,1032)` a uniformní1254→800 s `source_to_world=0.18731625`. Dveřní
světlé pole je přibližně35.1–35.4world vysoké a14.58world široké, s ruční
nejistotou asi0.60world.

Pevný jižní okraj produkční alfy (>25/255) leží dořádku657, tj. spodní hrana658
je ještě uvnitř nav658.373. Lanczos má několik téměř průhledných pixelů
nařádcích658–659 (nejvýše3/255), které vytvoří lem nanejvýš0.305world za fyzickou
hranicí. V prohlédnutém nativním záběru nevytvářejí viditelný přesah zdiva.
Netvrdíme tedy, že každá nenulová alfa přesně končí na kolizní hranici.

Zásoby, postava doma, otevřené dveře/okno, kouř a práce byly v tomto manifestu
prázdné a nebyly tímto krokem ověřeny. Ani skutečný průchod dveřmi, jejich
otevření, cyklus výroby či menu→hra→save/load nejsou důsledkem tohoto statického
měření. Tyto kontroly zůstávají součástí následné [celkové v2 QA](../README.md).

Reprodukce: nativní Godot, projekt `game`, `--audio-driver Dummy`,
`--script` s absolutní cestou zdejšího `capture.gd` a samostatný `--log-file`.
Volitelný `-- --output=/absolutni/cesta` zapisuje do izolovaného QA adresáře.
