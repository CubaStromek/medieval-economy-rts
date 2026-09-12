# Implementace objektu: půdorys dřevorubecké chaty v2

Datum **2026-09-10** · ID `lumber_hut` · typ: budova, změna herní geometrie.
Stav: **zapojeno a ověřeno; 755/755 celkových a 41/41 nativních kontrol**. Záznam podle
[implementační šablony](../object-integration-template.md) a
[společného postupu](../object-implementation-workflow.md).
Výsledky kontrol vede [QA v2](../qa/lumber-hut-footprint-v2/README.md).

## 1. Rozsah a autority

Uživatel výslovně schválil zvětšení půdorysu současné chaty, aby odpovídal
existujícím patkám a stojanu. Zachovává se velikost a kresba domu, všechny
stavební kroky i zásoby. Jde o povolenou změnu obsazené země a její verze,
nikoli jen žlutého obrysu. U dalších generovaných objektů se musí již první
koncept vejít do předem určeného půdorysu; tato výjimka se na ně nepřenáší.

Autorita aktuální a historické masky je
[`buildings.json`](../../../game/data/buildings.json), jejího výkladu
[`building_footprints.gd`](../../../game/scripts/simulation/building_footprints.gd).
Obecný kontrakt popisují [půdorysy](../../building-footprints.md).
Původ kresby, společnou registraci a 12 + 21 kroků nadále vede
[stavební brief v1](lumber-hut-construction-v1.md); jeho původní 3 × 2 geometrie
je historická v1. Zásoby a jejich data vede
[zásobní integrace v1](lumber-hut-stock-v1-integration.md) a
[zásobní brief](lumber-hut-v3-stock.md). Výtvarný manuál zůstává **v0.2**;
uživatelské schválení výtvarného etalonu stále není uděleno.

## 2. Geometrie a registrace

| Údaj | Nová hodnota / pravidlo | Zdroj a stav |
|---|---|---|
| Půdorys v2 | 4 × 3; `.### / .##E / ###.`; 9 obsazených polí | Aktuální katalog |
| Mapová kotva | Levé dolní pole obalového obdélníku; řádky od severu k jihu | Společný footprint helper |
| Dveřní pole | Kotva + `(3,-1)` | `E` ve druhé řadě |
| Venkovní vstup | Kotva + `(3,0)`; volný jihovýchodní zářez | Jižní soused dveřního pole, průchod dál na jih |
| Historická v1 | 3 × 2; `### / ##E`; 6 polí | `footprint_revisions["1"]`, neměnná |
| Stejné fyzické dveře při srovnání v1/v2 | `new_anchor = old_anchor + (-1,+1)` | Pouze nové demo/QA světy, nikoli migrace save |
| Registrace obrázku | Původní canvas 640 × 640, práh `(568,410)`, měřítko 0.225 world px/source px | Beze změny; autorita je původní obrazový manifest a stavební brief |
| Vizuální hloubka | Původní `sort_foot` `(568,488.1111111111111)` | Oddělená od dveří a fyzické výšky; nemění registraci |
| Zemní stín, výběr a srovnávání | Používají skutečně obsazenou masku konkrétní instance | Ověřeno v QA v2 |

Šest původních polí zůstává na stejných místech vůči dveřím; tři nová
jihozápadní pole pokrývají přední patky a stojan. Severozápadní dvě prázdná
pole a jihovýchodní vstup zůstávají volné. Rozměr 4 × 3 je obal masky,
nikoli nový rozměr bitmapy. Střecha a komín nejsou zemní kolize a jejich
obrazový obal neurčuje počet obsazených polí.

Pro porovnání se skutečnými polygony země používá nativní kontrola tyto
kontaktní body již existující kresby, ve zdrojových pixelech:

| Kontakt | Souřadnice |
|---|---|
| Západní kamenná patka přístřešku | `(44,454)` |
| Přední patka přístřešku | `(128,548)` |
| Patka stojanu | `(190,576)` |
| Přední kamenný základ uzavřené chaty | `(421,468)` |
| Zadní patka dřevěné části | `(334,405)` |

Převod je `house.rect.position + source_point × source_to_world`; kontroluje
se skutečný polygon obsazené země na rovině i vyvýšeném srovnaném podkladu.
Výsledky v QA: 10/10 kontaktů uvnitř obsazené země. Pět kontrolních bodů
není důkaz každého pixelu ani každého možného
svahu. Kontrola prvního konceptu před výrobou variant je zde N/A: tato oprava
neprodukuje nové obrázky a řeší již existující sadu.

