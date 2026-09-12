# Dřevorubecká chata — stavební sada v1

Datum **2026-09-10** · ID `lumber_hut` · manuál **v0.2**.
Stav: **výroba herního pilota**, nikoli uživatelem schválený etalon sady.
Aktuální požadavek uživatele výslovně rozšiřuje předchozí konceptovou práci
o implementaci ve hře: stejných **12 + 21** grafických stavebních kroků jako
v prozkoumaných datech KaM, s vlastní chatou.

## Úloha, identita a obrazové podklady

Vychází z [vlastního konceptu v3](lumber-hut-v3.md): nízký otevřený pracovní
přístřešek vlevo a vyšší uzavřená chata vpravo, kamenné patky, dřevěné
trámy/prkna, malá krémová výplň, šedohnědý šindel. Lesní řemeslná rodina;
hlavní motiv pracovní přístřešek, podpůrné motivy kozel a držák seker.
Lesníkova školka ani sazenice sem nepatří.

KaM dodává princip dvou obrazových vrstev s maskami pořadí a počty kroků.
Žádná jeho bitmapa nebo obkreslená architektura nebude produkčním vstupem.
Obrazový vstup je pouze vlastní `docs/art/concepts/lumber-hut-v3.png`.

## Geometrie a registrace

- Katalog `game/data/buildings.json`, maska **### / ##E**, 3 × 2 = 6 polí.
- Kotva levé dolní pole, dveře `(2,0)`, venkovní vstup `(2,1)`.
- Práh `terrain.project_grid_position(Vector2(door_cell) + Vector2(0,0.5))`.
- Osová mřížka 40 × 40; obsazená zem 120 × 80 world px, výška −8 px/úroveň.
- Vyvýšený předolevý pohled převzatý z vlastní v3; viditelný levý bok a
  horní plochy. Neotáčet mřížku, neměnit půdorys ani uložená data.
- Cíl běžného člověka 33 world px; měřítko dveří, patky a povolené malé
  přesahy ověřit přímo ve hře, ne podle celkové šířky souboru.
- Všechny stavy mají canvas **640 × 640**, práh **(568,410)** a měřítko
  **0.225 world px / source px**. Při alfě >0.1 je obal konstrukce
  `(11,56)–(633,577)` a hotové kresby `(10,47)–(633,577)`; horní meze
  jsou výlučné. Skutečná šířka siluety je přibližně 140 world px.
- Samostatný `sort_foot` **(568,488.1111)** je stabilní pro všechny kroky:
  společný spodní okraj 577 minus půl políčka. Řadí kresbu, neposouvá ji
  ani dveře. [Rozbor KaM a příčina původního ořezu](../kam-object-terrain-rendering-study.md).
- Výběr přes skutečnou alfa siluetu; staré půdorysy mají původní fallback.

## Stavební fáze a obrazová výroba

1. Připravená zem nadále používá současnou herní logiku srovnávání.
2. Nový roofless konstrukční master: kamenné patky, nosné trámy, rámování
   a nedokončené stěny téže chaty. Bez šindelové střechy, komína, nářadí,
   zásob a osob. Maska označí **12** souvisle a věrohodně přibývajících částí.
3. Dokončený prázdný master se skutečnou alfou; druhá maska má **21** kroků
   pro stěny, střechy, komín a vybavení. Odkrytá finální část nahradí i
   konstrukční podklad v jejích otvorech. Poslední stav přesně finální master.
4. Simulační postup je čten ze stávajícího `construction_remaining`;
   60 % práce konstrukce a 40 % dokončení. Náklady, trvání 120 pracovních
   ticků, logistika, srovnávání a save formát se tím nemění.

Dvě kresby a původní vlastní masky umožní stabilní polohu domu po všech
33 krocích. Není třeba generovat 33 vzájemně posunutých samostatných domů.
Masky jsou kódově popsané pořadí částí, nikoli generativní přemalování.
Nové obrazové podklady vytvoří vestavěný **imagegen**; skutečná zadání,
vstupy, výstupy a kontrola alfa kanálu budou archivovány.

## Stavové vrstvy

Statický dům a konstrukční vrstva neobsahují produkční zásoby, osoby,
kouř ani aktivní indikátor. Zásobní stojan je prázdný; jeho plocha a
dveřní závěs zachovávají přípravu budoucích stavů z v3.

