# Odpočívající dřevorubec — pohled do okolí

Datum **2026-09-12**. Malé pokračování vlastního [life v1](../../briefs/lumber-hut-life-v1.md):
tři registrované pózy hlavy, zatímco opřené tělo zůstává přesně stejné.
Záznam podle výrobních částí [společného postupu](../../object-implementation-workflow.md)
a [QA šablony](../../object-qa-template.md). Herní stav, časování a nativní
ověření náleží navazující integraci; tato stránka dokládá samostatné bitmapy.

## Původ a skutečné zadání

Vstupem je vlastní již použitý
`docs/art/sources/lumber-hut-life-v1/resting-lumberjack-rgba-master.png`.
Současné `resting_lumberjack.png` a jeho JSON nebyly přepsány.
Vlastní `finished.png` byla pouze prohlédnuta pro světlo a kontext;
nové generování ji nepoužilo jako vstup. Žádná cizí grafika nebyla vstupem.

Technický výřez masteru (320,0), velikost 500 × 430, zvětšený na 1000 × 860,
je [edit-reference-upper-body.png](edit-reference-upper-body.png). Tři skutečná
zadání vestavěnému `image_gen` jsou v [prompts.json](prompts.json).
Konkrétní model nástroj v odpovědi nepojmenoval. První pokus o průhlednost
vrátil RGB s namalovanou šachovnicí; je zachován jako
`left-rejected-checker.png` a nebyl použit jako RGBA. Levá oprava na technické
purpurové pozadí a přímo zadaný pravý pohled jsou uchovány v `left-key-raw.png`
a `right-key-raw.png`. Výsledné `left-rgba.png`/`right-rgba.png` vznikly až
změřeným exportem alfy.

Obě varianty obsahují skutečně nově nakreslené natočení obličeje, nosu, vousů
a čepice. Levá se dívá do levého okraje obrazu, pravá mírně dále vpravo než
výchozí póza. Nedochází ke zrcadlení, naklánění statické hlavy, překreslení
rukou nebo posouvání těla. Výchozí `center.png` je přesná kopie dosavadního
souboru, včetně všech bytů souboru.

## Registrace a technický export

[export-look.cjs](export-look.cjs) provádí pouze klíčování, změnu rozměrů,
registrovaný přenos hlavy a maskování. Výtvarnou změnu provedl imagegen.
Z normalizovaného výřezu se přebírají pouze pixely nad vnitřním okrajem
původního límce. Polygon ve zdrojových souřadnicích je uložen v
[look.json](../../../../game/art/buildings/lumber_hut/v1/life/look/look.json).
Původní zmenšení a registrace celého těla jsou zachovány.

| Kontrola | Naměřený výsledek |
|---|---|
| Raw oba výstupy | 1353 × 1162, RGB |
| Modalní technický klíč obou zdrojů | RGB (248,4,249) |
| Dominance prázdného vzorku, `min(R,B)-G` | Levý 221–248, pravý 217–248 |
| Vnitřní vzorek čepice | Levý −116 až −3, pravý −123 až −4 |
| Odstranění technického pozadí | Dominance ≥ 196, odmatení hran proti naměřenému klíči |
| Produkční canvas | 256 × 256 RGBA, všechny tři varianty |
| Změněný obal obou pohledů | [104,42,136,81), pravá/dolní mez výlučná |
| Počet odlišných pixelů vůči základu | Levý 821, pravý 799, střed 0 |
| Ochráněné tělo | Všech 44 544 pixelů od řádku 82 dolů přesně shodných |
| Boty | Všechny pixely od řádku 160 dolů přesně shodné |
| Obal alfy > 25 | [94,42,152,206), beze změny |
| Chodidlová kotva | (128,465631929; 205,229379419), beze změny |
| Výška těla / měřítko | 162,71 zdrojových px → 33 world px, beze změny |

Stabilní spodní bod zdrojové masky u krku je (590,351) ve starém masteru,
tedy přibližně (125,378;81,423) na 256² canvasu. Je pouze registrační hranicí
přenosu hlavy, nikoli novou polohou jednotky ve světě nebo vykreslovací kotvou.

## Provedené kontroly a omezení

Samostatný [verify-look.cjs](verify-look.cjs) znovu čte hotové produkční PNG;
[verification.json](verification.json) dokládá rozměry, hashe, přesnou shodu
těla/chodidel, skutečné počty alfy a pixelové sondy. Otvor mezi nohami,
prázdné rohy i bod pod podrážkou mají alfa 0; sonda na podrážce má alfa 255.
V nové hlavě nebyl nalezen silně purpurový pixel s alfa > 127.

Skutečně prohlédnuté karty: [hlavy 6×](head-qa-6x.png),
[světlý/tmavý/zelený podklad](alpha-qa.png),
[tělo přibližně 33 px](body33px-qa.png) a jeho
[zvětšení 4× bez vyhlazení](body33px-qa-4x.png). Na detailu je opačný směr nosu
a tváře čitelný, límec navazuje a založené ruce, zástěra i boty drží.
Na běžné velikosti má hlava asi šest obrazových pixelů a změna pohledu je
záměrně drobná; nativní hra ještě musí potvrdit použité časování a dojem.

Rozsah této kontroly je **samostatný asset**, nikoli nativní import, normální
herní cesta, světelné/okenní stavy, pauza, mlha nebo uložení. Tyto kontroly
provádí navazující integrace. Nevzniká osmisměrný klip ani schválený výtvarný
etalon celého katalogu.

## Produkční soubory

- [center.png](../../../../game/art/buildings/lumber_hut/v1/life/look/center.png)
- [left.png](../../../../game/art/buildings/lumber_hut/v1/life/look/left.png)
- [right.png](../../../../game/art/buildings/lumber_hut/v1/life/look/right.png)
- [look.json](../../../../game/art/buildings/lumber_hut/v1/life/look/look.json)

Zdroje zůstávají v tomto adresáři. Výtvarné přijetí celé sady uživatelem
není tvrzeno; varianty jsou připravené pro právě zadanou herní implementaci.
