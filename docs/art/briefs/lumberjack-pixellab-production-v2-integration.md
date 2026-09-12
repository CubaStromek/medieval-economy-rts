# Implementace objektu: dřevorubec — PixelLab produkční v2

Datum: **2026-09-10** · ID `lumberjack` · typ jednotka.
Stav: **finální balík všech 24 kombinací má 439 animačních PNG a 24
archivovaných vstupních referencí. Kompletní samostatná nativní ukázka
prošla. Následné zapojení do běžné hry a jeho ověření vlastní
[herní integrační záznam](lumberjack-pixellab-game-v1-integration.md).**
Založeno podle [implementační šablony](../object-integration-template.md)
a [společného postupu](../object-implementation-workflow.md).
[QA](../qa/lumberjack-pixellab-production-v2/README.md),
[produkční záznam](../animations/lumberjack-pixellab-production-v2/README.md),
[přesné runtime větve](lumberjack-pixellab-production-v2-runtime-notes.md).

## 1. Zadání a autoritativní data

Uživatel po zaplacení PixelLab Tier 2 zadal chůzi se sekerou, obouruční
kácení a chůzi s kládou, každé v osmi směrech. Předchozí zastavení
uploadu odvozeného pohledu vyřešil dne **2026-09-10** výslovnou odpovědí:
> Potvrzuji a zadam o zrušení té původní kontroly

Autorizované je opětovné odesílání vlastních výstupů PixelLabu téže
službě; původní početní omezení uploadů je zrušené. Jeden vlastní master
je pravidlo výtvarné konzistence, nikoli zákaz odvozených referencí/oprav.
Autorita identity, materiálů, kamery a původu:
[dřevorubec v1](lumberjack-v1.md). Kláda je podélně na pravém rameni,
pravá ruka ji podpírá, sekera je na levém boku. Původní vlastní S je
uvedené v produkčním záznamu; KaM není přebarvovaný produkční master.

Simulační typ, katalog, ceny, mřížka a save formát se kvůli výměně
kresby nemění. Klipy nejsou nové simulační akce. Výtvarné přijetí v2
uživatelem: **neuděleno**.

## 2. Geometrie a registrace

| Údaj | Skutečný stav / autorita |
|---|---|
| Canvas | Skutečné PNG 256 × 256 RGBA; měření u jednotlivých jobů |
| Výška člověka | Pracovní tělesná kalibrace 163 source px → 33 world px; cílový světový rozměr určuje kanonický brief |
| Společná obrazová kotva | Explicitních (128,205) source px, ověřeno technicky v S pilotu; fyzická kalibrace terénu/stromu je předběžná |
| Statická registrace | Celé RGBA reference posunuté celočíselně podle čepice na y52 / rasterový střed x128; cap ROI je oddělená od klády nad hlavou |
| Animované fáze / trim | Žádný individuální posun podle bot, bob navíc, ořez, zrcadlení nebo škálování dle výbavy |
| Alfa a přesahy | Změřeno u prohlédnutých zdrojů; skutečná průhlednost, žádné viditelné pixelové ořezy při statické registraci. Finální atlasové ověření prošlo bezeztrátově. |
| Mapová kotva / kolize / projekce | Zachovat skutečnou polohu pracovníka; kontrola v běžné hře neprovedena |
| Řazení, stín a UI | Dosud neověřeno v běžné hře; obrazový obal klády nesmí měnit fyzickou výšku/kolizi |
| Kontakt sekerou se stromem | Dosud neověřeno. Pracovník a strom mohou být ve stejné buňce; nulový směrový vektor není kalibrace kontaktu. |

[Registrační provenance](../animations/lumberjack-pixellab-production-v2/registered-inputs/README.md)
uchovává zdroje, SHA256, ROI a přesné posuny. Cap registrace je obrazové
srovnání, nikoli fyzická ground kotva, hloubkové řazení nebo stín.
Vzorec kreslení je projekce fyzické kotvy − společná obrazová kotva ×
world px / source px. Bbox nástroje tento vztah nepřepisuje.

## 3. Klipy, vrstvy a pravdivé stavy

Stavební fáze: N/A — pohyblivá jednotka.

| ID | Zdrojové QA k tomuto záznamu | Budoucí skutečný zdroj chování |
|---|---|---|
| `walk_axe` | Osm směrů prohlédnuto, oba střídající kroky, pravá ruka s jednou sekerou, levá volná. Částečné zakrytí vzdálené pravé ruky v W. | Viditelný pohyb pracovníka bez fyzicky nesené klády |
| `walk_log` | Osm směrů prohlédnuto. N 1–11 / 13,75 fps; ostatní 1–16 / 20 fps, dvojkrok 0,8 s. Přesný kontakt ramene v W a dalších zakrytých pohledech neprokázán. | Skutečné `carrying == "log"`, nikoli rezervace či zásoba chaty |
| `chop` | S waist-empty 1–16 / 12 fps; N forward 1–12 / 9 fps; NE/NW/SE/SW 1–16 / 12 fps. E/W slow-24 1–24 / 18 fps; celkem 140 animačních fází. | Skutečná povolená práce dřevorubce na stromu, nikoli přidělení k budově |

