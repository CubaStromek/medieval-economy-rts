# Společný postup pro grafiku a implementaci objektů

Verze postupu **1.1 · 2026-09-10**. Platí pro další budovy, stromy,
dekorace a obrazové vrstvy jednotek tohoto projektu. Vznikl na požadavek
uživatele po implementaci dřevorubecké chaty. Výtvarný manuál budov zůstává
**v0.2**; tento postup nemění kameru, paletu ani schválení obrazového etalonu.

## Začátek každého dalšího objektu

1. Přečíst aktuální `AGENTS.md`, tento postup a existující zadání objektu.
   U budovy také celý [výtvarný manuál](building-style-guide.md).
2. Zkopírovat [implementační šablonu](object-integration-template.md) do
   `docs/art/briefs/<object-id>-<version>-integration.md`. U budovy vytvořit
   nebo aktualizovat [výtvarný brief](building-brief-template.md) a propojit
   ho s implementačním záznamem. Již existující údaje odkazovat, neduplikovat.
3. Pro QA použít [šablonu kontroly](object-qa-template.md) v
   `docs/art/qa/<object-id>-<version>/README.md`. Začít prázdnými výsledky.
4. Pracovat na jednom konkrétním objektu, dokud není ověřený v běžné hře.
   Uplatnit současné zadání uživatele; tento postup nepřidává novou povinnost
   žádat souhlas s již zadanou implementací. Schválení obrazového etalonu
   celé sady zůstává samostatným výslovným rozhodnutím.

Šablony jsou projektové pracovní dokumenty. Nevytvářejí univerzální runtime
formát ani automatický importér. Aktuální kód a katalog jsou autoritou pro
geometrii, stavy, cenu, délku práce a kompatibilitu uložených pozic.

## 1. Zjistit skutečná data a rozsah

Zapsat ID, typ objektu, běžný vstup do hry, vlastníka dat a relevantní stavové
proměnné. Rozlišit již existující objekt s novou kresbou a zcela novou herní
funkci. Vizuální změna sama neopravňuje k novým kolizím, ceně, kameře nebo
formátu save. Zachovat nesouvisející rozpracované změny.

| Druh | Co ověřit před kresbou | Co se nepřebírá automaticky |
|---|---|---|
| Budova | Maska, práh, vstup, srovnávání, stavba, inventáře, obyvatelé | Počet kroků a architektura chatrče |
| Strom / ložisko | Kontakt se zemí, růst/vytěžení, kolize, množství | Dveře, stavební masky, trvání stavby |
| Dekorace | Zda je průchozí, kotva, orientace, varianty, viditelnost | Nové blokování polí nebo herní zásoby |
| Jednotka / pohyblivý objekt | Bod chodidel, směry, klipy, pohyb, interiér, náklad | Registrace podle dveří či spodku každého snímku |

Při referenci na KaM zapsat přesnou verzi a zdroj: původní grafická data,
zdrojový kód Remaku, nebo jen vizuální pozorování. U požadavku „stejný počet“
změřit konkrétní objekt. **12 + 21 je ověřená dřevorubecká chata, nikoli
univerzální počet pro všechny budovy.** Počet barevných masterů, masek,
změn obrazu a pracovních ticků jsou odlišné údaje. Původní KaM grafiku
nepoužívat jako vlastní produkční master, masku či přebarvovaný podklad
a nepřibalovat do distribuovaných assetů. Případnou výslovně zadanou
externí pohledovou/stylovou referenci evidovat jako referenci; nesmí
být vydávána za vlastní kresbu nebo povolení obkreslit její architekturu.

## 2. Připravit herní podklad a změřit kotvy

Nejprve získat skutečný výřez terénu s obsazenými a volnými políčky,
vstupní cestou, výškou a referenční jednotkou. U budovy ověřit předolevý
nadhled podle manuálu. Měřítko určovat z kontaktů se zemí a člověka,
nikoli ze šířky PNG včetně průhledného okolí.

