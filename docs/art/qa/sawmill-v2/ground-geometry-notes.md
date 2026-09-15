# Pila v2: guide a první čtyři skutečná měření — 2026-09-12

Tento dílčí záznam patří ke geometrii obrazového návrhu. Nenahrazuje
[integrační QA](README.md), které zatím nepotvrzuje finální asset ani nativní scénu.
Nevznikl žádný export produkčního PNG, runtime úprava ani změna půdorysu.

## Původní měřený guide

Autoritativní původní generovací podklad je [ground-guide.png](ground-guide.png).
Jeho SHA-256 je `430d05965aee4c3bce7e33e866c35caa66301d2802a7094cca610ee35eef9136`.
Po souběžném přepsání stejně pojmenovaného pomocného zdroje byl obnoven
[vektorový generátor](../../sources/sawmill-v2/build-ground-guide.cjs) a
[SVG](../../sources/sawmill-v2/ground-guide.svg). Obnovený generátor zapisuje pouze
[ground-guide-rebuilt.png](ground-guide-rebuilt.png); původní použitý raster se
nepřepisuje. Geometrie i registrace skutečné vlastní postavy jsou shodné, drobná
typografie se může lišit. Rychlý `ground-guide-minimal.*` z hlavní větve práce
nebyl použit jako obrazový vstup generace.

[geometry.json](geometry.json) uchovává původní technický kontrakt:

- Canvas 800², čtyři zdrojové pixely na jeden světový pixel, 160 zdrojových pixelů
  na políčko. Obsazený obdélník `(80,320)..(720,640)` znamená současných 160×80
  světových pixelů a osm buněk; herní mřížka se neotáčí.
- Úsporné zemní nároží `(284,620),(700,504),(564,356),(148,472)` celé leží uvnitř.
  Přední hrana stoupá doprava v poměru 116/416. To je obrazový směr, nikoli
  vymyšlený číselný sklon 3D kamery.
- Prahová registrace `(320,640)`, skutečná volná vnější vstupní buňka
  `x240..400 / y640..800`. Mělký vstupní schod leží ještě uvnitř půdorysu.
- Stávající vlastní tesař byl jednotně zmenšen z výšky těla 165 na132 zdrojových
  pixelů: přesně33 světových pixelů. Dveře mají mít35–37 světových pixelů.
- Hodnota nejvyššího povoleného bodu střechy `y72` je navržený okraj canvasu,
  nikoli povinná výška střechy. Výška a střecha smí obrazově vystoupit nad zem.

[guide-validation.json](guide-validation.json) kontroluje aritmetiku, všechny
zemní vrcholy, schod, skutečný obrazový vstup i novou reprodukci.

## Koncept01: lepší obrazový směr, ignorovaná registrace

Skutečný [koncept01](../../sources/sawmill-v2/concept-01.png) má1254² a není
přesně posazený do původního guide. Má zřetelně vhodnější stoupající čelní hrany,
čitelné horní plochy a širší oblé šindele. Původní `source_to_world=0.25` z guide
se proto nesmí bez měření převzít do tohoto nového obrazu.

Pro práh přibližně `x400` vyžaduje pravý patník `x1228` raw scale přibližně0.12:
828×0.12 =99.36 světového pixelu z dostupných100 vpravo od vstupu. Levý přední
patník sahá jižněji než střed schodu. Prah přesně na schodu `y995..1000` by tedy
přesahoval obsazenou jižní hranu; potřebuje buď drobnou výtvarnou opravu nebo
registraci těsně před schodem.

[Zvětšený výřez](concept-01-door-detail.png) a [pravítko](concept-01-door-ruler.png)
ukazují světlé dveřní pole přibližně
`(336,786),(397,768),(397,904),(336,920)`: výška134–136 raw pixelů, tj. pouze
16.1–16.3 světového pixelu při0.12. Měření je ruční s nejistotou přibližně5 raw
pixelů; nepravidelný rám nelze vydávat za dokonale geometrický otvor. Důležitý je
absolutní cíl nového otvoru kolem300 raw pixelů, nikoli pouhé relativní zvýšení.

## Koncept02: základ pro další výškovou korekci

[Koncept02](../../sources/sawmill-v2/concept-02-key.png) viditelně zvýšil stěny
a dveře, zachoval směr i hlavní nábytek. Jeho dveře stále nedosahují výšky33
světových pixelů; další cílené zvýšení je oprávněné.

