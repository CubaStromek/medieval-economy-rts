# Zadání budovy: <název>

Datum: <YYYY-MM-DD> · ID: <building_id> · verze assetu: <v1>
Manuál: [building-style-guide.md](building-style-guide.md), verze <0.2 / pozdější schválená>.
Stav: **návrh**. Schválený vlastní obrazový etalon: <cesta/verze, nebo zatím není>.

Při kopírování do `docs/art/briefs/` oprav relativní odkazy.
Nevyplněný údaj znamená neověřeno; nenahrazovat odhad tvrzením o skutečnosti.

Při produkci postupovat podle [společného implementačního postupu](object-implementation-workflow.md).
Technické napojení vede [implementační záznam objektu](object-integration-template.md),
skutečnou přejímku [QA záznam](object-qa-template.md). Tento brief zůstává
autoritou výtvarného a stavového zadání; shodné údaje v dalších záznamech odkazovat.

## Úloha a identita

- Co budova dělá v naší hře:
- Co divák pozná bez popisku:
- Rodina: les/venkov, výroba, občanská, vojenská; zdůvodnění:
- Hlavní pracovní motiv (jeden):
- Podpůrné motivy (nejvýše dva):
- Příbuzná budova, od níž se musí lišit:
- Vlastní architektonický nápad:
- Co z předlohy bereme jen jako obecný princip:
- Co konkrétně z předlohy neopakujeme:
- Jaké rekvizity jsou statická dekorace a které odrážejí skutečný herní stav:

## Geometrie — přečíst aktuální katalog a helper

- Katalogové ID a zdroj:
- Půdorys [šířka, výška]:
- Maska sever→jih:
- Počet obsazených polí:
- Kotva uložené budovy:
- Dveřní pole vůči kotvě:
- Venkovní vstup vůči kotvě:
- Pohled: vyvýšený zpředu mírně zleva; čitelné horní plochy a menší levý bok:
- Srovnání elevace s prohlédnutou KaM referencí a vlastními koncepty; ne číselný odhad:
- Projekční podklad: cesta k hernímu výřezu/podkladu:
- Jak výtvarné natočení zachovává osovou zemní mřížku, masku a pravý práh:
- Plocha podkladu při 1× (nikoli rozměr celé bitmapy):
- Reference člověka a jeho změřená výška:
- Zamýšlená výška dveří/stavby při 1×; stav ověření:
- Přesahy střechy a rekvizit; volná pole a průchod:
- Podklad s určeným půdorysem a vstupem skutečně předaný generátoru:
- První koncept nad tímto podkladem; změřené kontakty stěn/patek/stojanů
  uvnitř masky, střešní přesahy zvlášť; výsledek a datum před výrobou variant:
- Způsob výběru siluety po integraci:
- Podpora starších footprint verzí / fallback:

## Výtvarný návrh

- Silueta a skladba hmot:
- Konstrukce / kámen / dřevo / výplně:
- Střecha:
- Materiálová paleta a jeden střídmý akcent:
- Drobné stopy používání:
- Detaily, které záměrně vynecháme:
- Odchylky od společného manuálu, důvod a schválení:

## Stavový plán — povinný už před kresbou

Nespoléhat na pozdější přemalování hotového domu. U každé položky odlišit
**navržené / dodané / změřené / propojené s daty / herně ověřené**.
Budova bez inventáře má skladovou část N/A s odůvodněním, ne vymyšlenou zásobu.

- Co je trvalé vybavení a co proměnlivé zboží:
- Resource ID a přesný inventář/zdroj dat:
- Zdroj kapacity a nynější hodnota; chování při změně kapacity:
- Nula a všechny vizuální stupně; přesné kusy nebo výslovně přiznané skupiny:
- Fyzické předání / odebrání; které rezervace a nesené zboží se nezapočítávají:
- Rozměr a umístění prázdného skladovacího prostoru mimo dveřní přístup:
- Přítomnost: ano/ne nebo počet; fyzické `inside_building_id`, ne `home_id`:
- Oddělení přítomnosti od přidělení, povoleného provozu, práce a spánku:
- Vizuální řešení přítomnosti; prázdná/neutrální varianta:
- Práva na stav vlastního/cizího domu; viditelný/prozkoumaný/neznámý terén:
- Neutrální neznámý/skrytý stav, který není falešná nula nebo nepřítomnost:
- Srovnávání/stavba; kdy se dokončené produkční vrstvy vůbec smí zobrazit:
- Denní tónování, případné emisivní prvky a globální pauza:
- Stav případné obrazové ukázky: mockup není datově napojená ani oddělená vrstva:

| Vrstva | Co obsahuje | Pořadí/zakrytí | Navržena / skutečně dodána |
|---|---|---|---|
| Prázdný základ a zadní architektura | Dům, prázdný skladovací prostor, trvalé vybavení | <...> | <...> |
| Zásoby | Jen skutečně skladované kusy, bez pozadí | <...> | <...> |
| Přední architektura | Sloupky/lišty, které zakryjí zásoby | <... nebo N/A> | <...> |
| Přítomnost | Samostatný indikátor ano/ne nebo počtu | <...> | <...> |
| Další stavové vrstvy | Jen výslovně požadované stavy | <... nebo N/A> | <...> |
| Přesný údaj v UI | Text kreslený hrou, ne napevno v PNG | <... nebo N/A> | <...> |

| Kotva | Zdrojové px ve společném canvasu | Navržena / skutečně změřena |
|---|---|---|
| `door_threshold` | <x, y> | <...> |
| `sort_foot` — samostatný bod řazení | <x, y; skutečně použité složky a převod> | <...> |
| `label_anchor` — název/ukazatel | <x, y nebo N/A> | <...> |
| `stock_origin` | <x, y nebo N/A> | <...> |
| `stock_slot_<id>` pro každý kus/skupinu | <seznam pozic; u klád např. log_slot_1…6> | <...> |
| `occupancy_indicator` | <x, y> | <...> |
| `stock_count_label` | <x, y nebo N/A> | <...> |

- Společný canvas, pivot, měřítko a případné trim offsety všech vrstev:
- Alfa okraje a překryvné masky; jak se zabrání zdvojení sloupků či stínů:
- Zachování hloubkového řazení, klikání a mlhy; žádná vrstva nad vším:

## Stavební sada — pokud je součástí dodávky

- Ověřený počet kroků tohoto konkrétního domu a zdroj měření:
- Počet barevných masterů / masek / výsledných změn; počáteční stav zvlášť:
- Skutečný zdroj práce, trvání, podíly fází a hranice zaokrouhlení:
- Srovnávání terénu versus stavba versus skutečně povolený provoz:
- Pořadí konstrukčních částí a odstranění dočasných podpěr/otevření průhledných míst:
- Stejný práh, měřítko, canvas/trim a stabilní bod řazení pro všechny fáze:
- Neprázdné a odlišné požadované kroky; přesná shoda posledního obrazu s masterem:
- Odkaz na implementační a QA záznam; neimplementované fáze označit:

Čísla **12 + 21**, poměr práce 60/40 a kotvy chatrče nekopírovat jako
univerzální výchozí hodnoty. U statického zadání bez stavební sady zapsat
N/A a ponechat existující herní chování; samotný brief nic neimplementuje.

## Společný základ obrazového zadání

Níže je pracovní základ, ne samostatný měřitelný generátor stylu. Před odesláním
vyplnit všechny závorky a připojit pouze uvedené, dostupné a prohlédnuté reference.
Budova i výsledek musejí projít manuálem; nepřepisovat společný základ nahodile
pro každou profesi. Budoucí podstatnou změnu základu verzovat.

