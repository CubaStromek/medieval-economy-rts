# Dřevorubecká chata: stavební pilot a terén

Datum **2026-09-10**. Vlastní grafika podle
[briefu stavební sady](../../briefs/lumber-hut-construction-v1.md), manuál v0.2.
Jde o implementovaný herní pilot; uživatelský souhlas s etalonem sady
ani s konečnou kalibrací vzhledu nebyl udělen.

## Co skutečně běží ve hře

Aktuální dřevorubecká chata používá dvě vlastní RGBA kresby a dvě původní
masky: **12 kroků konstrukce a 21 kroků dokončení**. Základ a všech 33 kroků
čtou existující stavební práci. Dům nadále stojí 3 prkna a 2 kameny,
vyžaduje 120 pracovních ticků a používá stejných šest polí, dveře a save v20.
Zásoby klád a fyzická přítomnost nejsou nově zapečené do statické kresby.

Poloha obrázku je oddělena od stabilního bodu hloubkového řazení. Oprava
odstraňuje přemalování spodku domu dalším řádkem trávy. Dveře, skutečná
výška terénu, pozemní stíny ani kolize se tím nezvedají či neposouvají.
Podklad pro tento postup je v
[rozboru KaM Remake](../../kam-object-terrain-rendering-study.md).

## Reprodukovatelné ověření

- `asset-validation.json`: 33 rozdílných rastrových stavů, poslední přesně
  odpovídá hotovému masteru, původní obrazové vstupy zůstaly stejné.
- `game/tests/lumber_hut_construction_tests.gd`: skutečný stavitel projde
  všechny kroky po fyzické dodávce materiálů; ukládání každého stavu,
  obnovení práce, pauza, srovnávání terénu, staré půdorysy, alfa výběr,
  mlha a denní světlo. Samostatné kontroly ověřují stabilní řazení a
  kliknutí na viditelný spodek i na zvýšeném základu.
- Zaměřená sada prošla **12/12 bez grafického okna a 12/12 nativně**.
  Nativní test porovnal skutečný spodní pixel domu s nezakrytým obrazovým
  vzorkem; kontrola tedy přímo odhaluje původní ořez terénním řádkem.
- Kompletní herní sada po konečné opravě prošla **705/705**. Stávající
  kontrola střechy nově kliká na skutečný neprůhledný pixel bitmapy;
  všechny kontroly klikání na obsazená půdorysná políčka zůstaly zachované.
- `game/tools/preview_lumber_hut_construction.tscn`: skutečná hlavní herní
  scéna na Apple M4, Godot 4.7.2. Dočasný testovací svět, pozastavená
  simulace, přesně nastavené stavy práce; žádné přehrávané video místo hry.
  Herní hudba ani hráčova uložená hra nejsou načtené nebo přepsané.
- `capture-manifest.json`: přesné stavy a metadata všech 72 nativních
  snímků; tři přiblížení, den/soumrak/noc, svah, srovnávání, výběr,
  stromy/jednotky, cizí mlha a skutečný herní panel.

[Animace všech kroků](construction-in-game.gif) ·
[Běžné přiblížení 1×](construction-zoom-1-00.png) ·
[Detail 2.4×](construction-zoom-2-40.png) ·
[Terén, výběr, světlo a mlha](contexts.png) ·
[Hotový dům ve hře](game-complete.png)

Animace sestává ze skutečně zachycených 34 stavů (základ + 33 změn) s
prodlouženou výdrží hotového domu. Je to zrychlená ukázka výstavby,
nikoli tvrzení o skutečné délce stavebního procesu.

## Výsledek vizuální kontroly a meze pilota

Spodní patky, konstrukce i celý stojan se po opravě zobrazují. Během
výstavby nedochází k poskakování celé chaty. U vstupu se člověk kreslí
před domem a pravá přístupová cesta je volná. Průhledné pozadí nevytváří
barevný obdélník; materiály dostávají běžné denní/noční tónování. Neznámé
území dům skryje, v prozkoumané cizí mlze není zobrazena skrytá jednotka.

Původní koncept má přední patky a stojan přibližně **38 world px jižně
od prahu** a západní přesah přibližně **20 world px** mimo půdorys.
Na prudším okolním svahu je vidět přesah patek nad svažitou zemí.
To je omezení geometrie současné kresby; oprava řazení je neschovává
ořezem a neprohlašuje ho za vyřešené. Před schválením této chaty jako
etalonu či rozšířením katalogu je nutná samostatná výtvarná kalibrace
kontaktů se zemí a průchodu okolními volnými políčky. Dveřní otvor má
přibližně 23 world px proti běžné 33px postavě; jde zatím o stylizované
měřítko pilota, nikoli schválené proporce celé sady.

První nativní pokus selhal vizuálně na ořezu trávy; další ukázal obrys
výběru přes střechu. Tyto nálezy vedly k opravám řazení a pořadí kreslení
výběru. Samotný úspěšný export nebo spuštění scény nejsou přejímkou.
