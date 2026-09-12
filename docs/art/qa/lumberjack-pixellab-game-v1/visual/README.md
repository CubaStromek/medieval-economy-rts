# Dřevorubec ve hře — umělé vizuální kontrolní stavy

**2026-09-10, agent animation_services. Prošlo: 22 nativních PNG,
0 selhání runneru.** Jde o výslovně uměle nastavené stavy ve skutečné
`res://scenes/main.tscn`, přes produkční renderer jednotek, řádků terénu,
stromů, světla a stínů. Tento běh nedokládá přirozený ekonomický cyklus.
Ten má samostatné důkazy podle
[integračního záznamu](../../../briefs/lumberjack-pixellab-game-v1-integration.md).

## Ověřená verze a reprodukce

[Report](report.json) obsahuje všech 22 názvů a SHA-256 snímků, skutečně
vybrané klipy, směry, indexy fází, FPS, tick, logickou polohu, obrazovou
kotvu a bod řazení. Zaznamenává také shodné počáteční a koncové otisky
šesti produkčních souborů včetně `solar_shadows.gd`; renderer se během
finálního snímání nezměnil. Čas dokončení: **19:12:29 UTC**. Tento běh
již používá relativní souřadnice při kreslení stínových odřezků.

Nový samostatný proces Godotu 4.7.2 stable, macOS, Apple M4, OpenGL/Metal
Compatibility, okno 1600 × 1000. Použitý příkaz z kořene projektu:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path game --log-file /private/tmp/lumberjack-visual-native.log res://tests/lumberjack_visual_runner.tscn
```

[Nativní log](native.log) má návratový kód 0 a neobsahuje chybu skriptu ani
triangulace. Snímky pocházejí přímo z viewportu bez domalování nebo úprav
pixelů. Aktuální runtime balíček je
`game/art/units/lumberjack-pixellab-v2/`; otisk manifestu je v reportu.
Původ a kalibraci podkladů definuje
[produkční záznam](../../../briefs/lumberjack-pixellab-production-v2-integration.md).

## Umělé stavy a rozsah

Izolovaný svět 22 × 18, osm jednotek ve dvou řadách. Pořadí podle ID je
N, NE, E, SE / S, SW, W, NW; jejich interpolovaná poloha řady mírně posouvá.
Runner zadává polohy, příchozí směr, náklad, pracovní postup, tick a výšky.
Simulace stojí a vyhlazování kamery je vypnuto pouze pro okamžité QA přesuny.
Žádná uložená hra se nemění. Kácení používá skutečné dospělé stromy v tomto
světě a skutečný produkční výběr klipu i kontaktního postoje.

| Kontrola | Výsledek a prohlédnutý důkaz |
|---|---|
| Všechny dodané větve | **Prošlo:** `all8-{walk_axe,chop,walk_log}-{0_75,1_0,2_4}.png`, tedy 24 kombinací klip/směr při třech zoomech. |
| Měřítko a alfa | **Prošlo v zachycených fázích:** společné měřítko těla 33 světových px, průhledný canvas, bez viditelných obdélníků, šachovnice nebo duplicitního nákladu. Při 2,4× jsou zbraně a náklad čitelné; při 0,75×/1× jemné ruce splývají a kontrast hnědé postavy proti detailní trávě je slabší. |
| Kontakt při kácení | **Prošlo v pracovním a přípravném vzorku:** `all8-chop-2_4.png` a `all8-chop-windup-2_4.png`. Všech osm postojů je u vlastního kmene; E stojí vlevo od kmene, W vpravo. Čepel směřuje do oblasti kmene a obě zachycené fáze mají stejnou základnu. Nejde o měření kontaktu v každé fázi cyklu. |
| Terén a kotvy | **Prošlo ve vzorku:** obě `raised-slope` PNG. Horní řada používá skutečnou interpolovanou výšku sestupného svahu, dolní rovinu. Nevidím utržené boty ani obdélníkový ořez. Tato dvojice nenahrazuje kontrolu všech reliéfů. |
| Světlo a UI | **Prošlo:** denní a `all8-walk_log-night-2_4.png`; osoby i náklad v noci skutečně tmavnou, UI uvádí 23:00/Night. Panely nezakrývají žádnou z osmi osob; horní pravý panel může překrýt korunu stromu. Ukazatele nad osobami jsou nad kresbou, u kácení leží před korunou. |
| Fog a indoor | **Prošlo měřením:** skryté osoby nemají sprite, náklad ani stín navíc proti světu bez osob. Pozitivní kontroly níže. |
| Přechody, klikání, save, ekonomika a výkon | **Neověřeno tímto statickým runnerem.** Patří zaměřeným testům a přirozenému hernímu běhu v hlavním integračním záznamu. |

## Nezávislé pixelové kontroly

**Spodek bot na hranici řádku:** `flat-boundary-actual.png` zachycuje skutečnou
NW fázi s indexem 1. Alfa zasahuje ze zdrojové kotvy y=205 až k exkluzivnímu
spodku y=221, tedy **3,23926 světového px pod kotvu**. Umělý seed ušlé
vzdálenosti 4 px je výslovně uveden v reportu. Srovnávací
`flat-boundary-unobstructed-reference.png` volá stejnou produkční kresbu,
se stejným filtrem, světlem a transformací, ale nad řádky terénu. V ROI
**x=947, y=501, šířka=60, výška=11** je rozdíl **0 pixelů, tolerance 0**.
Pozitivní `flat-boundary-no-sprite-control.png` má v témže ROI rozdíl
**170 pixelů**: kontrolovaná oblast skutečně obsahuje spodní část osoby.
Stabilní hloubkový přesah 3,5 px tedy tento konkrétní spodek chrání.

**Fog:** osm viditelných osob v `visibility-positive-outdoor.png`, potom
cizí osoby v prozkoumané mlze. `visibility-fog-hidden.png` a
`visibility-fog-empty-control.png` mají v celé mapové oblasti rozdíl **0**.

**Indoor:** `visibility-indoor-outside-control.png` ukazuje osoby uměle
sesazené na stejný skutečný vchod. Kamera i poloha zůstávají stejné při
nastavení `inside_building_id`; změna má **3320 viditelných pixelů**.
`visibility-indoor-hidden.png` proti `visibility-indoor-empty-control.png`
má rozdíl **0**. Tato pozitivní kontrola dokládá fyzické skrytí obrazu;
nástup všech osmi osob do budovy nebyl simulován.

## Závěr této kontroly

Všech 22 finálních snímků má totožný SHA-256 s již vizuálně posouzenou
sadou z 19:08:23 UTC. Oprava souřadnic stínů tedy v těchto případech
nezměnila žádný pixel a všechny pozitivní i negativní kontroly znovu prošly.
V uvedeném rozsahu není otevřená doložená vada řazení nebo integrace.
Omezení čitelnosti při oddálení a vzorkování kontaktu jsou uvedena výše.
Výsledek neznamená vizuální přijetí uživatelem ani schválení společného
výtvarného etalonu. Budovy, konstrukce a růstové větve jsou zde N/A;
strom slouží jako skutečný kontaktní objekt kácení.
