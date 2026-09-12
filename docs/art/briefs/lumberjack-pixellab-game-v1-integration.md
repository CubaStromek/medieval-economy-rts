# Implementace dřevorubce PixelLab v běžné hře

Datum: **2026-09-10** · ID `lumberjack` · jednotka · stav: **implementováno a technicky ověřeno v běžné hře**.
Uživatel výslovně zadal „A můžeš ty animace už implementovat?“.
Postup: [společný workflow](../object-implementation-workflow.md).
Tento záznam navazuje na [hotový výrobní balík](lumberjack-pixellab-production-v2-integration.md)
a [audit původního rendereru](lumberjack-pixellab-production-v2-runtime-notes.md).

## 1. Zadání a autority

Stávající dřevorubec dostává tři skutečné směrové animace místo jediného
zrcadleného obrázku. Původ, snímky, výběr fází, časy jednotlivých směrů a
vlastní vzhled jsou autoritativně v uvedeném výrobním balíku; znovu se negenerují.
Rozsah zahrnuje běžné menu → mapa → skutečný pracovní cyklus, alfa výběr,
náklad, skrytí v interiéru/mlze, pauzu, světlo, terén a uložené pozice.
Nevznikají nová simulační pravidla ani nová verze save.

## 2. Geometrie a registrace

Celé 256px plátno a společná zdrojová kotva jsou v produkčním manifestu.
Měřítko člověka zůstává 33 world px, nezávislé na délce sekery nebo klády.
Fyzický pohyb a výškovou projekci vlastní `_world_draw_entries()`; registrace
spritu, pořadí, zemní stín a UI se neposouvají podle živého alfa obalu snímku.
Alfa obal všech dodaných zdrojů má horní mez y=20 a dolní y=221; je to
naměřený rozsah pixelů, nikoli automatická poloha chodidel.
Ukazatel hladu má stabilní kotvu 46 world px nad kontaktním bodem, aby
neprocházel kládou (nejvyšší pixel je 37,46 world px nad zdrojovou kotvou).

Kácení probíhá ve stejné simulační buňce jako strom. První normální
průchod prokázal W sek vedle kmene (`natural/04–06` v QA). Nový
`LumberjackWorkPlacement` proto používá osm explicitně prohlédnutých
bodů čepele ve zdrojových fázích a kalibrační bod 12 world px nad patou
kmene. Vzniká malý pracovní odstup uvnitř téže buňky; na poslední příchozí
a první odchozí hraně se plynule zapojí/vypojí. Simulační cell/path zůstávají
beze změny. Načtení uložené hry obě prezentační historie vymaže.

Draw-entry `ground_position` zůstává logicky interpolovaná poloha.
`contact_ground_position` je pozemní bod postoje; `position` vznikne jeho
projekcí na skutečný heightfield, `shadow_ground_position` používá stejný
kontakt. `visual_ground_position` přidá jen pro řazení 3,5 world px / 40
k jeho Y. Rezerva je odvozená z rozsahu podrážek 221−205 zdrojových px
(3,24 world px), ne z hodnot chatrče nebo průběžných alfa obalů. Stejný
bod řazení se používá při terénním zakrytí kliknutí. Fyzická výška země
ani stín tuto pomocnou rezervu nepřebírají.

## 3. Činnosti a vrstvy

| Zobrazení | Autoritativní podmínka |
|---|---|
| Chůze se sekerou | Nedokončený vizuální přesun bez fyzické klády |
| Chůze / klid s kládou | Skutečné `worker.carrying == "log"`; zastavení drží klidový snímek |
| Obouruční sekání | Skutečná povolená `working/harvest`, zbývající práce a platný zralý strom |
| Klid se sekerou | Viditelný stojící dřevorubec, který právě neseká a nenese kládu |
| Úplné skrytí | Interiér nebo ztráta práva vidět jednotku; včetně stínu, nákladu a ukazatelů |

Prezentační cache drží poslední směr, při nulovém vektoru jej nevymýšlí
z výškové projekce. Nová jednotka bez historie má explicitní směr S.
Chůze počítá jeden dvojkrok na 16 world px skutečně pozorované interpolované
trasy. Autorských 0,8 s cyklu se převádí na tuto vzdálenost; směr a náklad
fázi neresetují. Při rychlém běhu se pozoruje každý simulační tick. Sekání
čte jen skutečně odvedenou práci; při 30 ticích přehraje dvě celé série
úderů během tří simulačních sekund. Vynechaný produktivní tick fázi drží.
Pauza vychází ze stejného simulačního času jako interpolovaný pohyb.
Náklad nevzniká podle fáze animace: o převzetí a doručení rozhoduje simulace.
Generický symbol klády se potlačí jen při úspěšně vybrané textuře obsahující
kládu. Ostatní profese a fallback dál používají původní kresbu nákladu.

## 4. Soubory a převod

Vlastní PNG a manifest se nemění. Tři atlasové importy mají zapnuté mipmapy
pro běžný silně zmenšený herní pohled. Reader sdílí načtené atlasy mezi
instancemi scény, při načtení připraví alfa masky všech skutečných fází.
Hit-test používá aktuální snímek a práh alfy 0,10; nečte GPU pixely při kliknutí.
Chybějící či vadný balík vede ke stávajícímu profesnímu spritu.

## 5. Napojení a kompatibilita

`game_session.tscn` → `main.tscn` → `main_view.worker_presentation()`
→ prezentační stav dřevorubce → `LumberjackAnimationLibrary`.
Stejná prezentace slouží kreslení a alfa výběru. Stávající tónování rodiče,
mlha, výškový terén, stíny, výběrový kruh a inspektor zůstávají aktivní.
Cache se neserializuje; po načtení se bezpečně odvodí z načteného světa,
bez příslibu identické rozpracované pózy, kterou původní save neukládá.

## 6. Předání a QA

Skutečné výsledky jsou v [herním QA](../qa/lumberjack-pixellab-game-v1/README.md):
735/735 automatických případů, 22 nativních osmisměrných kontrolních snímků
a normální cesta přes menu s těžbou, předáním klády a 60 snímky skutečného sekání.
Výběr navíc respektuje neprůhlednou korunu stromu před postavou. Při běžném
průchodu se opravila numerická triangulace stínů: kreslí se stejné vrcholy
v lokálních souřadnicích, bez změny fyzického přijímače nebo zahazování ploch.
Výrobní a samostatné nativní QA z předchozí dodávky zůstává historicky zachované.
Uživatelské přijetí vzhledu a společného etalonu není tímto automaticky udělené.
