# Medieval Economy RTS — handover

Stav k **2026-09-05**. Aktuální souhrn níže má přednost před zachovaným
historickým kontextem původního milníku. Interní logy a citlivé údaje sem nepatří.

## Pohostinec a zásobování vojáků — 2026-09-05

- `Inn` v kategorii Food přijímá čtyři hotové potraviny. Civilisté včetně
  strážných rekrutů chodí jíst automaticky; pohostinec má šest míst a časovanou
  návštěvu, nejvýše tři různé chody v pořadí chleba → víno → klobása → ryba.
  Každý trvá 116 ticků, odečte se na začátku a postupně zvyšuje sytost.
  Jednotka zůstává skrytá uvnitř celou návštěvu, specialista si ponechá pracoviště.
- Sytost má venkovní barevný proužek, detail s procentem/stavem/časem do hladu
  a je vidět i u zaměstnance uvnitř pracoviště a jedlíka v pohostinci.
  Hlad je navázán na 6000tickový den: úbytek 5/10ticků, plný člověk znovu
  vyhládne za 18h43 herního času; nová jednotka za 10h05. Chudší jídlo vede
  k častějším návštěvám. Rychlost i pauza platí společně pro hlad a kalendář.
- Voják do pohostince nechodí. Výběr spritu → **Supply food**, případně
  **Military → Supply army**, objedná pod 55 % sytosti jednu fyzickou dávku.
  Nosič ji rezervuje, vyzvedne ze skladu/výstupu výrobce a předá vedle vojáka.
  Jedna porce plně nasytí; rozkaz čeká i při dočasném nedostatku zásob.
- Potravinová pole od save **v14** (zachovaná ve v15): `meal_ticks_left`, `meal_course`, `food_requested`,
  `ration_delivery`. Načítání neprovádí spotřebu ani nepřipisuje sytost; rozjedený
  chod pokračuje přesně. V13 už nasycený návštěvník jen dokončí starý odpočet.
  Validace chrání duplicity, průběh výživnosti a množství rezervací.
- Implementace: `inn_feeding.gd`, `soldier_food_supply.gd`, napojení na world,
  snapshot a HUD. Sady pokrývají jídlo, denní hlad, vojenské dodávky,
  save migrace, UI a viditelnost jednotek.
- [Pravidla a limity](docs/food-and-military-supply.md),
  [pohostinec ve hře](docs/previews/food-inn-seating.png),
  [vojenská donáška](docs/previews/food-soldier-supply.png).

## Jednotky uvnitř budov — 2026-09-05

- Skutečný vstup až po dokončení kroku do vchodu; uvnitř se jednotka ani její
  stín/náklad/hladová značka nekreslí a neblokuje venkovní políčko.
- Tesař zůstává uvnitř mezi dávkami i při čekání na vstupy. Dřevorubec a ostatní
  venkovní specialisté po návratu krátce pobudou uvnitř a bezpečně vyjdou na další
  úkol. Obsazený východ se nepřepisuje; volný člověk může normálně uhnout.
- Detail domu ukazuje skutečné obyvatele uvnitř; zaměstnání a počet občanů se
  nemění. Save **v12** uchovává pobyt a zbývající čekání; verze 1–11 se načítají
  s jednotkami venku. Ověřeno **336/336** headless i nativně, bez chyb skriptů.

## Aktuální ekonomika k 2026-09-05

- Godot **4.7.2**, vlastní procedurální 2,5D grafika, mřížka 48 × 48 px a
  autoritativní simulace na 10 Hz.
- **29 budov, 28 druhů zboží, 15 civilních profesí, 19 výrobních receptů a
  14 vojenských náborových definic.** Hratelné větve: dřevo, chléb, víno,
  ryby, prasata/uzeniny/kůže, koně, uhlí/železo/zlato, zbraně a zbroje.
- Skutečná konečná ložiska kamene, uhlí, železné a zlaté rudy a ryb. Specialista
  jde k dosažitelnému místu těžby, odečte jednotku ložiska a odnese ji do své
  budovy. Nosič zajišťuje další přepravu a zásobování i ze skladu.
- Pšeničná pole se osévají a po sklizni zůstávají prázdná. Vinice znovu
  dorůstají. Pole používají skutečné úkoly sedláka a samostatné růstové hodiny.
- Lesník je **Gardener**: školní tlačítko **Train Gardener** vyškolí autonomního
  pracovníka sázejícího stromy do osmi polí od své **Forester Hut** (Infrastructure,
  3 prkna + 2 kameny). Jedna chata = jeden zahradník; bez chaty čeká.
  Jde o vlastní rozšíření včetně ceny, ne původní KaM profesi/budovu.