| Vrstva/stav | Dodávka tohoto úkolu | Zdroj a pořadí |
|---|---|---|
| Konstrukce | Nová kresba + maska 1–12 | Skutečný stavební postup |
| Hotový prázdný dům | Nová RGBA varianta + maska 1–21 | Nahrazuje konstrukci; denní tónování |
| Produkční klády | Nové bitmapové vrstvy nejsou součástí úkolu | Skutečné `outputs.log`, nyní kapacita 6; stávající HUD |
| Fyzická přítomnost | Nový světový indikátor není součástí úkolu | `inside_building_id`, samostatně od práce/přidělení; stávající HUD |
| Počet, postup, výběr | Stávající herní UI | Mimo statické PNG |

Kotvy `door_threshold`, `stock_origin`, plánované `log_slot_1…6`,
`occupancy_indicator` a `stock_count_label` zůstávají rozlišeny: pro
integraci je závazně změřený práh; neimplementované zásobní kotvy se
nesmějí vydávat za hotové runtime vrstvy. Žádná dekorace nesmí předstírat
kladný inventář. Nedokončený dům nezobrazuje hotové produkční stavy.

Obraz podléhá stávajícímu hloubkovému řazení, mlze, světlu a pozemnímu
stínu. Práva na cizí zásoby či osoby se nerozšiřují. Globální pauza a
pozastavení dělníka zastaví postup tím, že se zastaví jeho skutečná práce.

## Výstup a přejímka

Umístění `game/art/buildings/lumber_hut/v1/`: barevné RGBA
masters, dvě bezeztrátové masky a manifest s registrací. Původ a přesná
zadání v [produkčním záznamu](lumber-hut-construction-v1-prompts.json). Žádné falešné průhledné šachovnice,
zapečený světlý obdélník, zemní ostrov ani dlouhý statický stín.

Provedené QA: všech 33 stavů, základ bez konstrukce, přesný konečný master,
stejná kotva; skutečný pracovní postup/save/load/pauza; 0.75×/1×/2.4×,
dveře s člověkem, rovina/výška, den/noc, výběr alfa a překrytí, vlastní/cizí
mlha, stará verze půdorysu. **705/705** herních kontrol a **12/12** zaměřených
nativních kontrol prošlo. [Výsledky, skutečné snímky a meze pilota](../qa/lumber-hut-construction-v1/README.md)
zahrnují dosud neschválené usazení předních patek a proporce dveří.

Uživatelské schválení konkrétního obrazu / etalonu celé sady: **zatím ne**.

## Vyrobené podklady a technická kontrola, 2026-09-10

Vestavěný imagegen vytvořil dvě vlastní kresby z v3: hotovou prázdnou
chatu a stejnou stavbu bez krytiny v dřevěné konstrukci. Nástroj model
výslovně neidentifikoval. První pokus vrátil namalovanou šachovnici a byl
odmítnut; není herním vstupem. Přijaté kresby mají sytě purpurové exportní
pozadí, ze kterého technický export vytvořil skutečnou RGBA průhlednost
včetně odstranění barevného lemu. Originály i odmítnutý výstup jsou
archivované v `docs/art/sources/lumber-hut-construction-v1/`.

`tools/pack-lumber-hut-construction.cjs` nemaluje novou architekturu:
odstraňuje exportní pozadí, společně zmenšuje a zapisuje vlastní masky
pořadí. KaM obrázky nejsou vstupem tohoto nástroje ani herního balíku.
Masky jsou celočíselné bezeztrátové PNG; dokončovací zóny zahrnují i místa,
kde má finální průhlednost odstranit dočasný dřevěný podklad.

Kontrola skutečných souborů: oba rohy obou RGBA exportů mají alfu 0,
konstrukce má 243193 zcela průhledných a 149147 plně neprůhledných pixelů;
hotový dům 215935 průhledných a 184131 neprůhledných. Všech 33 výsledných
rasterů má rozdílný otisk a poslední přesně odpovídá hotovému masteru.
Otisky zdrojů a výsledků jsou v manifestu a
`docs/art/qa/lumber-hut-construction-v1/asset-validation.json`.

První nativní herní snímky odhalily chybu hloubkového řazení: další řádek
terénu přemaloval přední část domu. Tyto první snímky nebyly úspěšnou
přejímkou. Oprava používá samostatný stabilní bod řazení podle výše
uvedeného rozboru; finální vizuální a herní výsledky následují v QA záznamu.
