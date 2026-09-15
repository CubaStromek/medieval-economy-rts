# Dřevorubecká chata — dveře, odpočinek a noční život

Datum **2026-09-12**. QA podle [společné šablony](../../object-qa-template.md).
Budova `lumber_hut`, doplnění samostatných stavových vrstev; vlastní
[brief life v1](../../briefs/lumber-hut-life-v1.md),
[implementační záznam](../../briefs/lumber-hut-life-v1-integration.md),
výtvarný směr v0.2. **Nativní obrazová kontrola prošla; běžný pracovní
cyklus a zaměřené herní testy jsou samostatné důkazy níže.** Uživatelské
výtvarné přijetí se z technických kontrol neodvozuje.

**Následné upřesnění 2026-09-12:** otevřené neosvětlené okno při denním
odpočinku a rozhlížení hlavy má [vlastní nové QA](../lumber-hut-life-look-v1/README.md).
Zdejší původní snímky a hashe jsou zachované jako důkaz před tímto
upřesněním; nezachycují novou animaci hlavy ani denní otevřené okno.

[Den venku / odpočinek doma / noc](showcase.png) ·
[Kouř v pohybu — 3 s](smoke-in-game.gif) ·
[Všech pět stavů při 1×](life-zoom-1-00.png) ·
[Detail 2.4×](life-zoom-2-40.png) ·
[Oddálení 0.75×](life-zoom-0-75.png)

## Přesný rozsah

Nové dveře, odpočinková postava, svit okna a kouř používají skutečné
stavy dokončené chaty ve `res://scenes/main.tscn`. Statický dům, zásoby,
stavební sada, fyzický půdorys ani herní pravidla nejsou tímto QA změněné.
Registraci domu a devět aktuálně obsazených polí určuje
[půdorys v2](../../briefs/lumber-hut-footprint-v2-integration.md);
nové body efektů jsou zdrojové souřadnice ve stejném canvasu, nikoli
nová fyzická výška nebo kolize.

| Měřený kontrakt | Důkaz |
|---|---|
| Canvas domu, měřítko | 640 × 640 zdrojových px; prezentace za běhu má 0.225 world px / source px; finální manifest uvádí každou kontrolovanou registraci |
| Postava, alfa, chodidla | Vlastní oddělený `resting_lumberjack.png`: canvas 256², alfa >0 obal (94,42)–(152,206), hranice výlučné. JSON uvádí 59 591 průhledných / 1 326 částečných / 4 619 neprůhledných pixelů, kalibrované tělo 33 world px a kontakt (128.466,205.229) source px. Nativní prohlídka kontroluje výslednou postavu na fasádě/terénu. |
| Dveře, okno, komín | `DOOR`, `WINDOW`, `CHIMNEY` v `lumber_hut_life.gd`; kontrolní pixely se mapují stejným obrazovým obdélníkem a skutečnou kamerou |
| Fyzická přítomnost | Přidělený dřevorubec vstupuje/vystupuje pomocí `IndoorWorkers.enter/leave`; návštěva či nesená kláda nejsou odpočinek |
| Terén | Vyvýšený test odvozuje rovnou plošinu z vrcholů aktuálních obsazených polí, výška 6; vstup musí zůstat průchozí |

## Běžná hra a oddělené obrazové vzorky

**Běžná cesta menu → Relief → skutečná těžba → návrat → odpočinek →
odchod → noc prošla přímo v aktuálním projektu.**
[Protokol a stavy](natural-final/report.json), [běhový log](natural-final/run.log),
[odpočinek](natural-final/day-rest.png), [odchod](natural-final/day-exit.png),
[skutečný návrat na noc](natural-final/night-home.png).
Čerstvá instance prošla skutečnými tlačítky menu. V běžné simulaci
dřevorubec odevzdal kládu v ticku **117**, odpočíval a odešel v ticku
**125**. Spánek doma dosáhl v ticku **3774** (první den 20:05), se
zavřenými dveřmi, světlem a kouřem. Celkem **10 fází, 20 snímků,
0 selhání**, exit 0. Hlavní agent prohlédl finální noční obraz s HUD.