## 3. Fáze, vrstvy a skutečná data

Stávající srovnávání připravuje všech devět obsazených polí. Nová maska tedy
mění reálnou plochu přípravy a kolizí. Práh zůstává odvozen od dveřního pole,
také když dveře neleží v nejspodnější řadě obalu.

Po přípravě se nadále používá původních **12 konstrukčních + 21 dokončovacích
kroků**, původní simulační práce a stejné dva mastery i masky. Cena zůstává
**3 prkna + 2 kameny**, stavební práce **120 ticků**; změna půdorysu nepřepisuje
tyto hodnoty ani zásoby. Přesný výklad stavebních stavů a vrstev je ve výše
odkazovaných autoritativních briefech. Klády 0–6 stále čtou `outputs.log` po
skutečném předání/vyzvednutí; fyzická přítomnost pracovníka není nový stav.

## 4. Produkční soubory

**Žádné generování ani úprava PNG, stavebních masek nebo obrazových manifestů.**
Původ, rozměry a SHA-256 obrazových souborů zůstávají v původních manifestech
a záznamech stavební/zásobní sady. Není nový prompt, nástroj pro výrobu obrazu
ani export. Změna runtime podpory dovoluje tutéž obrazovou sadu pro půdorys
v1 i v2; původní manifest nadále popisuje obrazovou dodávku v1, nikoli aktuální
simulační masku každé instance. Skutečná geometrie se čte z katalogu a verze
uložené budovy.

Při QA se ověřuje shoda původních assetů a společný obdélník všech stavebních
i zásobních stavů. Výsledek této nové kontroly patří do QA v2; úspěšné starší
testy se nepřepisují jako nový výsledek.

## 5. Napojení a kompatibilita

- Běžná cesta: hlavní menu → nová/načtená mapa → umístění chaty, příprava,
  výstavba a provoz; reálné průchody dveřmi a odvoz zásob.
- `SimulationWorld` vybírá nejnovější podporovanou geometrii podle druhu:
  nové chaty v2, ostatní dnešní budovy v1. Kontrola umístění, blokování,
  srovnávání, zrušení a výběr sdílejí tuto masku.
- `LumberHutSpriteLibrary` podporuje v1/v2 se stejnými texturami, práhem
  a měřítkem. Hlavní renderer a zásobní vrstva zachovávají mlhu, tónování,
  skutečnou alfa siluetu a oddělenou vizuální hloubku.
- Save **v21** podporuje novou geometrii. Staré instance v0/v1 si uchovají
  masku, kotvu, vstup, rozestavěnost a inventáře; žádná automatická expanze
  nezabere sousední cestu či budovu. Původní nesoulad staré v1 kresby a masky
  tím není zpětně odstraněn. V0 dál používá historický způsob vykreslení.
- Save v16–20 připouští jen geometrie v0/v1, dřívější save migrují na v0.
  Neplatná nebo nepodporovaná verze má selhat při ověření připravovaného světa
  před nahrazením běžící hry; historické masky se nemění.
- Nové ukázkové mapy mají přizpůsobenou kotvu chaty a volné návazné cesty.
  Uživatelské uložené pozice se nepřepisují. Samostatný distribuční balík
  není součástí tohoto zásahu.

## 6. Předání a stav ověření

[QA v2](../qa/lumber-hut-footprint-v2/README.md) obsahuje přesné výsledky testů,
nové herní snímky, rovinaté i vyvýšené kontakty, průchod zářezem, kolize,
kompatibilitu v0/v1/v2, stavební a zásobní stavy a běžnou herní cestu.
Nativní scénář je
[`preview_lumber_hut_footprint.gd`](../../../game/tools/preview_lumber_hut_footprint.gd).
Ověřeno 12/12 nových geometrických případů, 755/755 celkové sady,
41/41 nativních regresí, 61 vizuálních snímků a běžná herní cesta se
7 fázemi / 17 snímky / nulou selhání. Historická QA zůstávají zachovaná.

Technické dokončení a skutečná vizuální kontrola této změny jsou uvedeny
samostatně v QA. Uživatel autorizoval řešení geometrií; tím neschválil novou
vizuální referenci celé sady. Další objekty se musí od prvního konceptu vejít
do svého stanoveného půdorysu podle postupu v1.1.
