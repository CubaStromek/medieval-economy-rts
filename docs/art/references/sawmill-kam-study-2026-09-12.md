# Pila v původní grafice KaM: zásoby a pracovní cyklus

Ověřeno **2026-09-12**. Referenční rozbor pro vlastní zásoby a pracovní
animaci tesaře; nemění runtime ani nevytváří produkční assety.

## Původ a ověření

Bitmapy, paleta, pivoty a pořadí snímků pocházejí přímo z uživatelovy
instalace **GOG Knights and Merchants 1.60 (67017)**: `houses.rx`,
`houses.dat`, `pal0.bbm`. Dekodér přečetl všech 2000 RX slotů až po EOF,
ověřil bezeztrátový round-trip původních indexovaných pixelů a nezměněné
SHA-256 vstupů. Vizuálně byly prohlédnuty všechny stupně zásob, 10 slotů
řezání, celé rozběhové/dokončovací archy a zvětšené detaily včetně RX 687.

Skládání vrstev, výběr množství a pracovní plán dokládá lokální **KaM
Remake** `a3b3e5268e1475460e4561f9143df6f1a532e681`. Nejde o rozbor
původního `KM_TPR.exe`. Obrazy jsou **rekonstrukce originálních spritů,
nikoli screenshoty běžící hry**; zachovávají paletu a šachovnicové stíny,
nemají terén, mlhu ani novější změkčení stínů.

Výstup je v ignorovaném
[`original_game_data/kam-reference-export/sawmill-operation/`](../../../original_game_data/kam-reference-export/sawmill-operation/):
`export_sawmill.py`, `manifest.json`, `raw-layers/`, `frames/`, přehledy
a GIFy. Manifest má zdrojové cesty, SHA-256, rozměry a pivoty. Originální
kresba zůstává lokální referencí a není součástí produkčních assetů.

## Zásoby

Pila je DAT index **0**, offset **2100 B**, záznam **1688 B**.
Dokončený dům má RX ID **1**, rozměr **156 × 101 px**, pivot **[−72, −64]**.
Níže jsou RX ID od jedné; DAT obsahuje hodnoty o jedna menší.

| Počet | Klády: RX ID | Prkna: RX ID |
| ---: | ---: | ---: |
| 0 | žádná vrstva | žádná vrstva |
| 1 | 11 | 16 |
| 2 | 12 | 17 |
| 3 | 13 | 18 |
| 4 | 14 | 19 |
| 5 a více v rendereru Remaku | 15 | 20 |

Každé množství má **celý vlastní obrázek hromady**, nikoli několik kopií
jednoho kusu. Klády rostou v levé spodní zóně u stavby, s čitelnými čely
kmenů. Světlá oranžová prkna přibývají ve druhé pevné zóně pod předním
levým okapem, nad otevřenou přední částí. Obě zásoby jsou nezávislé:
[`stocks-0-5.png`](../../../original_game_data/kam-reference-export/sawmill-operation/stocks-0-5.png).