Denní cesta používá skutečný `_process` při rychlosti 4× a pauzy pro
snímání. Poté ověřovací scénář provede každý skutečný simulační tick
v dávkách po 32, aby nečekal na několik minut kreslení; nevynechává
tick, neposouvá přímo hodiny, osoby ani inventáře. Jde o zrychlený
simulační průchod do noci, nikoli záznam plynulého nočního videa při 4×.
Po dosažení spánku znovu zachytí skutečný hlavní renderer. Hráčovy savy
nebyly použity ani změněny. Starší `natural/` je nedokončený předchozí
běh do denního odchodu, ne finální přejímka.

`game/tools/preview_lumber_hut_life.tscn` vytvoří izolovaný svět 32 × 24,
chatu na (14,12) a přiděleného pracovníka. Používá skutečný `Main`,
produkční kreslení, terénní řádky, noční tónování a mlhu. Testovací
proces je pro statické snímky zastaven, tick, činnost a náklad jsou
výslovně nastavené. Pracovník venku je ve fixture přemístěn mimo dveře,
aby nemohl falešně ovlivnit pixelové kontroly okna a dveřního listu.
Přesun není vydáván za simulovanou chůzi. Tři klády jsou nastavený inventář,
nikoli důkaz skutečného předání.

Hráčovy savy a nastavení se nečtou ani nepřepisují. Hudební controller
není instancovaný; k běhu není přidaný žádný zvuk.

## Kontroly a výsledky

| Kontrola | Scénář | Výsledek |
|---|---|---|
| Stav a čitelnost | Den venku / den doma / odevzdávání / noc doma / noc venku, 0.75× / 1× / 2.4× | Prošlo: všech 15 nativních stavových snímků, prohlédnuté tři kontaktní archy a detailní showcase. V oddálení jsou jednotlivé detaily malé, funkční stav okna/odpočinku je nejčitelnější při 1× a v detailu. |
| Alfa a filtrace | Postava na skutečném terénu a fasádě, detail 2.4× | Prošlo v dodaných záběrech: žádná šachovnice, podkladový obdélník nebo purpurový lem; vlastní póza má prázdné složené ruce. |
| Kontakt a řazení | Rovina, vyvýšená plošina, strom v popředí | Prošlo: [zvýšený základ](frames/raised-home.png) drží registraci a průchozí vchod. [Strom na volném (16,13)](frames/occlusion-home.png) zakrývá spodní část postavy i domu ve správném pořadí. Není to ověření všech možných sousedních svahů. |
| Kotvy | Dveře, okno a postava nemění obdélník domu; noční kouř nad vlastním komínem | Prošlo: shodný obdélník ve všech stavech, otevřený průchod je vedle postavy volný, kouř začíná na kamenném komíně. |
| Klikání a výběr | Světlo a kouř nejsou klikací; skutečná alfa postavy rozšiřuje výběr domu | Prošlo: zaměřená sada kontroluje neprůhledné body, průhledné okolí a skrytí při noci/nepřítomnosti/mlze. Boty leží uvnitř skutečného půdorysu. |
| Cizí mlha | Domácí přítomen/venku ve stejné prozkoumané i neznámé mlze; celé snímky musí být totožné | Prošlo: oba páry mají **0 změněných pixelů**, `known=false`; snímky `frames/fog-explored-*.png`, `frames/fog-unknown-*.png`. |
| Světlo | Kontrola dveřního listu a pozitivní kontrola nočního jasu v okně | Prošlo všech šest kontrol při třech zoomech: dveře mění všech 25 px vzorku; maximální nárůst luminance okna 0.635 / 0.617 / 0.524. Teplé sklo zachovává dřevěný kříž; světlo zůstává lokální. |
| Čas | Pauza skutečného `_process` při speed 0, pak různé fáze kouře | Prošlo: pauza **0 změněných pixelů** celého snímku; různé fáze mění **2 118 pixelů** regionu nad komínem. Čas a svit se během pauzy nehýbou. |
| Uložení a starší varianty | Skutečný stav odvozovaný z uložených polí; legacy fallback | Prošlo: skutečný JSON roundtrip spánku/přítomnosti, půdorysy v1/v2 a původní fallback v0. |
| Běžná scéna / výkon | Skutečný pracovní cyklus a normální herní panel | Prošlo 10 fází / 20 nativních snímků ve výše popsaném běžném průchodu. Hromadný benchmark stovek chat není součástí ověření. |
| Stavba | Žádné life vrstvy během přípravy ani rozestavění | Nových 33 stavebních snímků není třeba: artwork kroků se nemění; zaměřená sada ověří dokončovací bránu |
| Stromy / další směry jednotky | Nevzniká nový strom ani směrová sada chůze | N/A — rozsah jsou stavové vrstvy jedné chaty |

