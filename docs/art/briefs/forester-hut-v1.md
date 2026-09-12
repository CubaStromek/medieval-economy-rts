# Pozdější návrh: lesnická chata v1

Datum: **2026-09-09** · ID: `forester_hut` · asset: zamýšlená v1
Manuál: [výtvarný manuál 0.2](../building-style-guide.md).
Stav: **návrh zadání, bez vytvořeného obrázku či nasazení**.
Schválený vlastní obrazový etalon budov: **zatím není**.

**Upřesnění 2026-09-09:** uživatel zvolil jako první skutečný koncept
[dřevorubeckou chatu](lumber-hut-v3.md). Tento lesník zůstává pozdějším návrhem;
není první vyrobený ani schválený pilot. Kamera a příprava stavů již podléhají
opravenému manuálu v0.2, konkrétní obraz lesníka ale dosud neexistuje.

## Úloha

Domov jednoho zahradníka/lesníka (`gardener`), který vysazuje stromy.
U nás jde o samostatnou budovu, odlišnou od `lumber_hut`; nemá předstírat
produkci klád. Zdroj: [lesník a rybář](../../forester-and-fisher-huts.md).

Výtvarná rodina: lesní/venkovská řemeslná stavba.
Hlavní rozpoznávací motiv: nízký **školkařský pracovní přístřešek** s policí
malých sazenic. Podpůrné motivy: svázané ochranné kolíky, jednoduché náčiní.
Nezaměnit za prodejnu květin ani sklad klád.

## Vlastní architektura — návrh

Nízká kamenná podezdívka, nosná dřevěná konstrukce, část prkenné a část světlé
hliněné výplně. Menší uzavřená chata a připojený nízký přístřešek na levé části
jejího obsazeného podkladu. Vchod vpravo na jižní straně zůstává jasně čitelný.

Matné teple šedohnědé šindele, mech pouze lokálně. Zelenou neseme hlavně
sazenicemi a drobným označením školkařské práce, nikoli zeleným přebarvením
celé původní KaM střechy. Jedno opravené prkno a ošlapaný práh stačí.

Z klasické KaM chaty bereme malou venkovskou velikost, čitelnost a přírodní
materiálový dojem. Nepřebíráme její celkovou srubovou siluetu, skladbu zelené
střechy, vlajku ani stejné rozmístění rekvizit. Původní obrázek není vlastní
schválenou referencí nové sady.

Sesterský dřevorubec dostane odlišný pracovní prostor s kládami a řezacím
kozlem; není součástí tohoto assetu lesníka. Společné mají materiály,
konstrukční logiku a měřítko, nikoli totožnou fasádu.

## Pohled a stavová připravenost — doplněno 2026-09-09

Mírně izometrický, dostatečně vyvýšený pohled zpředu zleva: vidět čelo, menší levý bok
a horní plochy střechy/pracovního prostoru. Nesmí působit jako čelní nárys
nebo nízký pohled od země. Přesnou elevaci porovnat s prohlédnutými referencemi,
neuvádět neověřený číselný úhel KaM kamery. Herní mřížka ani maska se neotáčí.

- Tato budova podle nynějšího katalogu nemá výstupní produkty; inventární
  vrstva je **N/A**. Dekorativní sazenice nepředstírají skladovaný počet zboží.
- Připravit samostatné místo indikátoru skutečné přítomnosti u dveří;
  zdrojem bude `inside_building_id == building.id`, nikoli přidělený zahradník.
- Navržené kotvy: `door_threshold`, `occupancy_indicator`; souřadnice a
  společný canvas zatím **nezměřeny**. Skladové kotvy N/A, dokud simulace
  skutečně nezavede skladované produkty a uživatel takový rozsah neurčí.
- Přítomnost odlišit od provozu, spánku a práce. Není napevno namalovaným
  člověkem, kouřem ani svítícím oknem. Zachovat soukromí cizích interiérů v mlze.
- Vrstvy a datové propojení jsou jen plán; nebyly vytvořeny ani implementovány.

## Ověřená geometrie, 2026-09-09

- `game/data/buildings.json`: půdorys **3 × 2**, maska `### / ##E`.
- Šest obsazených polí. Kotva = levé dolní pole ohraničujícího obdélníku.
- Dveřní pole vůči kotvě: `(2, 0)`; vnější vstup: `(2, 1)`.
- Práh: `terrain.project_grid_position(Vector2(door_cell) + Vector2(0, 0.5))`.
- Podklad na rovině při 1×: **120 × 80 world px**; to není velikost sprite.
- Rozlišení masteru navrženo 4×; samotný zemní podklad tedy 480 × 320
  zdrojových px. Výšku obrazu a rezervy nad střechou teprve určí koncept.
- Člověk: použít skutečný `gardener` a vedle něj `carrier`; běžný cíl 33 px.
- Přesné proporce dveří, celková výška a pixelový práh: **čekají na kalibraci**.
- Přízemní rekvizity pouze uvnitř masky; volný vchod i jeho venkovní přístup.
- Všechny nové obrazové stavy musí mít stejnou kotvu; herní masku neměnit.

## Rozsah budoucího pilotu této budovy

Jedna statická dokončená chata s opravdovou alfou, bez okolního trávníku,
obyvatele, dlouhého zemního stínu nebo nočního tónování.
Sazenice jsou malé pracovní rekvizity, ne nové simulační stromy či zásoba.
Žádný namalovaný počet klád nebo napevno aktivní indikátor práce/přítomnosti.
Samostatný stavový prvek a jeho společnou registraci plánovat od návrhu.

Při pozdější integraci nejprve nahradit jen moderní dokončenou
`forester_hut`; ostatní domy a staré footprint verze ponechat s bezpečným
fallbackem. Zachovat stávající srovnávání/lešení. Přizpůsobit výběrový tvar
nové siluetě, vrstvení, dynamické světlo, stíny a mlhu.
Tento dokument tyto kroky **neimplementuje**.

## Povinné srovnání při budoucí implementaci

1. Při 1× vedle V1 terénu, vlastního stromu, člověka a vstupní cesty.
2. Vedle dřevorubecké chaty zkontrolovat odlišení role; nynější placeholder
   neprohlásit za finální etalon dřevorubce.
3. Při 0.75×, 2.4× a mapovém přehledu; doplnit šedou siluetu.
4. Na srovnaném vyvýšeném základu; člověk před/za domem a strom vedle okapu.
5. Den, soumrak, noc, známá/neznámá oblast mlhy a prázdné alfa okraje při klikání.
6. Srovnávání, lešení, dokončení; uložit/načíst zkušební svět bez migrace masky.
7. Přítomnost: zahradník venku/uvnitř, spánek a provozní pauza; vlastní/cizí
   dům v mlze. Zásobové testy N/A pro nynější budovu bez výstupního inventáře.
   Všechny tyto runtime kontroly jsou dosud **neprovedeny**.

Původní známá předloha:
[KaM — přehled budov](https://www.knightsandmerchants.net/information/buildings).
Aktuální vlastní materiálová reference:
[terén V1](../../modern-terrain-textures.md),
`game/art/terrain/modern-materials-v1.png`.

## Záznam výroby

- Obrázek / master / skutečný prompt / nástroj: **dosud nevytvořeno**.
- Rozměry / alfa / pixelový práh / měřítko exportu: **dosud nezměřeno**.
- Herní QA snímky a výsledky: **dosud neprovedeno**.
- Schválení uživatelem: **čeká na skutečný herní pilot**.
- Obrazový etalon sady: **ne**.
