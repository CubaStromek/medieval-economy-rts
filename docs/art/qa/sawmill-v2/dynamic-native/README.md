# Pila v2: nativní stavové vrstvy — 2026-09-12

**Kompletní kandidát v2 prošel vizuální kontrolou zásob, domácího života a práce
ve skutečném Main.** Z této kontroly nevzešel výtvarný ani kontaktový blocker.
Vzniklo94 stavových/pohybových snímků a další2 společné záběry s chatou. Oba
nativní procesy skončily0, finální logy jsou bez chyb i varování.

## Co bylo skutečně prohlédnuto

- [Život a práce](activity.png): čisté otevření dveří a levého okna bez zbytků
  starých pantů či kliky; odpočinek opřený o levý sloup; při práci druhá postava
  u stolu; doma v noci světlo a komín, při nepřítomnosti zavřeno. Zásoba a
  rozpracovaná kláda zůstávají nezávislé na přítomnosti tesaře.
- [Všech35 kombinací zásob](stocks.png):0–4 klády a0–6 prken skutečně vytvořily
  35 rozdílných nativních obrazů. Každý záznam obsahuje aktuální množství a cesty
  skutečně načtených vrstev; počet nakreslených log/plank vrstev odpovídá zásobě.
- [Měřítko a okolí](context.png):0.75×,1×,2.4×, zvýšený základ4×2, strom vpředu
  a noc při plných skladech. Nohy, stojany a zásoby se vejdou na obsazenou zem;
  přístup ke dveřím zůstává volný. Strom zakrývá příslušné přední části dílny.
- [Šest skutečných pracovních póz](work-contact-native.png): ruce, list pily a
  kláda drží kontakt; chodidla zůstávají na stejném místě. Jde o výřezy skutečných
  nativních obrazů, jednotně zvětšené pro kontrolu, nikoli o nové kresby.
- [Video pracovního cyklu](work-cycle.mp4):40 snímků /40fps, jedna produktivní
  sekunda, obraz640×460 při kameře4×. Je to řízené vzorkování produktivních hodin,
  nikoli záznam reálného plynutí času. Detailní záběr záměrně soustředí pozornost
  na pracovní kontakt; celá střecha je ověřena v menších výše uvedených měřítkách.
- [Plné sklady vedle chaty2.4×](full-pair-zoom-2_4.png) a [1×](full-pair-zoom-1_0.png):
  stejné zboží má nyní srovnatelný průměr konců klád. Rozdíl čtyř a šesti kusů
  je skutečná kapacita, nikoli záminka pro jiné měřítko. Sklon průčelí, šindele,
  trámy a kámen působí příbuzně; dlouhá pila a členitá chata zůstávají rozlišitelné.

## Skutečná výrobní dávka

Samostatná závěrečná větev stejného runneru položila1 kládu do vstupu a poté
volala běžné `world.step_tick()`. Další zásoby, rozpracovaná dávka a pracovní
stav se v této větvi nepřepisovaly.

| Fáze | Vstup | Výstup | Rozpracovaná kláda | Pracující postava |
| --- | ---: | ---: | ---: | --- |
| Připravená surovina |1|0|0|ne|
| Začátek a průběh |0|0|1|ano|
| Skutečné dokončení |0|2|0|ne|
| Následný odpočinek |0|2|0|ne, vrací se odpočinková póza|

Obrazy jsou v [actual](actual/), například [zahájení](actual/01-started.png),
[dokončení](actual/02-produced.png) a [následný odpočinek](actual/03-rest.png).
Tato dávka není průchod menu ani dopravní/save test; ty zůstávají navazující prací.

## Konkrétní soubory a reprodukce

Použitý kandidát byl `res://art/buildings/sawmill/v2/manifest.json`, výslovně
předaný jako `--manifest=...`. Výchozí runtime asset se kvůli těmto snímkům
nepřepínal. Preview helper přebírá aktuální verzi z manifestu; explicitní override
umí vyzkoušet kandidáta ještě před přepnutím normální hry.

[capture-manifest.json](capture-manifest.json) zapisuje skutečný načtený RGBA
hash domu, všechny aktivní vrstvy, stav simulace a otisky celé assetové větve
před/po. Otisky se shodují. [verification.json](verification.json) doplňuje
94 snímkových otisků, kontrolu kombinací, šest póz, skutečnou dávku a video.
[full-pair-manifest.json](full-pair-manifest.json) vede oba společné záběry.

Godot4.7.2, nativní Compatibility / Apple M4, skutečná scéna `Main`, audio Dummy,
bez GameSession, hudby a hráčských uložených her. Řízené stavy používají tick1750
nebo4200; u skutečné dávky jsou tick a stav uložené jednotlivě.

Hlavní runner: `res://tools/preview_sawmill_operation.tscn`, volby
`-- --manifest=res://art/buildings/sawmill/v2/manifest.json --output=<absolutní cesta>`.
Společný pohled: zdejší [full-pair.gd](full-pair.gd) se stejným manifest override.
Logy: [native.log](native.log), [full-pair.log](full-pair.log).

Výtvarná kontrola navazuje na [statický nativní základ](../base-native/README.md)
a [měření04](../concept-04-geometry.json). Nenahrazuje celý navazující
[integrační protokol](../README.md), zejména menu, dopravu, ukládání a načítání.
Neuděluje nové uživatelské schválení výtvarného stylu celé stavební sady.
