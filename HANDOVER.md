# Medieval Economy RTS — handover

Stav k **2026-09-12**. Tento dokument je výchozí předání projektu pro další práci.
Popisuje skutečný lokální stav připravený k publikaci, nikoli jen návrhy z konverzací.
Předchozí souhrn je v [historickém archivu](docs/handover-archive/2026-09-09.md);
jeho staré počty testů, save verze a roadmapa nejsou aktuální zadání.

## 1. Rychlý přehled

- **Projekt:** vlastní ekonomická RTS inspirovaná Knights and Merchants, od nuly
  v Godotu; nejde o port Delphi enginu ani distribuci původní hry.
- **Repozitář:** [CubaStromek/medieval-economy-rts](https://github.com/CubaStromek/medieval-economy-rts),
  veřejný, větev `main`, licence AGPL-3.0.
- **Pracovní adresář:** `/Users/openclaw/AI-Projects/medieval-economy-rts`.
  Dřívější `Documents/ChatGPT/KaM` není adresář hry. Nepoužívat symlink jako
  náhradu kořene projektu; aplikace s omezeným zápisem jej nemusí přijmout.
- **Godot:** ověřen **4.7.2 stable**, OpenGL Compatibility, macOS / Apple M4.
  Importovat `game/project.godot`; hlavní scéna je `game_session.tscn`.
- **Simulace:** autoritativní fixed-step **10 Hz**, celočíselná herní mřížka.
  Aktuální zobrazovací buňka je **40 × 40 world px**, nikoli historických 48.
- **Save:** **v21**; zpětná validace/migrace v1–20. Půdorys se verzuje také
  samostatně po jednotlivých budovách.
- **Katalog:** 30 typů budov, 28 surovin, 15 civilních profesí,
  19 výrobních receptů a 14 vojenských náborových definic.
- **Předchozí publikovaný základ:** `7af2a48` z 7. 9.
  Kontrola `git fetch origin` dne 12. 9. před publikací: lokální HEAD i
  vzdálená main byly shodné, bez cizích novějších commitů.
  Nový commit zahrnuje dosavadní lokální práci i toto předání.
- **Čerstvé ověření:** kompletní herní sada **762/762**, konvertor terénu **6/6**
  a místní PixelLab klient **16/16**, bez volání generování či nových nákladů.
  Cílená sada s nativním vykreslováním: **81/81**, bez selhání.
  Samostatná veřejná kopie bez externích dat: nový import a znovu **762/762**.
  Podrobnosti a rozsah dalších kontrol: [ověření publikace](docs/release-verification-2026-09-12.md).

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
| Ekonomická ukázka | 34 × 30, 35 dokončených budov všech 30 typů, nyní 262 obsazených polí |
| Mountainous Region | Volitelná lokální mapa 143 × 127; bez externích dat není dostupná |

Mountainous Region má školu a sklad, bez lidí a cest, celkem 50 zlata a po
20 kládách, prknech a kamenech. Jedno zlato je ve škole pro první výcvik,
49 ve skladu. Má oddělený save slot. Její původní ani převedená mapová data
nejsou součástí veřejného klonu.

`Esc` nejprve ruší aktivní nástroj nebo zavírá detail, potom otevírá pauzové
menu. Testy a QA používají izolované pozice; skutečné hráčovy savy nepřepisovat.
Další ovládání a spouštěče `.command`: [README](README.md).

## 3. Herní stav a závazná rozhodnutí

### Ekonomika, logistika a bydlení

Fungují řetězce dřeva, chleba, vína, ryb, chovu, kůže, uhlí/rud/hutí,
zbraní a zbrojí, tržiště, výcvik a vybavení rekrutů. Ložiska včetně ryb jsou
konečná. Stromy rostou a lesník je sází; pole potřebují skutečnou práci sedláka.

Stavby vznikají z materiálu fyzicky přineseného nosiči a práce stavitele.
Pila vyrábí **2 prkna z 1 klády**. Škola spotřebuje zlato jednou při výcviku.
Rezervace, vážené osmicestné A*, uhýbání, přeplánování a interpolace pohybu
zůstávají součástí běžné simulace.

**Gardener / Forester Hut** je naše vlastní lesnické rozšíření, nikoli
dřevorubec. **Workers' Cottage** poskytuje přesně dvě lůžka nosičům nebo
stavitelům, stojí 3 prkna + 2 kameny; sklad je nouzové ubytování.
Není to obecný rodinný/domácí spotřební systém.

### Den, hlad, mlha a pozastavení

- Den má 6000 ticků = **10 minut při 1×**, hra začíná v 05:00.
  Civilisté od 20:00 do 05:00 nepracují a jdou spát; vojáci a stráže zůstávají aktivní.
- Civilisté se fyzicky stravují v hostinci; vojákovi musí dávku přinést nosič.
  Návštěva hostince má až tři různé chody, ne okamžité doplnění při otočení ve dveřích.
- Aktuální model odděluje sytost od dlouhodobého nedostatku.
  **Smrt až po sedmi celých herních dnech úplně bez jídla od plného stavu**,
  tedy 70 minut při 1×. Nové jednotky začínají najedené.
- Skutečný spánek snižuje úbytek sytosti na polovinu, ale nenatahuje
  sedmidenní kalendářní rezervu. Nedostatek postupně oslabí produktivní práci
  nejvýše o 20 %; chůzi a nosičské zásobování nezpomalí.
  Jídlo rezervu obnovuje poměrně, drobek ji nevynuluje.
- Neprozkoumaná mapa je černá, prozkoumaná zem mimo dohled tmavší;
  cizí jednotky se mimo dohled nekreslí a nesmějí prozradit stav přes UI.
- Detail občana ukazuje **Co si myslím — Teď / Potom** podle jeho skutečného stavu.
  Jednotku a budovu lze pozastavit nezávisle. Pauza práce zachovává náklad
  i postup, neblokuje jídlo, spánek a bezpečný pohyb. Není to globální pauza.
- Jednotka skutečně uvnitř budovy nemá venkovní sprite, stín, náklad ani
  venkovní blokování. Zaměstnání a aktuální fyzická přítomnost nejsou totéž.

Autority: [ekonomika](docs/economy-expansion.md),
[jídlo](docs/food-and-military-supply.md), [den a noc](docs/day-night-analysis.md),
[mlha](docs/fog-of-war.md), [pauza a myšlenky](docs/unit-thoughts-and-pause.md),
[bydlení](docs/worker-housing.md).

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
- Registrace bitmapy, fyzická poloha, výška terénu a vizuální řazení
  jsou samostatné veličiny; nepřesouvat fyzické dveře kvůli zakrytým pixelům.

Autority: [stavba](docs/art/briefs/lumber-hut-construction-v1.md),
[zásoby](docs/art/briefs/lumber-hut-stock-v1-integration.md),
[půdorys v2](docs/art/briefs/lumber-hut-footprint-v2-integration.md).
Jejich QA adresáře obsahují skutečné snímky i rozsah měření, nikoli univerzální
důkaz správného kontaktu na každém možném svahu.

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
- Pauza, interiér, mlha, noční tónování, alfa výběr a překrytí korunou
  jsou pokryté regresními testy. Save neukládá rozpracovanou vizuální pózu;
  po load se prezentační historie resetuje.
- Historický běžný průchod menu → Relief → kácení → předání prokázal pokles
  stromu 5 → 4 a nárůst zásoby chaty 0 → 1.
- Oprava drobných stínů řeší přesnost triangulace relativními souřadnicemi,
  nikoli zahazováním platných malých stínů.

[Herní integrační záznam](docs/art/briefs/lumberjack-pixellab-game-v1-integration.md)
a [skutečné herní QA](docs/art/qa/lumberjack-pixellab-game-v1/README.md)
mají přednost před starými větami „dosud neintegrováno“ v produkčních záznamech.

Meshy T-pose je pouze zachovaný statický experiment: bez kostry, animací a
herní integrace, s přibližně 1,94 milionu trojúhelníků. Uživatel tuto cestu
pozastavil. Nezahajovat další placené rigování z titulu tohoto handoveru.

## 5. Pravidla další grafické produkce

Závazná jsou [AGENTS.md](AGENTS.md), [manuál budov v0.2](docs/art/building-style-guide.md)
a [společný postup objektů](docs/art/object-implementation-workflow.md).

- **Nejdřív herní půdorys, průchodný vstup a měřítko člověka, potom první obrázek.**
  Variace vyrábět až po kontrole kontaktů se zemí.
  Zvětšení současné chaty bylo výslovnou jednorázovou výjimkou.
- Vlastní architektura a jednotný styl; KaM je inspirace, ne katalog k obkreslení.
  Mírný pohled zepředu zleva a více shora, nikoli čelní nízká kamera.
  Neotáčet kvůli tomu herní mřížku a nevymýšlet přesný historický úhel.
- Zásoby, fyzická přítomnost pracovníka a aktivita jsou různé zdroje stavu.
  Nekreslit je napevno do základního domu.
- Technické dokončení ani požadavek na implementaci **neznamenají výtvarné
  schválení etalonu celé sady**. To u chaty a nové herní jednotky zatím není doloženo.
  Lesnická chata zůstává další nevyrobený sourozenecký brief.
- Pro další směrovou jednotku použít dostupný osobní
  `pixellab-godot-unit-pipeline`. Tento skill žije mimo repo; jeho přítomnost
  v novém prostředí nelze předpokládat. Projektové postupy a záznamy jsou v repu.
  Každá profese potřebuje vlastní matici nástrojů, stavů, kontaktů a animací.
- Historický počet generací ani odsouhlasený rozpočet dřevorubce není
  oprávnění utrácet na nových úkolech. API klíč ani místní relay nejsou součástí dodávky.

## 6. Refaktor z 11. 9. a architektura

Herní pravidla a save se tímto refaktorem nezměnily:

- zásoby všech 28 surovin se agregují jedním průchodem přes budovy a pracovníky;
  výstup je čerstvý a nezávislý, i po změně ve stejném ticku;
- panel populace sdílí průchod místo opakovaných přepočtů;
- kontrola, zda existuje dosažitelný odběratel, končí u prvního vhodného cíle;
  **skutečné vyzvednutí stále vybírá nejlepší cíl původními pravidly**;
- odstraněno pět nepoužívaných funkcí a zbytečné eager výřezy atlasu.

Měření z 11. 9. na stejné osadě: HUD **0,983 → 0,382 ms** (−61 %),
ověření dopravy **8 → 1 hledání cesty**. Není to tvrzení o celkovém zvýšení FPS.
Zachovaná metodika, reprodukce a další kandidáti:
[refaktorový audit](docs/refactor-audit-2026-09-11.md).

Simulace patří do `game/scripts/simulation/`, vstup a kreslení do
`game/scripts/view/`. `world_snapshot.gd` provádí transakční validaci a
migraci: vadný save nesmí změnit rozehraný svět.
Renderer nesmí spotřebovávat zásoby ani posouvat simulační úkoly.
Pathfinding a pohyb čtou shodné ceny; rezervace nákladu/cíle jsou jednoznačné.
Zachovat tyto invarianty i při zmenšování velkých modulů.

## 7. Co zbývá a bezpečné další kroky

1. Uživatelské zhodnocení současné chaty a dřevorubce v běžné hře;
   nezaměňovat technické QA za schválení celé výtvarné sady.
2. Další budovy/jednotky vyrábět podle aktuálních postupů, ne kopírováním
   konkrétních dřevorubcových kotev, počtů fází a geometrických výjimek.
3. Zbývající optimalizace nejprve změřit na větší osadě: procházení polí
   a ložisek po řádcích, opakovaná geometrie/pozorovatelé mlhy,
   vyhledávání pracovišť a načítání definic. Viz audit, nejde o hotové opravy.
4. Vojenská část má nábor, vybavení, věž a zásobování, ale **nemá boj,
   taktické povely, střelbu ani obléhání**. Multiplayer není implementovaný.
5. Balance není úplná přesná replika KaM: stavební/výrobní časy a některé ceny
   jsou vlastní; chov ani sklizeň nejsou původní detailní animované procesy.
   Voda zůstává statická a většina objektů používá starší vlastní placeholdery.

## 8. Co se publikuje a co zůstává lokální

Publikace obsahuje herní kód, data, aktuální vlastní assety, testy, nástroje,
postupy, původ grafiky a zachované vlastní experimenty/QA.
Archivní pokusy nejsou runtime závislosti a jejich velikost není spotřeba hry.

Mimo Git zůstávají původní/proprietární data KaM a jejich převody,
lokální referenční klon, `.godot`, cache, ZIP balíky, logy,
surová API komunikace/stavy účtu a znovuvytvořitelná Blender QA scéna.
Z disku se nic z toho nemaže. Produkční atlasy, vybrané jednotlivé snímky,
mastery a textová evidence původu zůstávají dostupné v repozitáři.
Starší auditní odkazy na lokální logy, ZIP nebo původní data nejsou
příslibem jejich přítomnosti ve veřejném klonu.

[Pravidla publikace a původ](THIRD_PARTY_NOTICES.md), [ignorované cesty](.gitignore).
Běžné vestavěné mapy musí fungovat bez původní instalace; volitelný sandbox
s originální referencí a Mountainous Region vyžadují vlastní lokální podklady.

## 9. Zdroje předání

Souhrn kombinuje aktuální zdrojové soubory, datové definice, uvedené dokumenty
a dostupné poslední výměny projektových tasků. Není úplným exportem všech zpráv.

- **Refactor codebase for bloat** — provedené optimalizace a hranice měření.
- **Opravit klády a půdorys hutě** — zásoby 0–6 a výslovná změna na devět polí.
- **Najdi službu pro animace jednotek** — PixelLab, následná herní integrace,
  společný postup a osobní skill.
- **Prozkoumat fáze stavby chatrče** — 12 + 21 kroků a objektové šablony.
- **GRAFIKA** — identita postavy a historie odmítnutých/zvolených nosných póz.
- **GAMEPLAY** — sedmidenní rezerva, myšlenky a jednotlivé pozastavení.
- **Navrhni další ekonomické budovy** — ekonomika a dvoulůžkové obydlí.
- **Přidej hlavní menu hry**, **Připrav start v Mountains** — menu a mapový start;
  u druhého byl dostupný požadavek, realizace ověřena v kódu a dokumentaci.
- **Najdi půdorysy budov Knights**, **Navrhni systém dne a noci**,
  **Analyzuj systém potravin pro jednoty**, **Vytvoř testovací level**, **UI** —
  starší rozhodnutí, překonaná novějšími revizemi tam, kde je to výše uvedeno.
- **Locate repository** a tato předávací konverzace — umístění a Git workflow.

Task **Vytvoř animaci chůze dřevorubce** se při této aktualizaci nepodařilo
načíst; jeho historické varianty proto nejsou vydávány za nově ověřený obsah chatu.
Aktuální produkční stav je doložen následnou integrací a soubory v repu.
