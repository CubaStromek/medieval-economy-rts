# Tesař v1 — odpočinek doma u pily

Datum **2026-09-12** · role `carpenter` · asset **rest v1**.
Rozsah: vlastní odpočinková póza a její implementace pro pilu podle aktuálního
uživatelského zadání. Stav: **vlastní master a tři pohledy vyrobeny, alfa a
registrace ověřeny 2026-09-12; běžnou hru a opření u pily ověřuje její integrace**.

[Integrace](carpenter-rest-v1-integration.md) · [QA](../qa/carpenter-rest-v1/README.md).
Pila má vlastní [brief](sawmill-v1.md) a [geometrické QA](../qa/sawmill-v1/README.md).
Společný postup určuje [workflow objektů](../object-implementation-workflow.md).
Použit osobní `pixellab-godot-unit-pipeline`: nový kontrakt profese, skutečná alfa,
vlastní měření a normální herní cesta. Tato dílčí výroba používá vestavěný imagegen;
nejde o nový PixelLab balík směrových animací.

## Identita a měřítko

- Vlastní reference je aktuální produkční `carpenter` z
  `game/art/units/civilians-basic-v1.png`. [Výřez 2×](../sources/carpenter-rest-v1/current-carpenter-reference-2x.png)
  vznikl technicky skutečným `UnitSpriteLibrary`; [metadata](../sources/carpenter-rest-v1/current-carpenter-extraction.json)
  dokládají oblast i otisky. Nejde o nový generovaný master.
- Dospělý řemeslník s hustými krátkými hnědými vlasy, bez čepice a bez vousů.
  Teplá okrově krémová košile s vyhrnutými rukávy, tmavohnědá dlouhá kožená
  zástěra se dvěma ramenními popruhy, tmavé kalhoty, hnědé vysoké boty.
  Ve výtvarném návrhu doplnit střídmý dospělý obličej; starý malý atlas má jen
  velmi zjednodušené rysy. Neměnit jej na vousatého dřevorubce.
- Od dřevorubce jej odlišují holá hnědovlasá hlava, světlá košile a velká
  tmavá zástěra. Společné jsou dospělé proporce, přírodní paleta, malované
  modelované objemy, měkké světlo a zvýšený čelní pohled.
- Normální lidská výška z aktuálního čtenáře je **33 world px**. Starý sprite
  má při této výšce šířku 17.5784 world px včetně ruční pily. Nový odpočinkový
  sprite kalibrovat z hlavy k nosné podrážce, bez odvození z pilového nástroje.
- Kamera ukazuje temeno a horní plochy bot. Mírné natočení čela doprava dovolí
  klidné opření horních zad o sloupek. Světlo shora zleva, bez dlouhého vlastního
  vrženého stínu v PNG.

## Póza a vybavení

Uvolněný postoj s horními zády mírně opřenými o neviditelnou svislou oporu.
Jedna noha nese váhu, druhá je přirozeně mírně pokrčená, obě boty zůstávají
viditelné. Ruce prázdné, volně zkřížené pod hrudí. Žádná ruční pila, sekera,
kladivo, kláda, prkno ani kapsa vytvářející falešný nesený předmět. Žádný sloupek,
dům, zem, podstavec, stín nebo světelný lem v charakterovém souboru.

| Stav | Skutečný spouštěč | Dodávaný obraz | Nástroj / náklad | Čas |
|---|---|---|---|---|
| Denní odpočinek doma | Fyzický vlastní obyvatel uvnitř své dokončené pily, bez nákladu, bez spánku či aktivní práce/předání | Jedno celé statické tělo; výchozí hlava | Žádný | Jen při skutečném pobytu |
| Jemné rozhlížení | Tentýž platný odpočinek | Levá / střední / pravá hlava na přesně stejném těle | Žádný | Sdílené klidné časování odpočinku, simulací zmrazené při pauze |
| Práce, přesun, zásoby, noc, nepřítomnost | Skutečný stav hry | Tento venkovní odpočinkový sprite se nekreslí | Stávající ostatní prezentace | Nemění se simulační práce |

„Levá / pravá“ v názvech pohledů znamená směr pohledu na obrazovce, nikoli nový
směr chůze. Hlavu měnit anatomickým natočením, ne zrcadlením těla či pohybem očí.
Límec, trup, paže, opora a obě chodidla musí zůstat pixelově shodné napříč pózami.
Číselnou hranici krku a masku hlavy změřit na tomto tesaři, nekopírovat cizí masku.
Přesná stavová implementace patří k aktuálnímu readeru života pily.

## Podpora a usazení

Navržená opora je **přední levý rohový sloupek vlevo od vstupních dveří**.
Tesař se neopírá o zásoby ani rámovou pilu. Okno je na levém boku tak, aby
nezmizelo za jeho hlavou. Tělo a boty se musí vejít na přidělenou zem pily a
neuzavřít její přístupovou buňku. Kotvu určit až z finální opravené kresby domu:
[brief pily](sawmill-v1.md) je jedinou autoritou půdorysu a prahu.

Póza je grafická reprezentace fyzicky přítomného obyvatele; neposouvá jeho
simulační pozici ani nezabírá další pole. Samostatně měřit kontakt bot,
opření zad, sort bod a příjemce stínu. Venkovní odpočinek nesmí zdvojit skrytý
běžný sprite, náklad, stín, UI ani hit target.

## Výroba a dodávka

Vygenerovat jeden vlastní master podle výše uvedené identity, potom dvě malé
varianty hlavy z tohoto masteru. Uchovat raw výstupy, skutečné prompty a vstupní
otisky. Nástroj neuvádí-li konkrétní model, nevymýšlet jej.
Pokud generátor vrátí namalovanou šachovnici, není to použitelná alfa. Pro
technický klíč použít jednobarevné pozadí mimo paletu postavy; jeho reálnou
barvu a rozsahy změřit z tohoto obrázku a poté ověřit otvory a hrany.

Finální canvas, míra zmenšení, trim, kontakt, alfa meze a hashe jsou v
[produkčním JSON](../../../game/art/buildings/sawmill/v1/life/resting_carpenter.json)
a [integraci](carpenter-rest-v1-integration.md). Body-only měřítko **1280 source px
→ 165 production px → 33 world px** bylo změřeno podle vlasů a nosné podrážky.
Tři zdrojové hlavy neznamenají
schválení celé pohybové sady tesaře. Mimo tuto dodávku je nový walking/work/carry
balík a automatické zavedení celé množiny dalších profesí.

Uživatelské výtvarné přijetí této postavy ani společného etalonu zatím není
doložené. Aktuální explicitní zadání implementace pokračuje bez další brány.
