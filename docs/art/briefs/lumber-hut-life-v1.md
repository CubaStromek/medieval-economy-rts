# Dřevorubecká chata — dveře, odpočinek a noční život

Datum **2026-09-12** · `lumber_hut` · stavové vrstvy **life v1**.
Zadání podle [šablony budov](../building-brief-template.md),
[manuál v0.2](../building-style-guide.md). Uživatel požádal dokončit
dynamické prvky téměř hotové chaty: noc s kouřem a světlem, denní dveře
podle skutečné přítomnosti a případně dřevorubec opřený u chaty.
Upřesnění uživatele **2026-09-12**: při denním odpočinku také otevřít
okno bez světla a nechat opřeného dřevorubce jemně hledět doleva a doprava.

## Identita a rozsah

Vlastní architekturu, malované materiály a předolevý nadhled určuje
[existující v3](lumber-hut-v3.md), produkční registraci a stavební sadu
[stavební brief](lumber-hut-construction-v1.md), aktuální fyzický půdorys
[integrace v2](lumber-hut-footprint-v2-integration.md). Tyto údaje se
nepřepisují novým konkurenčním manifestem. Katalog, kolize, přístup,
terén, stavební práce, ekonomika a ukládání zůstávají autoritou simulace.
Zásoby nadále mají vlastní [vrstvu 0–6 klád](lumber-hut-stock-v1-integration.md).

Nový výtvarný etalon celé sady tím nevzniká. Novou architekturu ani další
budovy negenerujeme. Novým bitmapovým prvkem je samostatná klidová
póza stávajícího vlastního dřevorubce se třemi směry pohledu;
není součástí statického domu.

## Stavový plán

| Stav | Podmínka | Výsledek |
|---|---|---|
| Den, pracovník mimo chatu | Přidělení samo nestačí; fyzicky není uvnitř své chaty | Zavřená prkenná dvířka, tmavé okno, bez kouře a odpočívající postavy |
| Den, skutečný vstup | Přidělený dřevorubec má `inside_building_id == hut.id` | Otevřené dveře |
| Den, odpočinek doma | Totéž, bez nákladu, bez spánku nebo odevzdávání; idle nebo osobní pracovní pauza | Otevřené okenice a tmavý vnitřek bez svitu; opřená postava u levého sloupku se zvolna rozhlíží |
| Noc doma | `world.is_night_rest_time()` a fyzický pobyt svého dřevorubce | Zavřené dveře, teplé světlo malého okna, jemný stoupající kouř |
| Noc, prázdná chata | Pracovník ještě nedošel domů nebo není přidělený | Tmavé okno, bez kouře |
| Cizí chata v zapnuté mlze | Stejná politika jako zásoby/HUD, i při aktuálním spatření | Nečíst obyvatele; neutrální statický základ, bez živých stavových vrstev |
| Rozestavěná/připravovaná chata | `not world.is_building_complete()` | Žádná vrstva life |

Noční oheň je domácí atmosféra, nikoli produktivní práce. Požadavek na noc
je realizován pro skutečně obývanou chatu; světlo ani kouř neslouží jako
indikátor zapnuté výroby. Nosič, rezervace, kláda na cestě ani jiná návštěva
nepředstírají přítomnost domácího dřevorubce. Individuální pauza doma ho
neschová; globální pauza zmrazí čas efektů. Noc vychází ze stávajícího
rozvrhu 20:00–05:00. Východ/západ a tónování světa se nemění.

## Vrstvy, kotvy a technika kresby

Základ, konstrukční mastery i zásoby používají původní PNG. Zavřený dveřní
list je texturovaný čtyřúhelník se dřevem ze současné okenice. Nevzniká
nový generovaný dům. Otevřený stav odhalí původní tmavý průchod. Noční
okénko má teplé sklo, dřevěný kříž a okenice ze stejného materiálu;
samostatný slabý svit osvětluje okolní omítku. Kouř jsou překrývající se
měkké průhledné částice, které z komína stoupají, rozšiřují se a mizí.
Při denním odpočinku jsou stejné okenice otevřené, otvor ukazuje tmavý
interiér tónovaný okolním světlem. Nevytváří se žádná emisivní barva
ani svit. Samotné odevzdávání klády okno neotevírá.

Rozhlížení má klidový cyklus 12 simulačních sekund s delšími výdržemi
uprostřed, vlevo a vpravo. Každé malé otočení trvá 0,45 sekundy;
skutečné kreslené natočení hlavy má krátké plynulé přechody. Tělo,
ruce, chodidla i opření zůstávají přesně na místě. Cyklus nezařizuje
delší pobyt doma: při odchodu okamžitě končí podle skutečné simulace.

Všechny kotvy jsou v původním canvasu **640 × 640** a používají obdélník
a měřítko chaty přímo z její existující prezentace. Autoritativní souřadnice
texturovaných ploch jsou v `lumber_hut_life.gd` (`DOOR`, `WINDOW`, `CHIMNEY`,
`REST_FOOT`); nejsou novým simulačním prahem. Pohyb dřevorubce ve světě
neměníme: odpočinková kresba zastupuje skutečného obyvatele u jeho domu,
nevytváří druhou jednotku ani novou rezervaci pole.

Částice ani svit nejsou klikací objekty. Materiály a postava se tónují
stejně jako dům. Emisivní barva kompenzuje pouze okolní noční tón uvnitř
stejného kreslicího řádku; neobchází přední terén, stromy ani mlhu.
Registrace postavy, skutečná alfa a původ jsou v produkčním záznamu.

Stavební část tohoto zadání je N/A: všech 33 původních kroků zůstává
stejných. Nové layers se zapnou až při skutečném dokončení, ne při
posledním grafickém kroku s jedním zbývajícím pracovním tickem.

## Dodávka a přejímka

Technické zapojení a původ: [implementační záznam](lumber-hut-life-v1-integration.md).
Aktuální výsledky, snímky a omezení: [QA](../qa/lumber-hut-life-v1/README.md).
Upřesnění okna a pohledů: [nativní QA look v1](../qa/lumber-hut-life-look-v1/README.md).
Kontroluje se vlastní/cizí mlha, den/noc, příchod/odchod, náklad a odpočinek,
globální/osobní pauza, uložení, běžná herní cesta, měřítka 0.75×/1×/2.4×
a vyvýšená zem. Výsledek se doplní podle skutečně provedených kontrol.
Uživatelské výtvarné přijetí této nové vrstvy: **zatím neuděleno**.