Klády mají společný pivot [−62, −12] a ořezy 21–23 × 34–39 px. Prkna
mají různé ořezy i pivoty: od [−20, −16] / 16 × 17 px po [−38, −26] /
34 × 27 px. Právě pivoty udrží měnící se hromadu na místě; ořezy se
nesmějí znovu centrovat. Remake kreslí pouze počet > 0, používá
`min(počet, 5)` a připojuje zásoby jako vrstvy domu se stejným terénním
posunem. Viz [AddHouseSupply](../../../reference/kam_remake/src/render/KM_RenderPool.pas#L878)
a [limit](../../../reference/kam_remake/src/common/KM_Defaults.pas#L310).

Pět obrázků není důkaz, že zásoba nikdy nepřekročí pět. Remake dovoluje
nový cyklus při výstupu < 5, přičemž pila produkuje **2 prkna z 1 klády**;
vyšší počet renderer saturuje. Viz [kontrola](../../../reference/kam_remake/src/units/KM_Units.pas#L743)
a [recept](../../../reference/kam_remake/src/units/KM_UnitWorkPlan.pas#L376).

## Pohyb tesaře

Pracovní postava je animace konkrétního domu v `houses.rx`, **ne
osmisměrná pracovní sada jednotky**. Všechny aktivní úseky níže mají
DAT posun **MoveX=0, MoveY=7**, přičítaný k pivotu každého obrázku.

| Úsek | DAT sloty | Jedinečná RX ID | Plán doloženého Remaku |
| --- | ---: | ---: | --- |
| `haWork1`: příprava | 30 | 21 | jednou |
| `haWork2`: řezání | 10 | 8 | 25 opakování |
| `haWork5`: dokončení | 30 | 14 | jednou |
| `haIdle`: nečinnost | 30 | 6 | samostatný stav domu |

`haWork3`, `haWork4` ani kouř nemají u originální pily aktivní snímky.
Remake odvozuje délku úseku z `Count × cycles` a v řezacím slotu 1
spouští zvuk pily. Počet opakování není požadavek na ekonomické časování
naší hry. Viz [výpočet délky](../../../reference/kam_remake/src/units/KM_UnitWorkPlan.pas#L116),
[plán](../../../reference/kam_remake/src/units/KM_UnitWorkPlan.pas#L376),
[zvuk](../../../reference/kam_remake/src/houses/KM_Houses.pas#L2085).

**Příprava:** tesař stojí v pravé přední dílně, odsune se doleva za
sloup/stěnu a zmizí. Sloty 8–9 používají drobný prázdný RX 961. Za
zakrytím se objeví nízké části postavy/nástroje, pak se vrací doprava
ke stolici a předkloní se. Cesta k levé venkovní hromadě klád není přímo
vidět; nepřisuzujeme zakrytým snímkům takový děj. Viz
[rozběh](../../../original_game_data/kam-reference-export/sawmill-operation/start-all.png)
a [detail](../../../original_game_data/kam-reference-export/sawmill-operation/start-detail.png).

**Řezání:** předkloněný tesař je zády částečně k divákovi, čelem šikmo
doprava v obraze. Jedna paže zůstává nízko u stolice, druhá provádí
dlouhý tah a vrat ruční pilou doprava a zpět. Pohybuje se také rameno
a lehce trup; postava nechodí na místě. Slot 0 je vnější poloha, slot 4
vnitřní, další snímky pohyb vrací. Stolice/materiál je pevný kontaktní
bod, list jím prochází. Kompasový směr není samostatně definovaný jako
u unit animací. Jde o **ruční list poháněný člověkem**, nikoli zavěšený
rám, který by samostatně jezdil svisle.

Přesné řezací pořadí RX je **687, 688, 774, 692, 693, 692, 691, 690,
689, 688**. Osm jedinečných obrázků má 45 × 40 px a pivot [9, −18]. Viz
[všech 10 slotů](../../../original_game_data/kam-reference-export/sawmill-operation/saw-all.png),
[detail rukou a kontaktu](../../../original_game_data/kam-reference-export/sawmill-operation/saw-detail.png)
a [surový RX 687](../../../original_game_data/kam-reference-export/sawmill-operation/saw-raw-687-10x.png).
Surový obrázek obsahuje i okolní sloup, pozadí a přední prkennou ohradu:
jde o překreslovanou část domu s již vyřešeným zakrytím těla, nikoli
samostatného člověka na čisté průhlednosti.

**Dokončení:** tesař se narovná, vezme viditelná oranžová prkna, odnese
je doleva za stěnu a zmizí. Po delší prázdné části se vrací do přední
nečinné pózy. Viz [dokončení](../../../original_game_data/kam-reference-export/sawmill-operation/finish-all.png)
a [detail přenášení](../../../original_game_data/kam-reference-export/sawmill-operation/finish-detail.png).

## Poučení pro vlastní pilu

- Zachovat vlastní dům, kameru, tesaře 33 world px a fyzických 4 × 2 polí.
  Původní grafika je pohybová reference, ne předloha ke kopírování domu.
- Naše zásoby mají rozsah **klády 0–4 / prkna 0–6**. Nepřenášet původní
  clamp 5 do naší ekonomiky ani do přesného zobrazení šesti prken.
- Zásoby, přítomnost doma a právě probíhající výroba mají odlišný zdroj.
  Obrobek rozpracované dávky už není volná vstupní kláda.
- Vlastní šestifázová smyčka může zachovat vnější polohu, tah, vnitřní
  polohu, obrat, vrat a návrat. Ruce musí držet skutečný nástroj naší
  stolice a jeho list skutečný obrobek. Pohyb rámu se nesmí odvodit jen
  z názvu budovy. Pevná kotva a chodidla, měnící se paže a list.
- Nové průhledné pracovní pózy potřebují vlastní přední zakrytí stolem
  a sloupem. Originální překreslovaný kus fasády není univerzální maska.
- Odpočinek zobrazovat jen skutečnému nepracujícímu obyvateli. Zásoby
  zůstávají při odchodu pracovníka; pracovní figura se zastaví při
  pauze, noci, nepřítomnosti nebo zakázané výrobě.

Export obsahuje **57 původních RX vrstev a 100 registrovaných časových
slotů**, včetně opakování. GIFy mají výslovných 100 ms na DAT slot.
`work-plan-reference.gif` skládá 30 + 25 × 10 + 30 = 310 slotů doloženého
plánu Remaku, drží ilustrační zásobu 4 klády / 0 prken a **nesimuluje
spotřebu zásob**. Je to referenční rytmus, nikoli změřené hraní originálu.
