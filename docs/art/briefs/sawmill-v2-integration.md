# Implementace objektu: pila v2

Datum: **2026-09-12** · ID `sawmill` · výtvarný směr v0.2.
[Brief](sawmill-v2.md) · [QA](../qa/sawmill-v2/README.md) ·
[zdroje a přesná zadání](../sources/sawmill-v2/README.md).
Záznam používá [společný postup](../object-implementation-workflow.md)
a strukturu [integrační šablony](../object-integration-template.md).

## Zadání a rozsah

Uživatel autorizoval přepracování po přímém srovnání s vlastní dřevorubeckou
chatou. Nová malovaná pila má výraznější předolevý nadhled, stejné hrubší
materiály, dlouhou souvislou střechu, místnost vlevo a otevřenou dílnu vpravo.
Konkrétní nový export zůstává iterací, nikoli uživatelem schváleným etalonem.

Herní autorita: `buildings.json`, `recipes.json`, `building_footprints.gd`
a živý `SimulationWorld`. Zachováno4×2, maska `####/#E##`,160×80world,
footprint_version1. Herní kotva je vlevo dole: door offset(1,0), venkovní
přístup(1,1). Revize nemění simulaci, mřížku, kameru ani formát uložené hry.

## Geometrie a registrace

Autoritativní nové hodnoty jsou v produkčním
`game/art/buildings/sawmill/v2/manifest.json`, nikoli ve starém v1 briefu.
Měření vybraného1254² masteru04: [source geometrie](../qa/sawmill-v2/concept-04-geometry.json).
Skutečný800² RGBA export a jeho otisky: [base export](../qa/sawmill-v2/base-export.json).
První podklad byl [nativně prohlédnut před derivací vrstev](../qa/sawmill-v2/base-native/README.md).

Registrace je stále `origin = terrain door − source door_threshold × scale`.
Uniformní scale0.18731625, práh a visual sort foot jsou shodné v nově
naměřeném zdrojovém bodě. Dveře mají přibližně35.2×14.6world proti33world
člověku. Měření pevného kontaktu se odděluje od velmi slabého filtračního lemu:
na jižní hraně může nenulová alfa3/255 přesahovat asi0.305world; viditelné
zdivo, patky, podpěry a vstup se vejdou do stávající země.

Nové dveře, levé okno, komín, rest foot a work foot jsou v
[life/work metadatech](../sources/sawmill-v2/life-work-fields.json).
[Zásoby a přední masky](../../../game/art/buildings/sawmill/v2/operation/stock/geometry.json)
se měří v canvasu nového domu. Body rekvizit na stojanu nejsou pozemními
navigačními kotvami. [Kalibrace práce a odpočinku](../qa/sawmill-v2/life-work-calibration.md)
odlišuje technický kompozit od nativní kontroly.

## Vrstvy a skutečné stavy

Základ → jednotlivé zásoby → rozpracovaná kláda → pracovník → nové přední
sloupky/stojany → domácí vrstvy. Statický master je prázdný: nemá zásoby,
pracovníka, pracovní nástroj ani kouř. Nepotřebuje v1 záplatu dílenské stěny.

| Viditelný stav | Zachovaná skutečná autorita |
| --- | --- |
| 0–4 vstupní klády /0–6 prken | Živé `inputs.log` a `outputs.plank`; dodávka a odvoz mění jednotlivé kusy |
| Kláda na stole | Skutečná rozpracovaná dávka, přetrvá pauzu a noc |
| Řezající tesař | Fyzicky přítomný operátor a `active_work`; šest fází sleduje pozorovaný productive progress |
| Domácí odpočinek | Fyzický pobyt skutečného tesaře; samostatná práce vylučuje duplicitní postavu |
| Okno, dveře, noc a kouř | Existující `ProductionBuildingLife`, nové geometrické zóny |
| Cizí stav v mlze | Unknown se vyhodnocuje před čtením živých zásob, dávky a obyvatele |
| Rozestavěný dům | Dosavadní vektorové fáze až do skutečného dokončení |

Pracovní a odpočinkové PNG jsou přesné vlastní v1 assety s novými kontakty
a samostatnými head turns. Od 2026-09-13 má ohnutá pracovní póza31world,
odpočinek nadále33world; [oprava usazení truhláře](carpenter-sawmill-spatial-v1-integration.md)
zachovává opřenou dlaň a přidává kontaktní stíny i místní zastínění.
Klády zásob jsou vlastní
klády chaty ve stejném světovém měřítku. Prkna používají vlastní v1 master
uniformně zmenšený podle nového stojanu. Přední maska je vybraná přímo
z nového domu; stůl nezakrývá pracovní ruce a nástroj.

## Import a napojení

`SawmillSpriteLibrary` přijímá v1/v2 a validuje skutečný importovaný RGBA hash.
`SawmillOperationArt` dovoluje chybějící architektonický backplate, ale nadále
odmítá vadný výslovně zadaný patch. `process/fix_alpha_border=false` zachovává
exportní RGBA nových PNG. Vše prochází existující řadou domu, tónováním,
terénním zakrytím, mlhou a alpha klikáním. Nové stavové větvení v Main není
potřeba. Cache rozlišuje skutečné resource/manifest cesty.

[Audit přechodu](../qa/sawmill-v2/runtime-migration-audit.md) a
[finální QA](../qa/sawmill-v2/README.md) uvádějí skutečný aktivní default,
testové výsledky a běžnou herní cestu. Staré soubory v1 zůstávají zachované;
uložené objekty s footprint_version1 dostávají aktivní kresbu bez migrace. Legacyv0,
neúplná stavba a chybějící/vadný asset zachovávají původní fallback.

## Předání a omezení

Nové bitmapové stavební fáze nejsou součástí této výtvarné iterace. Technické
ověření není automatické uživatelské přijetí stylu. Výsledek lze dále výtvarně
iterovat; společný etalon pro hromadnou výrobu budov zatím není udělen.
