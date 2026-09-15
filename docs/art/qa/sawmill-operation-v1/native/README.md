# Pila: finální nativní kontrola provozních vrstev

Ověřeno **2026-09-12**, Godot **4.7.2**, Compatibility / Apple M4.
Runner: `game/tools/preview_sawmill_operation.tscn`, odvozený z existujícího
nativního náhledu života pily. Produkční `Main`, skutečný renderer,
terén a importované PNG; izolovaný testovací svět bez GameSession,
hudby a hráčových uložených her. `native-preflight/` je starší mezikontrola,
nikoli důkaz poslední čisté šestice.

## Přehledy

- [Zásoby](stocks.png): 12 pohledů — klády 0–4, prkna 1–6,
  prázdný stav společný oběma a oba sklady plné.
- [Činnost a přítomnost](activity.png): výroba, odpočinek, osobní pauza,
  noc doma, den mimo dům a noc mimo dům. Rozpracovaný kus je samostatný.
- [Měřítko a terén](context.png): zoom 0,75× / 1× / 2,4×,
  vyvýšená plošina s obrysem skutečných 4 × 2 polí, přední strom a noc.
- [Pracovní smyčka](work-cycle.mp4): 640 × 460, 40 sn./s, 1 sekunda.
  Testovací přehrání jednoho cyklu podle odpracovaného postupu;
  kamera 4×. Není to záznam běžného menu ani měření výkonu hry.

Všechny přehledy a několik fází obou krajních poloh byly vizuálně
prohlédnuty. Boty pracovníka sedí na dláždění uvnitř půdorysu, pracovní
postoj se vejde vlevo od předního sloupu a ruční pila prochází obrobkem.
Klády a prkna zůstávají ve svých zónách; dveře a nástupní pole jsou volné.
Přední strom správně zakrývá pracovníka a dílnu. Na zvýšené ploše nevzniká
další blokující zemní obsah mimo 4 × 2 polí. Šestice nemá viditelné
oddělené fragmenty u rukou/krku v prohlédnutém herním obrazu.

Při zoomu 1× je pracovník měřítkově shodný s ostatními lidmi. Pohyb je
úsporný: tělo a chodidla drží postoj, práci vyjadřuje hlavně tah předloktí
a listu. Není to zrekonstruovaný celý KaM rozběh/odnesení výrobku.

## Skutečná simulace uvnitř izolovaného světa

Vedle přesných obrazových fixture stavů runner spustil běžnou ekonomiku
od jedné již dodané klády: [vstup](actual/00-delivered.png) →
[zahájená dávka](actual/01-started.png) →
[dvě vyrobená prkna](actual/02-produced.png) →
[odpočinek](actual/03-rest.png). Vstup se změnil z 1 na 0 při zahájení,
rozpracovaný kus zůstal během řezání a zmizel při dokončení;
výstup se změnil z 0 na 2. Pracovní figura skončila spolu s dávkou.
To není náhrada za [samostatnou běžnou menu cestu](../natural/README.md).

Celkem **71 snímků**, z nich **40 časových vzorků pracovní smyčky**.
V této smyčce renderer skutečně vybral všech šest `frame_index` 0–5.
[`capture-manifest.json`](capture-manifest.json) zaznamenává skutečné
operační stavy i cesty vykreslených vrstev. Všech **11 PNG + 2 manifesty**
měly na začátku a konci totožný SHA-256. Nativní běh skončil kódem 0
a bez hlášené runtime chyby. Geometrii ani produkční PNG tento runner
neupravuje.