| Veličina | Úloha | Co nesmí omylem měnit |
|---|---|---|
| Mapová poloha / footprint | Simulace, kolize, obsazená zem | Výtvarná registrace ji nepřepisuje |
| Obrazová kotva | Práh, kořen nebo chodidla ve zdrojových px | Hloubkové řazení ji neposouvá |
| Výšková projekce | Skutečná výška země pod kontaktem | Nepřidává pomocnou levitaci |
| Bod pro řazení | Pořadí terénu, stromů, domů a lidí | Není nový fyzický bod ani stín |
| Pozemní stín | Příjemce na skutečném terénu | Nekopíruje pomocný posun řazení |
| Kotvy UI a stavů | Popisek, zboží, přítomnost, náklad | Nerozšiřují právo odhalovat skrytá data |

Obecná registrace v našich 2D světových souřadnicích:

```text
levý_horní_roh_kresby = projekce_skutečné_kontaktní_kotvy
                        − obrazová_kotva_v_px × world_px_na_zdrojový_px
```

Všechny stavy a vrstvy téhož objektu drží stejný souřadnicový systém. Samostatný
ořez je možný jen se zachovaným trim offsetem a ověřením všech snímků.
U pohyblivých jednotek zohlednit skutečné směry a klipy; neodvozovat
polohu chodidel z měnícího se obalu meče, nákladu či animované končetiny.

**Výslovný pokyn uživatele, 2026-09-10: další generované objekty se musí vejít
do předem určeného půdorysu.** Skutečnou masku/kolizi, vstup a měřítko vložit
do obrazového zadání jako podklad. Již první koncept nad tímto podkladem
zaregistrovat a změřit kontakty stěn, patek a neprůchozích rekvizit. Ty patří
do obsazené země; nesmějí vizuálně blokovat volná pole ani dveřní přístup.
Střešní přesah posoudit odděleně od zemní zdi či stojanu. Vyzkoušet i hranu
vyvýšené roviny, nikoli pouze stejně vysoké okolí celého objektu.

Nevyhovující koncept opravit **před výrobou stavebních fází a dalších variant**;
nezachraňovat kresbu automatickým rozšířením herní kolize. Uživatel dne
2026-09-10 výslovně povolil zvětšit půdorys již vyrobené dřevorubecké chaty,
aby zůstala její kresba i stavební sada. Jde o konkrétní výjimku, nikoli
o oprávnění měnit půdorysy dalších objektů. Kontrola konceptu je výrobní krok,
ne nová povinnost žádat souhlas s již autorizovanou prací.

## 3. Navrhnout vrstvy a stavový postup

Vytvořit jeden vlastní, registrovaný základ. Z něj odvozovat další stavy
se stejnou geometrií. Proměnlivé zboží, osoby a pracovní efekty nepatří
do statické kresby. Naplánovat zadní a přední části objektu, pokud musí
správně překrývat zboží nebo člověka.

U postupně stavěné budovy lze použít ověřený princip dvou masterů:
dokončená prázdná stavba a její nedokončená konstrukce, doplněné maskami
pořadí. Není nutné generovat každý krok jako samostatný dům. Tento princip
nenutit stromům, jednotkám nebo stavbě, která potřebuje jiný počet vrstev.

Každá maska musí mít doložený význam a pořadí souvislých stavebních částí.
Patky → nosné části/stěny → krov → krytina/dokončení; konkrétní pořadí
odpovídá architektuře. Neodkrývat drobnou součást bez její podpory nebo
celé vybavení náhlým skokem v posledním kroku. Dokončovací vrstva musí
umět také odstranit dočasné podpěry a otevřít průhledné mezery.

Zdrojem postupu je skutečná simulační práce. Samotné plynutí času, příchod
nosiče nebo animace kladiva práci nenahrazují. Zapsat hranice fází,
zaokrouhlování, stav 0, poslední grafický krok a skutečné dokončení.
Poslední grafický krok nesmí předčasně povolit produkci. Srovnávání
terénu, stavba a dokončený provoz jsou oddělené stavy.

## 4. Vyrobit a technicky zkontrolovat vlastní obrázky

Použít příslušný obrazový nástroj a prohlédnuté vlastní reference;
archivovat skutečná zadání, vstupy, výstupy a identifikovaný nástroj/model.
Model neuvedený nástrojem nevymýšlet. Technický export může provést
změnu rozměrů, registraci a masky; nesmí nahrazovat kontrolu návrhu.

