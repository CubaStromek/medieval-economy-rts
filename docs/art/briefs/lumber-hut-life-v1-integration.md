# Implementace objektu: život dřevorubecké chaty v1

Datum **2026-09-12**, `lumber_hut`, provozní grafika existující budovy.
Stav původní vrstvy: **zapojeno a ověřeno**, 11 zaměřených skupin,
10 nativních pixelových kontrol a běžný průchod menu → denní práce → noc.
Následné upřesnění stejného dne rozšiřuje denní odpočinek o otevřené
neosvětlené okno a otáčení hlavy; jeho samostatné důkazy vede
[QA look v1](../qa/lumber-hut-life-look-v1/README.md).
Upřesnění je **zapojené a ověřené**: 13 zaměřených skupin, 12 nativních
pixelových kontrol a opakovaný běžný průchod menu → práce → noc bez
selhání. Celý 240snímkový cyklus hlavy má v měřeném těle a chodidlech
0 odlišných pixelů, při zastavení uprostřed otočení se celý obraz nemění.
Podle [implementační šablony](../object-integration-template.md).
Výtvarný a stavový kontrakt: [brief life v1](lumber-hut-life-v1.md).

## 1. Rozsah a autority

Implementace aktuálně zadaných dveří, odpočinku, nočního světla a kouře.
Denní okno se otevírá až při odpočinku; noční otevření a světlo zůstávají
vázané na fyzickou přítomnost. `window_open` je samostatný údaj, nikoli
odvození z nenulového jasu.
Čtenář `LumberHutLife` čte skutečnou přítomnost vlastního pracovníka,
jeho osobní režim a uložený herní čas. Neprovádí práci, přesun ani
změnu zásob. Stavový plán a starší autoritativní briefy odkazuje brief.

## 2. Geometrie a registrace

Obdélník a `source_to_world` se přebírají z `LumberHutSpriteLibrary`.
Tím dveře, okno i komín následují stejný práh a skutečnou výšku terénu.
Nové zemní/střešní blokující rekvizity nevznikají. Původní `sort_foot`
a příjemce pozemního stínu se nemění. Postava má své změřené chodidlo
a jednotkové měřítko; zapojuje se v souřadnicích stejného domu.
Kontrola prvního nového konceptu budovy je N/A: kresba domu se nemění.
Srovnání postavy s terénem, vstupem a stěnou probíhá v nativním QA.

## 3. Stavy a pořadí

`main_view.gd::_draw_lumber_hut_sprite` kreslí základ, zásoby a potom
`LumberHutLife.draw` ve stejném řádku domu. Samostatná odpočinková
postava se zobrazí jen místo skrytého skutečného obyvatele; jeho běžný
sprite, náklad ani stín se tím nezdvojí. Částice jsou nekolidující
dekorace; noční světlo nepřidává globální kreslicí vrstvu.

Veřejné `building_life_presentation()` umožňuje stejný čtený stav ověřit
v nativní hlavní scéně. Pro cizí budovu při zapnuté mlze se vrací
`known=false` ještě před dotazem na obyvatele. Neznámé údaje nezobrazují
živou postavu, světlo ani kouř; původní statický dům není tvrzení o
aktuální přítomnosti. Viditelnost celého domu dál řídí hlavní renderer.

## 4. Soubory a původ

- `game/scripts/view/lumber_hut_life.gd`: čtení stavu, texturované dveře,
  lokální emisivní okno, simulací časované částice; měkká textura sdílená
  v cache. Všechny čtyřúhelníky používají současnou vlastní kresbu dřeva.
- Nová odpočinková póza: samostatný asset v `game/art/buildings/lumber_hut/v1/life/`.
  Generování vestavěným imagegen podle vlastního dřevorubce, model nástroj
  výslovně neidentifikoval; skutečné prompty, raw pokusy, měření a hashe
  v `docs/art/sources/lumber-hut-life-v1/`.
  [Produkční PNG](../../../game/art/buildings/lumber_hut/v1/life/resting_lumberjack.png),
  [skutečná zadání](../sources/lumber-hut-life-v1/resting-lumberjack-prompts.json),
  [naměřená alfa a export](../sources/lumber-hut-life-v1/resting-lumberjack-asset-qa.md).
- Upřesnění pohledů **2026-09-12**: `life/look/center.png` je původní soubor,
  `left.png` a `right.png` mění pouze hlavu. Jejich `look.json` používá
  původní změřené chodidlo a výšku. Pod límcem (`y >= 82`) se všechny
  RGBA pixely přesně shodují; skutečné změny jsou v `[104,42,136,81)`.
  Původní opření a velikost postavy se nemění. [Zadání a export](../sources/lumber-hut-life-look-v1/README.md)
  uchovávají generované zdroje a skutečné prompty.
- Krátké otočení interpoluje barvu s přednásobenou alfou mezi skutečně
  namalovanými směry pohledu. Osm přechodových kroků každého směru je
  připraveno jednou v paměti. Každý snímek se kreslí jednou, se stejnými
  pixely těla a vlastní maskou pro výběr domu; nevzniká překryv dvou těl.
- Původní `finished.png`, `wood.png`, obě stavební masky a zásoby nejsou
  přemalovány. Jejich otisky se zaznamenávají při nativním QA.

## 5. Napojení a kompatibilita

Běžná cesta menu → Relief → hlavní scéna používá novou vrstvu automaticky.
Podporované půdorysy bitmapové chaty zůstávají v1/v2; historická v0 používá
dosavadní renderer. Save formát ani uložené pozice se kvůli efektům nemění.
Animace používá tick a stejný zlomek ticku jako denní osvětlení; při pauze
čas stojí. Load ihned rekonstruuje život domu z uloženého času a obyvatele.
Dvanáctisekundový cyklus hlavy má stabilní posun podle ID obyvatele;
chatrče proto nemusí otáčet hlavy současně. Při krátkém skutečném pobytu
se zobrazí jen odpovídající část cyklu, bez změny pracovního rozvrhu.
Samostatný distribuční export není součástí této dodávky.

## 6. Předání

[QA záznam](../qa/lumber-hut-life-v1/README.md) vede výsledky nových testů,
regrese a skutečné nativní snímky včetně cesty normálním menu.
Technická integrace, vizuální kontrola a přijetí uživatelem se evidují
odděleně. Tato změna nepovyšuje stávající styl na schválený etalon.

Nové zobrazení používá skutečnou přítomnost okamžitě i ve starších
uložených domech v1/v2. Není třeba přestavovat chatu nebo začínat novou mapu.
U historické varianty v0 zůstává původní grafika.
