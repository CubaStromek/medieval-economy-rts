# Dřevorubec — nesení klády podle KaM, v1

2026-09-10. Osm směrů **N, NE, E, SE, S, SW, W, NW**, každý osm fází.
Vlastní kresba navazuje na [hotovou chůzi bez klády](../lumberjack-without-log-kam-v2/README.md).
Jde o sadu obrázků a náhled pro kontrolu; ve hře zatím zapojená není.
**Obrázky mají bílé neprůhledné pozadí (RGB), bez namalovaného zemního stínu.**

## Podklady a výtvarné řešení

Pohybovou referencí je skutečný export původních dat KaM
[`uaWalkTool2`](../../../../original_game_data/kam-reference-export/lumberjack-full-set/manifest.json).
Jeho 64 tělesných vrstev včetně pořadí a pivotů odpovídá předchozí chůzi;
mění se překryv nákladu a paží. KaM obrázky jsou externí referencí pro
pohyb, nejsou přebarveným produkčním podkladem našeho atlasu.

Identitu a oděv určuje [brief postavy](../../briefs/lumberjack-v1.md),
podélné uložení jedné klády na pravém rameni vybraný
[vlastní N návrh](../../concepts/lumberjack-v1/log-n-shoulder-v1.png).
Pravá ruka podpírá náklad, levá zůstává volná. Sekera visí na levém boku;
v E a SE je zakrytá tělem. Mírný dotyk klády s okrajem čepice navazuje na
vybraný návrh. Starší vlastní návrhy s příčným uložením přes šíji se nepoužily.

## Soubory

| Cesta | Obsah |
|---|---|
| `frames/<směr>/00.png` až `07.png` | 64 finálně registrovaných snímků, 448 × 544 px |
| `sheets/<směr>.png` | Osm archů 4 × 2, každý 1792 × 1088 px |
| [sprite-atlas.png](sprite-atlas.png) | 3584 × 4352 px, osm směrů v řádcích, osm fází ve sloupcích |
| [directions-overview.png](directions-overview.png) | Přehled první fáze všech směrů |
| `reviews/<směr>-5fps.gif`, `-10fps.gif` | 16 přehrávatelných smyček; kontrolní tempo 5 a 10 snímků/s |
| [manifest.json](manifest.json) | Pořadí, soubory, rozměry, kotvy a otisky |
| [registration.json](registration.json) | Změřená registrace těla každé fáze |
| [pack.py](pack.py) | Opakovatelný export zdrojů do registrované sady |
| `sources/` | Osm směrových výstupů, historie oprav a nový společně kreslený pár SE 7/8 |
| [SE-phases-07-08-proportions-normalized.png](sources/SE-phases-07-08-proportions-normalized.png) | Aktuální zdroj dvojice SE 7/8 po zkrácení původně příliš dlouhých nohou |
| `final-frame-overrides/SE/06.png`, `07.png` | Náhrady sedmé a osmé fáze SE po registraci podle čepice |
| `normalized-sheets/`, `raw/` | Normalizované archy a jejich přesné výřezy před registrací |
| `walk-targets/` | Vlastní chůze vložená do většího plátna bez změny původních pixelů |
| `diagnostics/` | Kontrola rozpoznané čepice, mimo finální atlas |
| `rejected/` | Zachované nevybrané pokusy a doložené důvody oprav |

## Kotva a převod

Společná obrazová kotva je **[216, 400]** v buňce 448 × 544 px. Je to
původní KaM render origin [26, 46] při 8× zvětšení a posunu [8, 32].
Vlastní chůze má původně kotvu [184, 368]; přidaný okraj [32, 32] zachovává
stejný původ i prostor pro kládu. Samotná kláda neurčuje měřítko postavy.

Výstupy generátoru mají různé skutečné rozměry. Celý arch se nejprve
převede na společných 1792 × 1088 px. Pro každý směr se použije jediný
poměr mediánů výšky čepice–boty vůči vlastní registrované chůzi. Potom
se jednotlivé fáze celočíselně posunou podle odpovídající koruny čepice.
Barvová maska je pouze měřicí pomůckou a do kresby se neaplikuje.
Boty se nezamykají k dolní hraně a proměnlivý obrys klády se necentruje.

Toto srovnání zachovává referenční pohyb hlavy. Není důkazem shody
kostry, fyzického kontaktu nohy s terénem ani rychlosti pohybu ve hře.
Tempo GIFů a porovnání je kontrolní; herní časování se zde neměnilo.

## Generování a kontrola

Použit **vestavěný generátor obrázků**, nikoli CLI. Přesný model nástroj
neuvedl. **Třináct volání:** osm výchozích směrů, oprava sekery SE,
oprava opěrné paže E, překonaná samostatná oprava SE 7, nový společný
pár SE 7/8 a oprava proporcí této dvojice.
Zadání jsou v [prompts](prompts/), přesné vstupy a původní výstupy zde:

- [N, NE, NW](generation-notes-N-NE-NW.json)
- [E, W](generation-notes-E-W.json)
- [SE, S, SW](generation-notes-SE-S-SW.json)

Podrobné skutečně provedené kontroly a neověřené oblasti rozlišuje
[QA záznam](../../qa/lumberjack-with-log-kam-v1/README.md).
[Implementační záznam](../../briefs/lumberjack-with-log-kam-v1-integration.md)
odděluje nynější obrázkovou dodávku od budoucího zapojení do hry.
Žádný nový výtvarný etalon nebo produkční přijetí uživatelem se zde netvrdí.

### Kontinuita pravé nohy SE — 2026-09-10

Uživatel upozornil na výměnu identity nohou při přechodu **6→7**.
Starší izolovaná oprava sedmé fáze je překonaná: její zadání zaměnilo
bližší levou a vzdálenější pravou nohu; zviditelněná bota neprokázala
souvislý krok. V tomto SE pohledu je **bližší pravá kyčel pod zvednutou
pravou paží na levé straně obrazu**.

Nová dvojice sleduje tutéž pravou nohu zezadu ve fázi 6 přes pokrčený
průchod před levou nohou ve fázi 7, rozvinutí dopředu ve fázi 8 a přední
kontakt ve fázi 1. Levá noha ve fázi 7 ještě podpírá tělo a ve fázi 8
zůstává vzadu. První nový pár měl příliš dlouhé nohy; aktuálním zdrojem
je jeho [oprava proporcí](sources/SE-phases-07-08-proportions-normalized.png).
Přesná zadání: [kontinuita](prompts/SE-phases-07-08-leg-continuity.txt)
a [proporce](prompts/SE-phases-07-08-proportions.txt).

Mění se pouze náhrady `final-frame-overrides/SE/06.png` a `07.png`;
ostatních 62 fází je bytově beze změny. Packer náhrady aplikuje po základní
registraci, před sestavením archů, GIFů a atlasu. Záznam základní registrace
není měřením nových pixelů. Náhled začíná **pozastavený na SE, fázi 6**,
s tempem **2 fps** a dalšími volbami 5/10 fps.

Technické balení této revize prošlo; oba snímky jsou v archu, atlasu a GIFech.
Logika náhledu byla ověřena v Node VM s výslovnými náhradami DOM/Image/timer;
skutečný prohlížeč tím ověřen není. Aktuální výsledky a velikosti jsou v [pack-validation.json](pack-validation.json)
a [preview-validation.json](preview-validation.json). Nová kresba nemá
uživatelské přijetí ani ověření ve hře.