- Ověřit skutečný alfa kanál v souboru, vnější pozadí i vnitřní otvory.
  Ani přípona PNG, ani prompt „transparent“ nejsou důkaz průhlednosti.
- Pokud přímý výstup obsahuje namalovanou šachovnici, odmítnout ho jako
  RGBA vstup. Možná náhrada je vlastní kresba na jednobarevném technickém
  pozadí a měřený export alfy. Barva klíče nesmí být v samotném objektu.
- Při klíčování měřit reálnou barvu a její odchylky. Vyčistit barevný lem,
  ověřit tmavý, světlý a skutečný herní podklad. Prahy chatrče nekopírovat
  na jiný obraz; její klíčovací export očekává RGB zdroj na purpurové ploše.
- Zapsat canvas, alfa obal s prahovou hodnotou a konvencí hran, kotvy,
  měřítko, trim, zdrojové i exportní otisky. Nulové rohy samy nestačí.
- Pro celočíselné masky zachovat hodnoty bez ztrátové komprese nebo
  změny barev. Ověřit je znovu po skutečném importu v Godotu.
- Zkontrolovat neprázdné kroky, odlišnost výsledných obrazů a přesnou
  shodu posledního stavu s finálním masterem. Pokud jsou stejné snímky
  záměrná výdrž animace, odlišit je od chybějícího stavebního kroku.

## 5. Zapojit do skutečné herní cesty

Zapsat čtenáře metadat a skutečný vstup do hry. Ověřit řetězec hlavní
menu → mapa / načtená pozice → hlavní scéna → správná větev vykreslení.
Pomocná scéna s ukázkou sama nezajišťuje herní implementaci. Při dodávce
samostatného exportu ověřit také zabalené PNG, masky a JSON v tomto exportu;
fungující lokální import není důkaz distribuovaného balíku.

Použít stejný bod řazení pro kreslení a odpovídající test zakrytí při
klikání. Zachovat výběr obsazené země; u kresby mimo půdorys testovat
skutečnou alfu, ne celý průhledný obdélník nebo starý vektorový obrys.
Pozemní výběr patří pod kresbu; text a ukazatele do vlastních stabilních
kotev mimo její čitelné části. Všechny stavové vrstvy projdou mlhou,
světlem a řazením jejich objektu. Známá silueta není oprávnění odhalit
živý cizí inventář nebo skryté osoby.

Načtení, skládání fází a hit masky ukládat do cache; neprovádět celý
pixelový export v každém vykreslovaném snímku. Cache oddělit podle objektu
a verze. U většího počtu objektů změřit náběh a paměť; současná chatrč má
34 RGBA textur s mipmapami a nelze bez měření násobit tento model katalogem.
Po změně assetů obnovit import a spustit novou herní instanci.

Současný pilot při 640² drží přibližně 71 MiB samotných RGBA textur
s mipmapami plus hit masky a dočasná data; jde o výpočet kapacity,
nikoli naměřenou celkovou paměť procesu.

### Co je dnes příklad a co je obecné

| Existující soubor | Využitelný princip | Parametry specifické pro chatrč |
|---|---|---|
| `game/scripts/view/lumber_hut_sprite_library.gd` | Registrované fáze, cache, alfa výběr | Cesta, ID, footprint v1, 12/21, hranice 60/40, statická cache jedné sady |
| `tools/pack-lumber-hut-construction.cjs` | Vlastní masters → RGBA → masky → ověření | Vstupy, rozměry, všechny polygony, klíčování, kotvy, počty |
| `game/scripts/view/main_view.gd` | Oddělená vizuální hloubka a skutečná zem | Výběr knihovny podle konkrétního objektu |
| `game/tools/preview_lumber_hut_construction.gd` | Snímky skutečné hlavní scény | Mapa, ID, stavební vzorky, kompozice a názvy výstupů |

Pouhé přejmenování PNG či změna `building_id` v manifestu další objekt
nezapojí. Při druhém konkrétním objektu rozhodnout, co společně zobecnit
v kódu a co zůstane jeho daty; zachovat regresní pokrytí první chatrče.
Tento dokument sám takové zobecnění neimplementuje.