```text
Create one original building artwork for Medieval Economy RTS.
Deliverable stage: [CONCEPT / PRODUCTION SPRITE / NAMED SEPARATE LAYER].
Style version: [VERSION].
Visual world: a hand-painted medieval craft settlement on a wooded frontier;
warm irregular local stone, practical timber framing, matte roof materials,
restrained earth colors, modest signs of use, believable human craftsmanship.
Inspired by the clarity and intimate atmosphere of classic medieval strategy
games; invent this building's architecture and arrangement, not a trace,
recolor or upscale of an existing game's building.

Match the supplied OWN approved building reference and game-ground guide
exactly in viewing direction, human scale, edge softness and detail density.
If no approved own building exists, this is an unapproved calibration pilot.
ARTWORK CAMERA: an elevated front-LEFT oblique view with a mild isometric
impression, in the spirit of KaM Remake. Look down enough to read the roof
planes and the working/storage area; avoid a low eye-level view. The front
remains dominant and a modest LEFT side is visible. It is NOT a perfectly
frontal elevation. Match the inspected visual references rather than inventing
numeric original-camera angles. No vanishing-point or dramatic perspective.
ENGINE GROUND CONTRACT: the simulation still uses an axis-aligned 40px square
grid, NOT a rotated 2:1 diamond grid. Do not rotate or alter that grid or the
occupied footprint. Square ground cells do NOT require frontal building art.
Fit the drawn mass above the predetermined footprint, retaining the registered
threshold, human scale and unobstructed south-side approach. Keep all ground
contacts of walls, footings and blocking props inside the occupied cells.
Only the explicitly specified roof overhangs may extend beyond them.
The first concept will be measured against this ground guide before any
construction or other variants are produced; do not enlarge the footprint
to rescue an oversized design.

Building: [NAME AND FUNCTION].
Ground footprint and doorway: [MASK, GROUND GUIDE, THRESHOLD].
Architecture and silhouette: [OWN MASSING].
Main work cue: [ONE CUE]; secondary cues: [UP TO TWO].
Materials and accent: [MATERIALS].
Differences from sibling buildings: [DIFFERENCES].
Allowed visual overhangs: [OVERHANGS].
Empty stock area and dynamic layer plan: [AREA, ANCHORS, LAYERS, OCCLUSION].
Independent physical-presence indicator: [LOCATION, NEUTRAL BASE, STATES].
Delivered layer/state: [EXACT REQUEST; DO NOT CLAIM UNDELIVERED LAYERS].

Readable large forms first, a few crafted details second; retain clarity at
normal game scale. Neutral soft volume shading and restrained local occlusion.
No long cast shadow, dramatic side lighting, sunset grading or night filter.
One complete building, no clipping; real transparent alpha, no landscape,
grass island, ground backdrop, people, UI, caption, watermark or fake checkerboard.
For the static house, show an EMPTY stock area. Do not bake changing inventory,
workers, work smoke, glowing status windows or active-work indicators into it.
All variable stocks and physical-presence states must remain independently
replaceable; preserve foreground posts needed to occlude future stock layers.
A labelled concept demonstration is only a mockup, never proof of separate
layers, working status logic, valid alpha or game integration.
Output target: [MASTER SCALE, CANVAS, REGISTRATION GUIDE]; actual output and
alpha will be measured and validated rather than assumed to match the request.
```

## Dodávka a skutečné údaje

- Nástroj/model/verze a datum:
- Všechny skutečně použité reference (vlastní / externí; URL či cesta):
- Skutečný prompt nebo výrobní postup:
- Zdrojový master:
- Exportovaný soubor / verze / hash při schválení:
- Skutečná šířka × výška v px:
- Skutečně ověřený alfa kanál a jeho rozsah; konceptové pozadí není alfa:
- Skutečný alfa bounding box:
- Práh v souřadnicích zdrojového obrazu:
- Zdrojové px na world px; použité škálování/výřez:
- Povolené přesahy:
- Dodané vrstvy/stavy a jejich společná registrace; odlišit od pouhého plánu:
- Přesné zdroje dat a implementované/neimplementované propojení:
- Chybějící stavy, které se nesmějí označit za hotové:
- Pozemní stín / animace / stavové prvky a kdo je vykresluje:
- Zamýšlený instalační bod; ještě není implementace:

## Přejímka a schválení

Přiložit vyplněný checklist z manuálu, ne pouze odkaz na „testy prošly“.

- Silueta a materiály vedle vlastního etalonu:
- Screenshot 0.75× / 1× / 2.4× / přehled:
- Screenshot s člověkem, vstupní cestou a příbuznou budovou:
- Kamera: čelo, menší levý bok, dostatečně čitelné horní plochy; výsledek srovnání:
- Den / soumrak / noc:
- Vyvýšený srovnaný základ:
- Výběr / průhledné okraje / překrytí / mlha:
- Srovnávání terénu / výstavba / dokončení:
- Zásoby: nula, všechny stupně do kapacity, změna kapacity:
- Zásoby × skutečná přítomnost: nezávislé kombinace, ne jeden společný přepínač:
- Skutečné předání / vyzvednutí; nesené zboží a rezervace nemění sklad předčasně:
- Přidělený venku / uvnitř / nepřidělený / spící / provozně pozastavený:
- Vlastní/cizí stav a mlha; žádný únik živého cizího inventáře či skrytých osob:
- Globální pauza, změna rychlosti, uložení/načtení, registrace vrstev:
- Relevantní testy a výsledek; u konceptu runtime kontroly **neprovedeno**:
- Známé odchylky a omezení:
- Schválil uživatel, datum a konkrétní verze: **zatím ne**
- Je obrazovým etalonem sady: **ne**
