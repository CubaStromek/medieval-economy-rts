# Pila v1 — herní integrace

Datum **2026-09-12** · ID **sawmill** · budova · stav **zapojeno**.
[Brief a geometrie](sawmill-v1.md) · [QA](../qa/sawmill-v1/README.md) ·
[společný workflow](../object-implementation-workflow.md).

## 1. Rozsah a autority

Uživatel výslovně zadal vlastní podobu pily, komín, levé okno a tesařův
odpočinek a potvrdil přímé zapojení do hry. Půdorys4×2, kolize, vstup,
ekonomika, cena, stavba a save formát jsou autoritou existující simulace.
Stavební PNG a nové inventářové rastry nejsou touto dodávkou zavedeny.

## 2. Geometrie a registrace

Autorita pixelů: game/art/buildings/sawmill/v1/manifest.json.
[Asset validation](../qa/sawmill-v1/asset-validation.json) odděluje fyzické
kontakty, střechu, práh a bod řazení. Finální800² při0.2508world/sourcepx
má registrovaný skutečný jižní práh. Sort anchor je samostatný, zde shodný
s prahem; nezvedá zem ani shadow receiver. První nadměrný koncept byl
zúžen a přeměřen před odvozením provozních vrstev.

## 3. Stavy a vrstvy

Viz [společný kontrakt](../production-building-life-pattern.md) a brief.
Statický dům má zavřené dveře/okenice. Reader otevírá registrované plochy,
kreslí texturované okenice, lokální noční svit a kouř a samostatného domácího.
Tři pohledy tesaře mají shodné tělo/kotvu a přechody používají simulační čas.

## 4. Soubory a převod

- finished-key.png: vlastní1254²RGB z imagegen, reálně změřený modal key247/4/250.
- export-sawmill.cjs: technické odstranění barvy s ověřenými mezemi,
  zachovaný RGBA master, jednotné zmenšení, metadata, hashe a QA.
- game/art/buildings/sawmill/v1/finished.png:800² se skutečnou alfou.
- manifest.json: identita, canvas, alpha bbox, SHA PNG i raw RGBA8,
  registrace a konkrétní life geometry s odkazem na tesaře.
- [Tesařův výrobní záznam](carpenter-rest-v1-integration.md): zdroje,
  vlastní alfa export, výška33px a tři skutečné směry pohledu.

Godot import pily má process/fix_alpha_border=false: import nepřepisuje RGB
průhledných pixelů proti raw hashi. Ověření probíhá nad skutečně importovanými
pixely. Reader vytváří mipmapy a cache textury/hit masky jednou.

## 5. Napojení a kompatibilita

SawmillSpriteLibrary obsluhuje pouze dokončenou pilu footprint_version1.
Validuje identitu, rozměry, konečné kotvy/měřítko, SHA i alfa obal. Chybný
či chybějící podklad ponechá dosavadní vektorový fallback.

MainView volí knihovnu podle typu, zachovává výběr obsazené země a mimo ni
testuje alfu se shodným zakrytím jako při kreslení. Nedokončená pila má
dosavadní vektorové staveniště. Stíny dál vycházejí ze skutečné země.
ProductionBuildingLife čte skutečného obyvatele a produkci; při cizí mlze
se vrací před lookup. Rendering nic nesimuluje ani neodhaluje skryté údaje.
Odpočinkový tesař zastupuje skrytého domácího, nezdvojuje jeho normální
sprite, náklad či pole. Dřevorubecká chata zůstala na svém funkčním readeru.

## 6. Ověření a předání

[Runtime testy](../qa/sawmill-v1/runtime-tests.md) dokládají skutečnou
placenou stavbu, save, kolize, měřítko, mlhu, pauzu a nativní porovnání
spodku se stejným nezakrytým spritem při dni/noci. Nový život domu má
zvláštní stavové a asset testy. [QA](../qa/sawmill-v1/README.md) vede
skutečné výsledky, nativní obrazy a běžný menu→Relief→výroba→noc→save/load.
Distribuční export samostatného balíku nebyl součástí úkolu.
Konceptový směr je přijat, finální herní vzhled ani etalon ještě ne.
