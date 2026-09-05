# Medieval Economy RTS — handover

Stav k **2026-08-23**. Dokument shrnuje dostupná hlavní projektová vlákna,
původní zadání, aktuální repozitář a ověřený stav prototypu. Interní pomocná
vlákna, systémové logy a citlivé údaje nejsou součástí handoveru.

## 1. Vize a mantinely projektu

`Medieval Economy RTS` je fanouškovská open-source ekonomická RTS inspirovaná
stylem Knights and Merchants. Jde o novou hru napsanou od nuly v Godotu 4.6 a
typovaném GDScriptu, nikoli o port nebo úpravu původní hry či Delphi enginu.

- Technická reference: [KaM Remake](https://github.com/reyandme/kam_remake),
  analyzovaný commit `a3b3e5268e1475460e4561f9143df6f1a532e681`.
- Licence projektu: AGPL-3.0.
- KaM Remake slouží k pochopení odpovědností, pravidel a invariantů. Delphi kód
  se nemá mechanicky přepisovat řádek po řádku.
- Do repozitáře nesmí přijít původní grafika, hudba, zvuky, mapy, kampaně ani
  jiné proprietární soubory. Případná legálně vlastněná instalace smí být jen
  externí lokální zdroj pro budoucí nástroje.
- Prototyp používá vlastní procedurální placeholdery.

## 2. Repozitář a ověřený stav

- GitHub: <https://github.com/CubaStromek/medieval-economy-rts>
- Lokální cesta: `/Users/openclaw/AI-Projects/medieval-economy-rts`
- Výchozí větev: `main`
- Výchozí stav před tímto handoverem: commit `6b2472f` (`Initial Medieval
  Economy RTS prototype`), shodný s `origin/main`.
- Cílový Godot: 4.6; původní milestone byl ověřen s 4.6.3 stable.
- Aktuální testy ověřené 2026-09-04 Godotem 4.6.1 stable:
  `TEST RESULT: 50/50 passed`.

Spuštění hry:

```sh
godot --path game
```

Testy:

```sh
./tests/run-headless.sh
```

Testy musí dál běžet přes skutečný headless Godot projekt a scénu, ne přes
izolované spuštění GDScriptu.

## 3. Co je hotové

První hratelný vertikální řez obsahuje:

- celočíselnou mřížku a autoritativní fixed-step simulaci na 10 Hz, nezávislou
  na FPS;
- kameru, posun, zoom, výběr polí a build režimy;
- kamenné cesty, sklad, dřevorubeckou chatu a pilu;
- oddělené profese dřevorubce, nosiče a autonomního zahradníka;
- řetězec strom → dřevorubec → chata → nosič → pila → nosič → sklad;
- datové definice surovin, budov, receptů, profesí a pohybu v `game/data/`;
- datově řízenou školu s FIFO výcvikem nosičů, dřevorubců a zahradníků, přesným
  časováním v tickách a čekáním při obsazených výstupech;
- autonomní výběr nejbližšího dosažitelného místa, výsadbu, exkluzivní rezervace
  a cooldown zahradníků; ruční mikromanagement výsadby není potřeba;
- tři vizuální růstové fáze stromu; těžební úkol vzniká až v dospělé fázi;
- deterministické vážené A*, rezervace úkolů i polí a replánování při blokaci;
- hustou autoritativní vrstvu základního terénu (`grass`, `dirt`, `water`,
  `rock`) oddělenou od stezek, cest a obsazení;
- pravoúhlou projekci 48 × 48 px a samostatný čtecí `TerrainRenderer` s
  deterministickými barevnými variantami a automatickými přechody;
- verzi 5 JSON save/load se stavem terénu, výcviku, růstu stromů a cooldownu
  zahradníků a zpětným načtením verzí 1 až 4;
- datově řízený HUD vpravo nahoře s procedurálními ikonami klád, prken a kamene,
  který odděleně ukazuje skladové a rozpracované množství; kámen je zatím nulová
  skladová položka bez těžebního řetězce;
- procedurální vektorovou placeholder grafiku bez externích assetů.

Architektura drží simulaci v `game/scripts/simulation/` oddělenou od vstupu,
kamery, UI a kreslení v `game/scripts/view/`. V prvním milníku nejsou gameplay
Autoloady; scénu vlastní samostatný `SimulationWorld`, což usnadňuje testy a
budoucí běh více světů.

## 4. Důležitá rozhodnutí z ladění pohybu a logistiky

Původní vizuální pohyb působil trhaně, protože se interpolace po každém ticku
znovu rozbíhala ze starého políčka. Oprava drží plynulý průběh celého kroku a
test hlídá, že vizuální interpolace necouvne.

Aktuální časování:

- výchozí rychlost hry `0.5×`; UI nabízí pauzu, `0.5×`, `1×` a `2×`;
- logický tick je stále 10 Hz; rychlost mění jen tempo požadavků na tick;
- tráva `6` ticků/pole, hlíněná stezka `4`, kamenná cesta `2`;
- pokácení stromu `30` ticků;
- výsadba `20` ticků, opakování po `80` tickách;
- sazenice přechází v mladý strom v ticku `80` a dospívá v ticku `200`;
- pila spotřebuje 1 kládu a za `60` ticků vyrobí 1 prkno.

Při blokaci jiným pracovníkem se jednotka nesmí zaseknout ani donekonečna
opakovat stejný neproveditelný úkol:

- ostatní pracovníci se při replánování berou jako dočasné překážky;
- po omezeném čekání se přepočítá cesta;
- pokud zdroj zůstává nedosažitelný, nezatížený pracovník úkol uvolní a vybere
  nejbližší aktuálně dosažitelný zdroj;
- pracovník s nákladem nejdřív obnoví doručení a nepřijme nový těžební úkol;
- logistiku lze dokončit ze sousedního pole, když je vstup budovy obsazený;
- výměna protijdoucích jednotek je atomická a nesmí nastat, dokud oba skutečně
  nedokončí aktuální krok.

## 5. Cesty, profese a zamýšlená ekonomika

Uživatel výslovně rozhodl, že prvotní těžbu provádí specialista (například
dřevorubec), zatímco přepravu z výrobní budovy zajišťuje nosič. Nosiči používáním
nejefektivnější trasy vytvářejí infrastrukturu:

1. na běžné trávě chodí nejpomaleji;
2. po čtyřech dokončených průchodech nosiče vznikne rychlejší hlíněná stezka;
3. hráčem postavená kamenná cesta je nejrychlejší.

Pouze dokončené kroky nosiče přidávají opotřebení; chůze dřevorubce cestu
nevyšlapává. A* používá stejné náklady jako skutečná délka kroku, takže delší
trasa po kameni může správně porazit kratší cestu přes trávu.

## 6. Zvolený grafický směr

Uživatel zvolil **moderní malovanou 2,5D grafiku inspirovanou KaM**, ne skutečné
3D a ne striktní kopii původního vzhledu.

Referenční princip KaM:

- pravoúhlá síť čtvercových polí s výškou v rozích;
- malované 2D povrchy, přechodové masky, dekorace a velké sprity budov;
- osmisměrné snímkové animace postav;
- samostatné animační vrstvy budov a maska barvy hráče;
- 2D řazení objektů podle mapové pozice a jednotný směr světla/stínů.

Současný základ už používá pravoúhlou projekci 48 × 48 px. Rozlišuje trávu,
hlínu, vodu a skálu, oddělené stezky/cesty, deterministické varianty a
automatické procedurální okraje. Jde stále o dočasné barevné textury bez výšky
a produkčních malovaných assetů; jejich účelem je ověřit projekci, měřítko,
kameru a datové hranice.

## 7. Schválený plán terénu

Cílová terénní buňka má oddělit:

- základní zeminu (`grass`, `dirt`, `sand`, `rock`, `water`);
- výšku uloženou ve sdílených rozích polí;
- povrchový overlay (vyšlapaná stezka, kamenná cesta, pole apod.);
- přechodové masky mezi materiály;
- deterministickou vizuální variantu a dekorace;
- herní vlastnosti jako průchodnost, stavitelnost, rychlost, úrodnost nebo
  těžitelnost.

Terénní data jsou autorita; renderer je pouze zobrazuje. Cesty se nesmějí dál
tvářit jako základní druh zeminy.

Stav plánovaných fází:

1. datový model a save migrace — hotovo ve verzi 4;
2. samostatný `TerrainRenderer` — hotovo; cache bloků přibližně 16 × 16 polí
   zůstává dalším výkonovým krokem;
3. dočasná sada tráva/hlína/skála/voda + deterministické varianty — hotovo;
4. procedurální automatické okraje a rohy — základ hotov, malované maskové
   atlasy teprve vzniknou;
5. procedurální vyšlapané stezky a napojované kamenné cesty — základ hotov,
   produkční kresba zbývá;
6. sdílená výška rohů, svahy a skalní stěny;
7. voda a pobřeží;
8. samostatné přírodní dekorace;
9. interní editor terénu s undo/redo.

Výkonnostní cíl produkčního systému je mapa až 256 × 256 polí s lokálním
překreslením změněných bloků.

## 8. Dokončený terénní základ

První omezený terénní balík nyní obsahuje:

1. přidat datový model pro trávu, hlínu, vodu a skálu;
2. oddělit základní zeminu od stezky a kamenné cesty;
3. zavést pravoúhlou projekci blízkou KaM;
4. přesunout kreslení do samostatného `TerrainRenderer`;
5. použít dočasné barevné textury a automatické přechody;
6. migrovat formát uložené hry;
7. doplnit testy průchodnosti, stavitelnosti, cest a serializace.

Produkční malované assety se mají vyrábět až po ověření projekce, měřítka,
kamery a přechodů. Technická kontrola a testy proběhly; před výrobou celé sady
je vhodné uživatelsky potvrdit náhled měřítka 48 px a celkovou hustotu mapy.

Kontrolní milníky jsou: (1) malovaný plochý terén, (2) živá krajina s
dekoracemi a vodou, (3) reliéf a pravidla svahů, (4) produkční renderer a editor.

## 9. Další otevřená práce

Po terénním základu navazují zejména:

- vícepólové a otočné půdorysy budov a skutečné stavební úkoly s materiály;
- typované stavy entit místo prototypových slovníků;
- logistický matcher podle ceny trasy, priority, kapacity a stáří nabídky;
- atomické rezervace zdrojového množství, kapacity cíle a pracovníka;
- potřeby obyvatel, jídlo a bydlení;
- širší výrobní graf, farmy, doly, sklady a distribuční politiky;
- deterministický příkazový log, vlastní PRNG, hash stavu a pozdější lockstep
  multiplayer;
- dlouhé invariantní a seedované testy, replay hash a testy poškozených saveů.

## 10. Rizika a pravidla pro pokračování

- Fixed-step simulaci a celočíselné rozhodování nepropojovat s FPS nebo
  vizuální interpolací.
- UI a renderer nesmí přímo měnit autoritativní inventáře ani terénní pravidla.
- Pathfinding a reálný pohyb musí číst stejnou cenu povrchu.
- Každý úkol, předmět, cílové pole a budoucí kapacita musí mít jednoznačnou
  rezervaci.
- Entity a definice aktualizovat v kanonickém pořadí; náhodnost smí později
  pocházet jen z projektového deterministického PRNG.
- Před rozšířením formátu save přidávat explicitní migraci verze.
- `reference/kam_remake/` zůstává lokální, neupravovaný a ignorovaný Gitem,
  pokud se výslovně nezvolí čistý submodul.
- Po každém významném milníku stručně uvést: co je hotové, co bylo ověřeno, co
  následuje a která rizika nebo rozhodnutí vyžadují uživatele.

## 11. Orientace v dokumentaci

Po code review 4. 9. 2026 jsou opravené čtyři integrační chyby: opakovaná
aktualizace jednotky při výměně míst, neobnovený výběr cíle při zablokovaném
doručování, přijetí neúplného save a dvojí zpracování mezerníku přes UI focus.
`WorldSnapshot` nyní vlastní serializaci/validaci/migrace a `GameHud` konstrukci
a texty UI. Pohybové definice mají společný zdroj v JSON; A* i hledání nejbližšího
cíle používají společnou haldu. Podrobnosti a testy jsou v architektuře a
`docs/code-review-fixes.md`.

- `README.md` — spuštění, ovládání, aktuální funkce a právní mantinely.
- `docs/reference-analysis.md` — rozbor KaM Remake.
- `docs/godot-architecture.md` — hranice systémů a plán determinismu.
- `docs/reference-map.md` — mapování Delphi odpovědností na Godot systémy.
- `THIRD_PARTY_NOTICES.md` — původ reference a licence.
- `game/scripts/simulation/` — autoritativní model.
- `game/scripts/view/main_view.gd` — vstup, UI a kreslení entit;
- `game/scripts/view/terrain_renderer.gd` — samostatné čtecí zobrazení terénu;
- `game/scripts/view/map_projection.gd` — sdílená projekce a budoucí hranice pro
  výšku rohů.
- `game/tests/test_runner.gd` — současná testovací sada.
