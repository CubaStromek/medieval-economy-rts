# Medieval Economy RTS — handover

Stav k **2026-09-15**, vydání **0.6.0**. Tento dokument je výchozí předání
projektu pro další práci. Popisuje skutečný stav repozitáře, nikoli jen návrhy
z konverzací. Co přinesla jednotlivá vydání, shrnuje [CHANGELOG](CHANGELOG.md).
Předchozí souhrn je v [historickém archivu](docs/handover-archive/2026-09-12.md);
jeho počty testů, save verze a roadmapa nejsou aktuální zadání.

## 1. Rychlý přehled

- **Projekt:** vlastní ekonomická RTS inspirovaná Knights and Merchants, od nuly
  v Godotu; nejde o port Delphi enginu ani distribuci původní hry.
- **Repozitář:** [CubaStromek/medieval-economy-rts](https://github.com/CubaStromek/medieval-economy-rts),
  veřejný, větev `main`, licence AGPL-3.0.
- **Verze:** **0.6.0**, tag `v0.6.0`, v `application/config/version`
  souboru `game/project.godot`. Starší milníky nesou tagy `v0.1.0`–`v0.5.0`.
  Číslování, changelog a postup vydání: [release process](docs/release-process.md).
- **Pracovní adresář:** `/Users/openclaw/AI-Projects/medieval-economy-rts`.
  Dřívější `Documents/ChatGPT/KaM` není adresář hry. Nepoužívat symlink jako
  náhradu kořene projektu; aplikace s omezeným zápisem jej nemusí přijmout.
- **Godot:** ověřen **4.7.2 stable**, OpenGL Compatibility, macOS / Apple M4.
  Importovat `game/project.godot`; hlavní scéna je `game_session.tscn`.
- **Simulace:** autoritativní fixed-step **10 Hz**, celočíselná herní mřížka.
  Herní čas drží reálný čas jako KaM Remake: pomalý snímek dožene dlužné ticky
  (strop 100, nejvýš 100 ms dohánění na snímek), hra se nezpomalí.
  Aktuální zobrazovací buňka je **40 × 40 world px**, nikoli historických 48.
- **Save:** **v23** se zpětnou validací a migrací v1–22. v23 zahazuje spánek,
  vlky a chalupy dělníků. Půdorys se verzuje také samostatně po jednotlivých
  budovách.
- **Katalog:** 29 typů budov, 28 surovin, 15 civilních profesí,
  19 výrobních receptů a 14 vojenských náborových definic.
- **Předchozí vydání:** `c965329` (0.5.0) z 12. 9. Kontrola `git fetch origin`
  15. 9. před vydáním: lokální HEAD i vzdálená `main` byly shodné.
- **Ověření vydání 0.6.0:**
  - kompletní headless sada **787/787**, znovu **787/787** i v čisté kopii
    z indexu po novém importu;
  - nativní refaktorová a renderovací sada **79 případů bez selhání**;
  - exportér terénu **6/6**, importér **17 + 1 volitelný přeskočený**;
  - PixelLab klient **16/16**, bez volání služby.

  Podrobnosti: [ověření vydání](docs/release-verification-2026-09-15.md).

## 2. Jak navázat a spustit hru

Nejprve přečíst [AGENTS.md](AGENTS.md), tento handover a dokument konkrétní oblasti.
Nespouštět další generování ani nevracet zamítnutou grafiku jen podle starého názvu souboru.

Z kořene repozitáře:

```sh
godot --editor --path game
godot --path game
./tests/run-headless.sh
```

Na zdejším Macu lze místo `godot` použít
`/Applications/Godot.app/Contents/MacOS/Godot`. Po čerstvém klonu nejprve
nechat editor importovat textury; lze i bez okna:

```sh
godot --headless --editor --path game --import
```

Hlavní menu nabízí novou hru, načtení a grafický sandbox. Nová hra má:

| Mapa | Stav |
|---|---|
| Nová osada | 28 × 22, Warehouse a School; základ pro budování |
| Osídlené údolí | 28 × 22, osídlený terénní scénář; také běžné QA dřevorubce |
| Ekonomická ukázka | 34 × 30, 29 dokončených budov všech 29 typů |
| Mountainous Region | Volitelná lokální mapa 143 × 127; bez externích dat není dostupná |

Mountainous Region má školu a sklad, bez lidí a cest, celkem 50 zlata a po
20 kládách, prknech a kamenech. Jedno zlato je ve škole pro první výcvik,
49 ve skladu. Má oddělený save slot. Její původní ani převedená mapová data
nejsou součástí veřejného klonu.

`Esc` nejprve ruší aktivní nástroj nebo zavírá detail, potom otevírá pauzové
menu. Testy a QA používají izolované pozice; skutečné hráčovy savy nepřepisovat.
Další ovládání a spouštěče `.command`: [README](README.md).

## 3. Herní stav a závazná rozhodnutí

### Ekonomika a logistika

Fungují řetězce dřeva, chleba, vína, ryb, chovu, kůže, uhlí/rud/hutí,
zbraní a zbrojí, tržiště, výcvik a vybavení rekrutů. Ložiska včetně ryb jsou
konečná. Stromy rostou a lesník je sází; pole potřebují skutečnou práci sedláka.

Stavby vznikají z materiálu fyzicky přineseného nosiči a práce stavitele.
Pila vyrábí **2 prkna z 1 klády**. Škola spotřebuje zlato jednou při výcviku.
Rezervace, vážené osmicestné A*, uhýbání, přeplánování a interpolace pohybu
zůstávají součástí běžné simulace. Hledání cest používá packed index se
stejnými trasami (tick ~5× levnější); viz
[výkon hledání cest](docs/pathfinding-performance.md).

**Gardener / Forester Hut** je naše vlastní lesnické rozšíření, nikoli
dřevorubec. Workers' Cottage (ubytování) byla 14. 9. 2026 odstraněna spolu
s cyklem dne a noci.

### Hlad, mlha a pozastavení

- **Cyklus dne a noci je od 14. 9. 2026 zrušen**: žádné hodiny, spánek, noční
  tónování, vržené stíny, vlci ani chalupy dělníků. Civilisté pracují bez
  přestávky, tick zůstává 0,1 s.
- Civilisté se fyzicky stravují v hostinci; vojákovi musí dávku přinést nosič.
  Návštěva hostince má až tři různé chody, ne okamžité doplnění při otočení ve dveřích.
- Aktuální model odděluje sytost od dlouhodobého nedostatku.
  **Smrt až po sedmi bilančních dnech (6000 ticků = 10 minut) úplně bez jídla od plného stavu**,
  tedy 70 minut při 1×. Nové jednotky začínají najedené.
- Sytost ubývá stálým tempem 390 milli za tick (stejná denní spotřeba jako
  dřívější průměr bdění a spánku). Nedostatek postupně oslabí produktivní práci
  nejvýše o 20 %; chůzi a nosičské zásobování nezpomalí.
  Jídlo rezervu obnovuje poměrně, drobek ji nevynuluje.
- Neprozkoumaná mapa je černá, prozkoumaná zem mimo dohled tmavší;
  cizí jednotky se mimo dohled nekreslí a nesmějí prozradit stav přes UI.
- Detail občana ukazuje **Co si myslím — Teď / Potom** podle jeho skutečného stavu.
  Jednotku a budovu lze pozastavit nezávisle. Pauza práce zachovává náklad
  i postup, neblokuje jídlo a bezpečný pohyb. Není to globální pauza.
- Jednotka skutečně uvnitř budovy nemá venkovní sprite, stín, náklad ani
  venkovní blokování. Zaměstnání a aktuální fyzická přítomnost nejsou totéž.

Autority: [ekonomika](docs/economy-expansion.md),
[jídlo](docs/food-and-military-supply.md), [mlha](docs/fog-of-war.md),
[pauza a myšlenky](docs/unit-thoughts-and-pause.md); historické:
[den a noc](docs/day-night-analysis.md), [bydlení](docs/worker-housing.md),
[vlci](docs/night-wolves.md).

## 4. Aktuální grafika: co skutečně používá hra

### Terén

Běžná hra používá vlastní malovaný **V1 atlas osmi materiálů** a společný
compositor se sandboxem. Přechody a osvětlení nejsou jen přebarvené staré
trojúhelníky. Atlas je vlastní generovaný obraz, ne originální KaM textura.
Původní procedurální renderer zůstává fallbackem a historickou testovací cestou.

Herní terén, kolize a srovnávání země jsou oddělené od vzhledu.
Voda je **statická**. Rozdíl zaokrouhlení původních výšek proti hernímu terénu
může být zhruba 4 px při 1×; nejde automaticky o chybu textury.
Viz [V1 v běžné hře](docs/painted-terrain-game.md) a
[sandbox](docs/terrain-graphics-sandbox.md).

### Dřevorubecká chata

- Vlastní RGBA budova a **12 dřevěných + 21 dokončovacích kroků**.
  33 kroků odhaluje skutečná práce stavitele, nejde o nezávislé video.
- Samostatná vrstva zásob zobrazuje **0–6 klád podle fyzického výstupního
  inventáře**, nikoli podle rezervací nebo dosud neseného nákladu.
- Nově stavěná chata má **půdorys v2: 4 × 3, devět obsazených polí**:
  `.### / .##E / ###.`. Dveře zůstaly ve stejné fyzické pozici vůči kresbě;
  zářez před vstupem je průchozí. Zachovány obrázky, měřítko a stavební fáze.
- Staré uložené chaty se **nezvětšují**: v1 zůstává 3 × 2 / šest polí,
  v0 zachovává původní jednopolovou geometrii. Verze mohou existovat společně.
  Proto starý save nemusí vypadat jako nově postavená chata.
- Vrstva života ukazuje jen skutečnou přítomnost vlastního dřevorubce:
  otevřené dveře, odpočívající postavu s otáčením hlavy a otevřené okno.
- Registrace bitmapy, fyzická poloha, výška terénu a vizuální řazení
  jsou samostatné veličiny; nepřesouvat fyzické dveře kvůli zakrytým pixelům.

Autority: [stavba](docs/art/briefs/lumber-hut-construction-v1.md),
[zásoby](docs/art/briefs/lumber-hut-stock-v1-integration.md),
[půdorys v2](docs/art/briefs/lumber-hut-footprint-v2-integration.md),
[život chaty](docs/art/briefs/lumber-hut-life-v1-integration.md).
Jejich QA adresáře obsahují skutečné snímky i rozsah měření, nikoli univerzální
důkaz správného kontaktu na každém možném svahu.

### Pila a tesař

- Aktivní je malovaná **pila v2**; v1 zůstává jako historie. Půdorys 4 × 2
  s maskou `####/#E##` se nezměnil, stejně jako simulace, mřížka a save.
- Vrstvy klád, prken a rozpracovaného kusu kreslí skutečný inventář a výrobu.
  `SawmillOperation` pozoruje každý simulační tick, i při dohánění času,
  a jeho historie je jen zobrazovací cache mimo save.
- Tesař u pily má šest pracovních póz. Doma odpočívá opřený s jemným dýcháním
  (`building_worker_idle.gd`), s kontaktním stínem a zastíněním pod střechou
  (`building_worker_appearance.gd`).
- Uživatel 13. 9. přijal pilu v2 pozitivně. Srovnání vlastní pily v2
  a chaty je pracovní vizuální reference, nikoli schválený etalon celé sady.

Autority: [pila v2](docs/art/briefs/sawmill-v2-integration.md),
[zásoby a práce](docs/art/briefs/sawmill-operation-v1-integration.md),
[usazení tesaře](docs/art/briefs/carpenter-sawmill-spatial-v1-integration.md),
[odpočinek](docs/art/briefs/carpenter-idle-v1-integration.md).

### Skladiště

Aktivní je malované **skladiště v2** s perspektivou sladěnou s chatou a pilou;
v1 zůstává jako historie. Vrstva ukazuje jen otevřené či zavřené dveře;
zásoby ani postavy uvnitř se záměrně nekreslí.
Autorita: [skladiště v2](docs/art/briefs/warehouse-v2-integration.md).

### Život budov a noční stavy

`LumberHutLife` a `ProductionBuildingLife` jsou čtecí vrstvy nad skutečnou
přítomností (`inside_building_id`), nikoli nad pouhým přidělením pracovníka.
Noční světlo a kouř zmizely se zrušením dne a noci. Starší art dokumenty
s nočními stavy jsou v tomto bodě historické; komíny a okna zůstávají běžnou
architekturou. Vzor: [život výrobní budovy](docs/art/production-building-life-pattern.md).

### Dřevorubec

**Produkční cesta je PixelLab v2, ne starší imagegen cykly ani Meshy model.**
V normální hře jsou tři činnosti `walk_axe`, `chop`, `walk_log`,
každá v osmi skutečných směrech: **439 fází 256 × 256 RGBA**, tři atlasy.
Dalších 24 vstupních referencí se nepočítá jako animace stání.

- Zdroj, výběr a FPS: `docs/art/animations/lumberjack-pixellab-production-v2/`.
- Runtime: `game/art/units/lumberjack-pixellab-v2/`.
- Sdílená knihovna: `lumberjack_animation_library.gd`; pozorovaný stav:
  `lumberjack_presentation.gd`; pracovní odstup: `lumberjack_work_placement.gd`.
- Chůze se řídí uraženou vzdáleností, sekání skutečným postupem práce.
  Nesená kláda se nekreslí podruhé jako generický náklad.
- Pauza, interiér, mlha, alfa výběr a překrytí korunou
  jsou pokryté regresními testy. Save neukládá rozpracovanou vizuální pózu;
  po load se prezentační historie resetuje.
- Historický běžný průchod menu → Relief → kácení → předání prokázal pokles
  stromu 5 → 4 a nárůst zásoby chaty 0 → 1.

[Herní integrační záznam](docs/art/briefs/lumberjack-pixellab-game-v1-integration.md)
a [skutečné herní QA](docs/art/qa/lumberjack-pixellab-game-v1/README.md)
mají přednost před starými větami „dosud neintegrováno“ v produkčních záznamech.

Meshy T-pose je pouze zachovaný statický experiment: bez kostry, animací a
herní integrace, s přibližně 1,94 milionu trojúhelníků. Uživatel tuto cestu
pozastavil. Nezahajovat další placené rigování z titulu tohoto handoveru.

### HUD

HUD je česky: `ui_text.gd` překládá jen zobrazované názvy, katalog a savy
drží původní ID. `ui_scale.gd` škáluje rám tak, aby větší okno ukázalo víc
mapy místo větších tlačítek. Rámec a konstanty: [HUD layout](docs/hud-layout.md).

## 5. Pravidla další grafické produkce

Závazná jsou [AGENTS.md](AGENTS.md), [manuál budov v0.2](docs/art/building-style-guide.md)
a [společný postup objektů](docs/art/object-implementation-workflow.md).

- **Nejdřív herní půdorys, průchodný vstup a měřítko člověka, potom první obrázek.**
  Variace vyrábět až po kontrole kontaktů se zemí.
  Zvětšení současné chaty bylo výslovnou jednorázovou výjimkou.
- Pro koncepty, revize a integraci budov používat osobní skill
  `medieval-building-design`, je-li dostupný. Pro směrové jednotky
  `pixellab-godot-unit-pipeline`. Oba žijí mimo repo; jejich přítomnost
  v novém prostředí nelze předpokládat. Projektové postupy a záznamy jsou v repu.
- Vlastní architektura a jednotný styl; KaM je inspirace, ne katalog k obkreslení.
  Mírný pohled zepředu zleva a více shora, nikoli čelní nízká kamera.
  Neotáčet kvůli tomu herní mřížku a nevymýšlet přesný historický úhel.
- Zásoby, fyzická přítomnost pracovníka a aktivita jsou různé zdroje stavu.
  Nekreslit je napevno do základního domu.
- Technické dokončení ani požadavek na implementaci **neznamenají výtvarné
  schválení etalonu celé sady**. U chaty, pily, skladiště ani jednotek zatím
  není doloženo. Lesnická chata zůstává další nevyrobený sourozenecký brief.
- Každá profese potřebuje vlastní matici nástrojů, stavů, kontaktů a animací.
- Historický počet generací ani odsouhlasený rozpočet není oprávnění utrácet
  na nových úkolech. API klíč ani místní relay nejsou součástí dodávky.

## 6. Architektura a výkon

Simulace patří do `game/scripts/simulation/`, vstup a kreslení do
`game/scripts/view/`. `world_snapshot.gd` provádí transakční validaci a
migraci: vadný save nesmí změnit rozehraný svět.
Renderer nesmí spotřebovávat zásoby ani posouvat simulační úkoly.
Pathfinding a pohyb čtou shodné ceny; rezervace nákladu/cíle jsou jednoznačné.
Zachovat tyto invarianty i při zmenšování velkých modulů.

Refaktor z 11. 9. nezměnil pravidla ani save. HUD agreguje zásoby jedním
průchodem (**0,983 → 0,382 ms**) a kontrola dosažitelného odběratele končí
u prvního cíle; skutečné vyzvednutí stále vybírá nejlepší cíl původními pravidly.
Viz [refaktorový audit](docs/refactor-audit-2026-09-11.md).

Výkonová práce z 14. 9. (Apple M4, podrobnosti v odkazech):

- **Hledání cest:** packed index se stejnými trasami a pořadím. Průměrný tick
  hráčova savu **5,3 → 1,0 ms**, nejhorší **273 → 9 ms**.
  [Výkon hledání cest](docs/pathfinding-performance.md).
- **Budovy:** cache geometrie a zachované vrstvy zástupných budov. Medián snímku
  save **14 → 9,4 ms**, ekonomické demo **38,7 → 18,9 ms**, pixelově shodně.
  [Výkon vykreslování](docs/render-performance.md).
- **Herní čas:** `MainView._advance_simulation` dohání dlužné ticky jako Remake.
  V běžném demu na 2× drží 100 % času jako dřív; přetížená scéna
  s 40 nosiči navíc na 2× stihne 35 % místo 17 %.
  [Fixed simulation time](docs/godot-architecture.md#fixed-simulation-time).

## 7. Co zbývá a bezpečné další kroky

1. Uživatelské zhodnocení chaty, pily v2, skladiště v2, dřevorubce a tesaře
   v běžné hře; nezaměňovat technické QA za schválení celé výtvarné sady.
2. Další budovy/jednotky vyrábět podle aktuálních postupů, ne kopírováním
   konkrétních kotev, počtů fází a geometrických výjimek jiného objektu.
3. Výkon nejprve změřit na větší osadě. Známí kandidáti:
   - přeplněné scény (uhýbání a přeplánování, `_temporary_blockers_for`);
   - jedno A* na kandidátní úkol v `_assign_task`;
   - bitmapové budovy se kreslí každý snímek (kandidát: statický sprite
     ve vrstvě + animované překryvy);
   - body z auditu 11. 9.
4. Vržené stíny se nekreslí; dynamické stíny ani den a noc nevracet bez nového pokynu.
5. Vojenská část má nábor, vybavení, věž a zásobování, ale **nemá boj,
   taktické povely, střelbu ani obléhání**. Multiplayer není implementovaný.
6. Balance není úplná přesná replika KaM: stavební/výrobní časy a některé ceny
   jsou vlastní; chov ani sklizeň nejsou původní detailní animované procesy.
   Voda zůstává statická a většina objektů používá starší vlastní placeholdery.
7. Každou změnu viditelnou pro hráče zapsat do `[Unreleased]` v
   [CHANGELOG](CHANGELOG.md). Commit, tag, push i vydání jen na pokyn uživatele,
   podle [release process](docs/release-process.md).

## 8. Co se publikuje a co zůstává lokální

Publikace obsahuje herní kód, data, aktuální vlastní assety, testy, nástroje,
postupy, původ grafiky a zachované vlastní experimenty/QA.
Archivní pokusy nejsou runtime závislosti a jejich velikost není spotřeba hry.

Mimo Git zůstávají původní/proprietární data KaM a jejich převody,
lokální referenční klon, `.godot`, cache, ZIP balíky, logy,
surová API komunikace/stavy účtu a znovuvytvořitelná Blender QA scéna.
Od vydání 0.6.0 také **sekvence QA snímků** v `docs/art/qa/**/frames/`,
`motion/` a `*-motion/`. Publikují se jen snímky odkazované z dokumentace
(přidané přes `git add -f`), MP4 záznamy, reporty a README. QA README proto
mohou popisovat sekvence, které veřejný klon nemá.

Z disku se nic z toho nemaže. Produkční atlasy, vybrané jednotlivé snímky,
mastery a textová evidence původu zůstávají dostupné v repozitáři.
Starší auditní odkazy na lokální logy, ZIP nebo původní data nejsou
příslibem jejich přítomnosti ve veřejném klonu.

[Pravidla publikace a původ](THIRD_PARTY_NOTICES.md), [ignorované cesty](.gitignore).
Běžné vestavěné mapy musí fungovat bez původní instalace; volitelný sandbox
s originální referencí a Mountainous Region vyžadují vlastní lokální podklady.

## 9. Zdroje předání

Souhrn kombinuje aktuální zdrojové soubory, datové definice a uvedené dokumenty.
Grafická práce z 12.–13. 9. je doložena integračními a QA záznamy
v `docs/art/`. Zrušení dne a noci, výkonová práce, herní čas a zavedení
verzování (14.–15. 9.) vycházejí z přímé práce s uživatelem a z datovaných
pokynů v [AGENTS.md](AGENTS.md). Seznam projektových tasků předchozího předání
zůstává v [archivu z 12. 9.](docs/handover-archive/2026-09-12.md).