První nativní prohlídka zjistila málo čitelný kouř. Region nad komínem
u zachycených nočních snímků se při přítomnosti změnil v 1 540 pixelech,
ale maximální změna kanálu byla jen 16/255. Samotný nenulový rozdíl
nebyl uznán za dostatečnou výtvarnou čitelnost. Po úpravě průhlednosti a
kompenzaci nočního tónu má konečný region (285,13), 75 × 101 px, při
srovnání obývané/prázdné chaty **1 963 změněných pixelů**, maximum **74/255**
(příklad RGB [34,37,21] → [93,98,95]). V [konečném přehledu](showcase.png)
je měkký stoupající pruh čitelný; v animaci je patrnější než ve statickém snímku.
První vyvýšená fixture navíc používala historický rozsah původního
náhledu; opravena byla pouze testovací plošina podle současného půdorysu.
Musí vzniknout před položením chaty: produkční ochrana správně odmítá
libovolně přepisovat výšky pod již postavenou budovou.

## Reprodukce a nezávislé pozitivní kontroly

```text
godot --path game --windowed --log-file /tmp/lumber-hut-life-native.log res://tools/preview_lumber_hut_life.tscn
```

Konečný běh **2026-09-12 13:25:22** přímo z aktuálního pracovního projektu
prošel s návratovým kódem **0**, **57 obrazovými záznamy** (53 samostatných
herních snímků + 4 kontaktní archy), **10/10 pixelovými kontrolami** a bez
chyb skriptů či triangulace. [Log](native-run.txt) ·
[Manifest a přesné výsledky](capture-manifest.json) ·
[Shoda souborů a ověření animace](native-verification.json).

Proces se po konečném manifestu sám ukončí. Godot 4.7.2, macOS,
Compatibility/OpenGL 4.1 přes Metal, Apple M4; okno 1000 × 650,
skutečný herní SubViewport 480 × 420. Otisky kódu a assetů jsou
uložené v `capture-manifest.json` ze stejné čerstvě spuštěné instance;
všech pět zaznamenaných produkčních souborů odpovídalo pracovním souborům
po dokončení běhu. Starší chybové pokusy nejsou finální přejímkou.

Dočasný problém během práce: souběžně upravovaný `night_wolves.gd`
obsahoval duplicitní lokální `index` a chybu závorek přetypování. Kvůli
tomu proběhl meziběh v `/tmp/lumber-hut-life-validation/game` s těmito
dvěma opravami izolovanými od pracovní verze. Po opravě týchž dvou řádků
v projektu hlavním agentem se celá tato konečná obrazová sada znovu
zachytila přímo z `game`; současná evidence tedy není závislá na dočasné kopii.

- Dveře: zdroj (560,355), mapovaný skutečnou kamerou; 5 × 5 px musí
  mezi otevřením/zavřením změnit nenulový počet pixelů.