Další přesná omezení aktuálního příkladu:

- Masky chatrče čtou **červený byte**: konstrukce 1–12, dokončení 1–21,
  nula znamená nikdy. Alfa masky neurčuje odkrývání. Dokončení přepisuje
  všechny RGBA složky včetně průhlednosti. Původní KaM masky mají jiné
  indexování; při porovnávání nemíchat původní hodnoty a náš export.
- `sort_foot` má ve zdejších metadatech dvě složky, ale aktuální řazení
  chatrče používá jen jeho Y; X ponechává mapové kotvě. Nejde o hotovou
  univerzální implementaci libovolného 2D bodu pro všechny objekty.
- Čtenář ověřuje některé registrační údaje, zdroje, rozměry a skupiny
  masek, ale ne celé schéma, všechny konečné číselné hodnoty, otisky nebo
  úplnost alfa pokrytí. Při novém čtenáři tyto vstupy výslovně validovat;
  dnes další důkazy poskytují exporter a testy. Pole přítomné v JSON
  není samo o sobě potvrzením, že ho hra čte nebo kontroluje.

## 6. Při chybě usazení nejprve určit příčinu

| Příznak | První kontrola | Možná oprava podle důkazu |
|---|---|---|
| Rovná tráva uřízne dolní část | Řádky terénu, bod řazení, skutečný spodní pixel | Oddělená stabilní hloubka a shodné klikání |
| Objekt poskakuje mezi stavy | Canvas, trim, kotva, měřítko a klíč řazení | Sjednotit registraci všech vrstev |
| Celý dům je stejně posunutý | Skutečný práh, zdrojová kotva, výšková projekce | Opravit nesprávnou registraci |
| Patky visí nad svahem, kresba je celá | Kontakty země a přesahy mimo obsazenou masku | Překalibrovat vlastní kresbu a podklad |
| Kliká se prázdné okolí nebo stará střecha | Alfa, aktuální hit tvar, terénní zakrytí | Sdílet viditelnou geometrii s výběrem |
| Barevný obdélník či lem | Alfa, klíčované pozadí, mipmapy a import | Opravit export; nebarvit okolí na trávu |
| Výběr / text přetíná střechu | Pořadí kreslení a kotva UI | Výběr pod objekt, vlastní kotva popisku |

KaM Remake kreslí celý terén před objekty a odděluje `Loc` od `Feet`.
Naše hra terénní a objektové řádky prokládá. [Zdrojový rozbor](kam-object-terrain-rendering-study.md)
dokládá rozdíl; neříká, že máme stejný renderer nebo že máme všechny
objekty přesunout nad všechny kopce. Půl políčka v bodu řazení chatrče
není obecná fyzická výška všech objektů. Stabilní bod odvodit a ověřit
pro konkrétní registraci; nepočítat jej z živého alfa obalu každé fáze.

## 7. Ověřit a předat

Vyplnit [QA záznam](object-qa-template.md): relevantní simulační testy,
skutečné nativní obrázky a běžnou cestu spuštění. U regrese zakrytí použít
test viditelného pixelu s kontrolním nezakrytým obrazem nebo obdobný
průkazný test. Headless průchod nedokazuje správné výsledné pixely.

Při nových změnách opakovat dotčené kontroly; po úspěchu nerozšiřovat
testování bez dalšího důvodu. Zachovat datum, engine, revizi, otisky
assetů a konkrétní výsledek. Technický průchod, vizuální nedostatky a
uživatelské schválení uvést odděleně. Předat fungující stav, snímek či
animaci, stručný popis a skutečně zbývající omezení.

## Doložený příklad, nikoli automatický etalon

[Dřevorubecká chata v1](briefs/lumber-hut-construction-v1.md) má vlastní
RGBA, 12 + 21 kroků a ověřené řazení; [QA](qa/lumber-hut-construction-v1/README.md)
dokládá i dosud nedoladěné patky na svahu a proporce dveří. Tato omezení
nekopírovat jako standard dalšího objektu. Původní [v3 koncept](briefs/lumber-hut-v3.md)
není zaměnitelný s produkčním exportem a technický pilot není automaticky
schválenou výtvarnou referencí celé sady.