- **Fisherman's Hut** (Food, 4 prkna + 3 kameny) má jednoho rybáře a potřebuje
  dosažitelné loviště do tří polí. Rybář nosí ryby do chaty, nosič dále.
  Výchozí jezero má nově konečná loviště; staré savy se automaticky nemění.
- Nové budovy jsou staveniště: nosiči přivezou prkna/kámen a stavitel dokončí
  práci. Škola přijímá dodané zlato, každého občana zaplatí jednou a dokončí
  časovaný výcvik. Pila nyní mění 1 kládu na **2 prkna**; mlýn a pekárnu
  stále obsluhuje pekař.
- Jídlo se spotřebovává v hostinci; pracovníci mají kondici a mohou vyhladovět.
  Tržiště má skutečné směnné nabídky, fyzické dodání a odběr zboží. Dílny
  zbraní/zbrojí plní hráčem zadanou FIFO frontu receptů.
- Kasárna vybaví přítomného rekruta dodaným vybavením; radnice přijímá zlato.
  Volný rekrut může obsadit strážní věž a věž přijímá kámen do zásoby. Nábor
  nemá další časovač po splnění podmínek. **Boj, vojenské povely, projektily
  ani obléhací stroje zatím nejsou implementované.**
- Výchozí `setup_economy_demo()` je vesnice **34 × 24 polí**, má všechny typy
  dokončených budov, pole/vinice, ložiska, pracovníky, startovní zásoby a
  ukázkové výrobní/náborové objednávky. Nové hráčovy stavby už stojí materiál.
  Původní `setup_demo()` zůstává kompaktní testovací/kompatibilitní scénář.
- UI má čtyři kategorie staveb, samostatně rolovaný detail a školní nabídku,
  tři skladové kategorie se všemi surovinami a živé požadavky výroby/služeb.
  Klávesy **1–9** zůstávají, **0** staví pšenici; vinice jsou v kategorii Food.
- **Save v7**: druh políčka, konečná ložiska, kondice, rozestavěnost/dodaný
  materiál, zaplacení výcviku, recepty a výrobní/náborové/obchodní fronty.
  Verze 1–6 se migrací doplní; staré hry nevytvářejí nová ložiska a ponechávají
  pokročilé náklady/potřeby vypnuté. Načtení je transakční.
- Ověření na Godotu 4.7.2: **87/87 testů prošlo**. Rozpad sad a pokrytí:
  `tests/README.md`. Samostatná kontrola UI při
  1152 × 720 ověřila panel 390 × 696, sklad 392 × 178, všech 28 zboží,
  15 profesí, přepínání budov a příkazy výroby/náboru/směny. V běžícím Godotu
  byl ověřen i náhled 1440 × 900 s mapou, ložisky a školní nabídkou.

### Přesné hranice tohoto milníku

Ekonomické vazby vycházejí z KaM Remake, ale pracovní/růstové/stavební časy a
většina stavebních cen jsou vlastní balance projektu. Chov používá jednu dávku
čtyř obilí na zvíře; nesimuluje čtyři samostatná krmení a individuální věk.
Lisování hroznů je sloučené se sklizní. Kamenná cesta a vinice se zaplatí ihned
ze skladu (1 kámen / 1 prkno) a hned vzniknou. Budovy jsou stále jednopolové,
neexistuje strom odemykání, bydlení ani boj. Věž má posádku a zásobu kamene,
ale nestřílí. Podrobnosti: `docs/economy-expansion.md`.

## Zachovaný historický kontext

Následující oddíly popisují původní dřevní/terénní milník z 23. 8. a opravy do
4. 9. 2026. Dřívější tvrzení o verzi save, počtu testů, neexistujících spotřebách
nebo plánovaných budovách nejsou aktuálním rozsahem hry. Předchozí první
rozšíření z 5. 9. (čtyři budovy a pšeničná pole, v6, 67 testů) je popsáno jako
historie v `docs/economy-expansion.md`; nahradila je výše uvedená v7 ekonomika.

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
- Historické testy ověřené 2026-09-04 Godotem 4.6.1 stable:
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

Časování původního milníku (historie):

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

## 9. Původní roadmapa (historie)

Původní plán po terénním základu je zachován níže. Materiálové stavění, jídlo,
farmy, doly a širší výrobní graf už doplnila v7; ostatní body pokračují dál:

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
- `docs/economy-expansion.md` — aktuální řetězce, ceny/časování a přesné hranice.
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