Diagnostické měření viditelného spodku v řádcích `y>=740` vrací podle citlivosti
vůči růžovému okraji bbox `(34..1228,740..1028)`; čísla jsou inkluzivní pixely.
Nejde o produkční alfa masku ani důkaz skrytého půdorysu. Souřadnice a otisky
jsou v [concept-geometry-review.json](concept-geometry-review.json).

Navržený fyzický vstup raw `(400,1030)` leží těsně před nejnižším patníkem a
přibližně22 raw pixelů před středem spodní hrany schodu. Při0.12 jde o2.64
světového pixelu. Tento malý rozdíl je nutné ověřit přímo při vstupu člověka
a na zvýšeném základu, ne jej vydávat za hotovou kalibraci.

Při raw scale0.120 je pravá mez přibližně99.4 světového pixelu od vstupu;
jižní mez je jen asi0.24 světového pixelu uvnitř. Varianta0.1195 dává malou
rezervu, aniž mění proporce. Při uniformním exportu1254→800 tomu odpovídají
`source_to_world=0.1881` nebo `0.18731625`. Dveřní světlá výška300 raw pixelů
pak znamená36 nebo35.85 světového pixelu. Konkrétní finální výstup se musí
změřit znovu, protože generátor může při opravě posunout i zdánlivě pevné body.

Volný vnější přístup se zachovává. Herní půdorys se kvůli obrazu nezvětšuje.
Následné zásoby i tesař potřebují vlastní kontaktové kotvy vůči finálnímu domu;
staré kotvy z v1 nejsou měřením v2.

## Koncept03: výška dospělého, potřebné rozšíření dveří

Aktuální [koncept03](../../sources/sawmill-v2/concept-03-key.png) se měří zvlášť,
nikoli převzetím čísel02. [JSON](concept-03-geometry.json),
[kontaktní náhled](concept-03-contact-guide.png) a [dveřní pravítko](concept-03-door-ruler.png)
obsahují konkrétní zdroj, otisk a zjištěné meze. Opakovatelný
[měřicí skript](../../sources/sawmill-v2/measure-concept-03.py) zapisuje pouze QA
anotace a JSON; neprodukuje herní alfa asset.

Při schváleném raw scale0.1195 a nav `(400,1030)` má půdorys raw meze
`x−102.092..1236.820 / y360.544..1030`. Viditelný spodní obraz v řádcích `y>=740`
končí podle ne-růžových pixelů v `x1229,y1029` včetně. Celý poslední pixel tedy
končí přesně na jižní hranici1030: rezerva je0, nikoli dřívější odhad z02.
Východní rezerva je0.815 světového pixelu. To se vejde do současného půdorysu,
ale musí projít kontrolou filtrace a zvýšeného základu ve skutečné scéně.

Ručně měřené světlé dveře mají přibližně285–286 raw pixelů na výšku, tedy
34.06–34.18 světového pixelu (nejistota asi0.60world). Výška již převyšuje33world
člověka, nicméně šířka71raw=8.48world zůstává úzká; hlavní větev práce zadala
ještě cílené rozšíření otvoru. Koncept03 se tímto nepovažuje za finální přijatý
sprite. Po této úpravě se geometrie následujícího výstupu měří znovu.

## Koncept04 a první nativní základ

Samostatné [měření04](concept-04-geometry.json),
[kontaktní náhled](concept-04-contact-guide.png) a [dveřní pravítko](concept-04-door-ruler.png)
potvrzují širší otvor přibližně122raw=14.58world a výšku294–296raw=35.13–35.37world.
Source SHA-256 je `3ff20d909aaa9dd05788c4545a657d2984bb03a8a4ffd7118cb80da506d12115`.
Finální raw nav je `(400,1032)`, scale0.1195. Jižní ne-růžový extent je inkluzivní
řádek1030, tedy spodní hrana pixelu1031. Zdrojová rezerva1raw=0.1195world je malá,
ale kladná. Východní mez zůstává1229 včetně, rezerva0.815world.

Hlavní větev práce vyexportovala skutečnou alfu a zapsala [base-export.json](base-export.json).
Tato samostatná QA větev pak dokončila a prohlédla [první nativní kontrolu základu](base-native/README.md):
7 finálních záběrů, skutečné Main a načtené pixely v2, současná chata, tesař33world,
rovina i přesný zvýšený4×2. Finální proces skončil0 bez chyb. Viditelné pevné
kontakty se vešly; minimální téměř průhledný filtrační lem a dosud neověřené
dynamické stavy jsou výslovně rozepsané v nativním protokolu. Guide registrace
se do skutečného exportu nekopírovala.