- Okno: zdroj (486,365), 5 × 5 px; alespoň jeden pixel se musí zesvětlit
  o více než 0.025 luminance. Okolí bodu obsahuje sklo i zachovaný kříž.
- Mlha: doma a venku při stejném ticku a kameře musí mít **0** změněných
  pixelů v celém snímku. Pozitivní kontrolu dosaženého nočního stavu
  poskytuje viditelná vlastní chata a její lokální okno.
- Pauza: oba snímky mají shodný tick i zbytek simulačního času; mezi
  nimi proběhne čekání 0.4 s a `_process(0.4)` při nulové rychlosti.
  Celé snímky musí být totožné, včetně svitu a kouře.
- Kouř: po zmrazení se samostatně vzorkuje 30 po sobě jdoucích
  produkčních časů od 475.037 do 477.937 s, krok 0.1 s; region nad
  komínem musí při změně fáze změnit skutečné pixely. Případná animace
  přehrává tyto snímky s výdrží 0.1 s, žádné mezisnímky se nedokreslují.

## Výsledek této verze

### Zaměřené a regresní testy

- **11/11** zaměřených skupin prošlo na konečné pracovní verzi,
  [log](focused-tests.log): přidělení versus fyzický pobyt, návštěvník,
  skutečný poslední krok do dveří/odevzdání/pobyt/odchod, noc/úsvit,
  individuální pauza, zásoby 0/6, cizí soukromí před čtením pracovníků,
  stavba a verze půdorysu, JSON save, skutečný import/alpha/kontakt bot,
  čas hlavní scény a pauza. Přímý příkaz:
  `godot --headless --path game --scene res://tests/lumber_hut_life_runner.tscn`.
- **10/10** nativních pixelových kontrol, 57 záznamů obrazů,
  [finální ověření a otisky](native-verification.json), včetně nulového
  rozdílu při pauze a cizí skryté přítomnosti. Dům, stavební podklady
  a zásobní rastry zůstávají původní.
- První úplná sada během souběžných změn vypsala **788/788** úspěšných
  případů, ale zároveň obsahovala chyby přetypování v právě rozpracovaném
  systému vlků ([log](full-suite-during-parallel-work.log)); proto se
  **neoznačuje za bezchybný běh celého projektu**. Dvě malé následné opravy
  zápisu v `night_wolves.gd` ověřil [přímý probe](wolf-syntax-probe.log):
  vytvoření skutečné smečky a plánování prázdné i neprázdné cesty, exit 0.
  Později přidaná samostatná vlčí sada měla během souběžné práce neplatné
  přípravy budov/obyvatel a čas úsvitu: 12 případů, 10 neúspěšných kontrol
  a přístup k neexistujícímu obyvateli 0 ([log](wolf-suite-during-parallel-work.log)).
  Tato rozpracovaná sada nebyla v grafickém úkolu opravována ani přijata.

Skutečný nativní průchod menu a nocí lze zopakovat:

```text
godot --path game --windowed --resolution 1280x800 --scene res://tests/lumber_hut_life_game_runner.tscn -- --speed=4 --capture=/absolute/qa/output
```

Technická nativní integrace a prohlídka: **prošla v uvedeném rozsahu**.
Prohlédnuto hlavním agentem i QA agentem: showcase, běžné přiblížení,
detail, zvýšená plošina a překrytí postavy stromem. Dveře jsou zavřené
při odchodu, při odpočinku otevřené; postava stojí při sloupku a nepřekáží
v otvoru; při odevzdávání se nepředstírá odpočinek. Noční chata má teplé
okno, zavřené dveře a měkký kouř, prázdná noční chata zůstává tmavá.
Uživatelské přijetí této vrstvy ani společného etalonu: **neuděleno**.
Starší usazení domu a jeho styl nejsou novou vrstvou automaticky schválené.