Všechny tři činnosti mají skutečné výstupy pro N, NE, E, SE, S, SW, W,
NW, ale první vadné pokusy nejsou finální dodávka. Výběry a časování jsou v
[uzavřeném záznamu](../animations/lumberjack-pixellab-production-v2/delivery-selection.json)
a individuálním QA. Finální počty: walk_axe 176, chop 140, walk_log 123,
celkem 439 fází. Zvlášť je přiloženo 24 raw00 vstupních referencí.
Všechny původní raw fáze včetně nevybraných konců zůstávají uchované.

Stojící pracovník musí udržet správné vybavení, zejména kládu. Chůze
musí sledovat dobíhající zobrazený pohyb i při změně simulačního stavu.
Pauza zastaví čas; kreslení nic nesimuluje. Skutečný náklad musí být
odlišen od rezervací a zásob budovy.

## 4. Soubory a bezeztrátový převod

Každý skutečný job uchovává vstup, zadání, ID, odpověď, původ a účtování.
Odmítnuté reference/pokusy zůstávají u svých historických QA. [Audit](../animations/lumberjack-pixellab-production-v2/qa/cost-audit.md)
k **2026-09-10 17:43:52 UTC** potvrzuje 55 unikátních dokončených úloh,
560 zahrnutých generací a 0 USD za generování, bez běžících rezerv.
Zahrnuje odmítnuté pokusy i finální opravy; předplatné se zde nepočítá.
Globální souběžné zůstatky se nesčítají jako ceny.

[Packer](../../../tools/pack_pixellab_lumberjack.py) již bezeztrátově
zabalil skutečný S pilot. Přesné PNG kopie, celé RGBA atlasové buňky a
dekódovaný APNG byly ověřené. Následně stejnou
[kontrolou finálního balení](../animations/lumberjack-pixellab-production-v2/pack-validation.json)
prošlo všech 439 vybraných fází, bez varování a bez symlinků v dodávce.
Schema 1 má canvas, společnou kotvu, tělesnou škálu, skutečné indexy,
`rest_frame`, hashe a regiony. Efektivní FPS jsou `direction.fps`, pokud
existují, jinak klipová `fps`; časování nevynucuje změnu pořadí/pixelů.
`renders_cargo: "log"` platí pouze pro skutečně kreslenou kládu.

[Godot reader a samostatná scéna](lumberjack-pixellab-v2-godot-reader.md)
jsou implementované. [S pilot](../qa/lumberjack-pixellab-v2-S-pilot/README.md)
prošel skutečným importem a nativním vykreslením; historický
pilot zůstává odděleně archivovaný. Kompletní runtime kopie již prošla
[plným nativním QA](../qa/lumberjack-pixellab-production-v2/native/README.md):
439/439 fází, 24/24 kombinací, nový import a `require-complete`, bez
chyb či varování readeru, 15 prohlédnutých nativních snímků při 1×/3×. [Směrový FPS probe](../qa/lumberjack-pixellab-direction-fps-probe/README.md)
a [test packeru](../qa/lumberjack-pixellab-direction-fps-probe/packer-timing-review.md)
prošly v odděleném testovacím rozsahu. Tyto technické běhy ani finální
nativní ukázka neprokazují menu → mapa nebo skutečně vykonanou práci.

## 5. Zapojení a kompatibilita

**Hlavní herní cesta není zapojená ani ověřená.** Samostatný prohlížeč
není menu → mapa → skutečný pracovník. Finální importér/přehrávač byl
ověřen s kompletní sadou v samostatné scéně; zbývá běžná cesta chůze → kácení → převzetí
klády → návrat → odevzdání. Zachovat mlhu, interiér, světlo, stín, řazení,
výběr, interpolaci, pauzu a podporované uložené hry. Potlačit obecný symbol
nákladu pouze při jeho skutečné kresbě. Nepřičítat ke zdrojové animaci
staré dodatečné pohupování. Hlavní scéna a simulace tímto záznamem změněné
nejsou; technický reader sám tyto větve neprokazuje.

## 6. Předání

Všechny tři činnosti mají uzavřený výběr a kompletní bezeztrátový balík.
[Předávací ZIP](../animations/lumberjack-pixellab-production-v2/lumberjack-pixellab-v2.zip)
a [návod k importu](../animations/lumberjack-pixellab-production-v2/DELIVERY.md)
jsou dostupné; CRC a shoda bajtů archivu prošly kontrolou.
[HTML](../animations/lumberjack-pixellab-production-v2/preview/index.html) a
[přehled 3 × 8](../animations/lumberjack-pixellab-production-v2/preview/overview.apng.png)
jsou vytvořené. Kompletní nativní QA také prošlo. Zbývá fyzická kalibrace
a běžná herní cesta; při 1× je tělo/kláda čitelná, detail úchopu je omezený. [QA v2](../qa/lumberjack-pixellab-production-v2/README.md)
vede tyto kroky odděleně od uživatelského přijetí. V2 není schváleným
výtvarným etalonem; přijetí nelze odvodit z existence atlasu nebo staré v1.
