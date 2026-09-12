# Kontrola zásob dřevorubecké chaty v1

Datum **2026-09-10** · ověřil Codex · oprava provozní vrstvy `lumber_hut`.
Záznam podle [QA šablony](../../object-qa-template.md),
[integračního záznamu](../../briefs/lumber-hut-stock-v1-integration.md)
a [zásobního briefu](../../briefs/lumber-hut-v3-stock.md), manuál v0.2.
Změna je implementovaná; schválení výtvarného etalonu sady z ní nevyplývá.

## 1. Ověřený rozsah a soubory

Klády jsou samostatné RGBA překryvy nad původní chatou. Počet čte skutečné
`outputs.log`, dnešní kapacita je šest kusů, skladba 3 + 2 + 1.
Vlastní malovaná kláda pochází z existujícího konceptu a byla technicky
vyjmuta/exportována; nové generování budovy ani klád neproběhlo.

Kód je místní změna nad `7af2a48`. Přesné otisky kódu, sedmi zásobních
PNG, manifestu a původní chaty obsahuje [capture-manifest.json](capture-manifest.json).
Údaje o měřených kotvách, alfě a původu jsou v
[`stock/manifest.json`](../../../../game/art/buildings/lumber_hut/v1/stock/manifest.json).
Oba masters, obě stavební masky, původní manifest a knihovna stavebních
fází byly porovnány s [otisky před opravou](verification/preserved-house.sha256):
všech šest souborů zůstalo identických.

Nativní prostředí: **Godot 4.7.2**, macOS, Apple M4, Compatibility/OpenGL.
Nově spuštěné procesy po importu; izolované světy a dočasné save cesty,
bez načítání/přepisování hráčových pozic. Projekt nyní hudbu neobsahuje;
produkční runner navíc respektuje samostatný hudební bus.

## 2. Běžná hra a skutečná simulace

`res://tests/lumber_hut_stock_game_runner.tscn` projde skutečné hlavní menu,
volbu nové hry/Relief a normální těžbu. Dřevorubec vyjde ke stromu, získá
kládu, přinese ji a odevzdá do chaty. Runner nemění inventář ani akce
pracovníka; nastavuje pouze rychlost a kameru a při zachycení obraz pozastaví.

**Prošlo:** sedm pozorovaných fází, 17 nativních snímků, nula selhání.
Před odevzdáním stojan zůstává prázdný; při skutečném odevzdání v ticku 94
se objeví jedna kláda a HUD ukazuje stejný počet.
[Výsledek ve hře](natural/09-delivered-2_4x.png),
[úplný report](natural/report.json), [log](verification/natural.log).

Zaměřené testy samostatně provedly skutečný odvoz všech šesti klád
nosičem do skladu: rezervace zásobu neodečte, každé odečtení odpovídá
fyzickému vyzvednutí. Všechna množství 0–6 prošla skutečným JSON save/load.

## 3. Nativní obrazové a stavové kontroly

`res://tools/preview_lumber_hut_stock.tscn` používá skutečnou hlavní scénu
na izolované mapě 32 × 24, chata na `(14,12)`. Tyto inventáře a kontexty
jsou **uměle nastavené QA stavy**, nikoli doklad času výroby šestikusové zásoby.
Výstup je 31 herních snímků a čtyři archy. Prohlédnuty jsou všechny archy,
finální HUD, mlha a nedokončený dům.

| Kontrola | Výsledek a důkaz |
|---|---|
| Jednotlivě 0–6, čitelnost | Prošlo: [0.75×](stock-zoom-0-75.png), [1×](stock-zoom-1-00.png), [2.4×](stock-zoom-2-40.png). V detailu šest samostatných čel; při oddálení je přesný počet spolehlivě v HUD. |
| Alfa a registrace | Prošlo: nula má zcela prázdnou alfu; ostatní vrstvy mají měřené neprůhledné pixely. Dům ani již položené klády mezi stavy neskáčou. |
| Skutečně vykreslené pixely | Prošlo: 18 změn proti prázdnému a předchozímu stavu napříč třemi zoomy. Zaměřená nativní sada navíc porovnává konkrétní pixely každého přidaného čela s prázdným obrazem. |
| Sloupky, terén a pořadí | Prošlo pro zásobní vrstvu: sloupky/lišty zůstávají před kládami, klády sdílejí řádek chaty. [Kontexty](contexts.png). |
| Klikání | Prošlo: skutečná nově neprůhledná kláda mimo alfu prázdného domu a půdorys vybere chatu; stejné místo při nulové zásobě propouští kliknutí. |
| Den/noc | Prošlo: zásoba zachová množství, skutečné pixely klád se v noci ztmaví s domem. |
| Pauza a přítomnost | Prošlo: vypnutá výroba, pozastavený pracovník i pobyt uvnitř ponechají šest klád. |
| Mlha a soukromí | Prošlo: cizí živý inventář se nečte a nemění soukromou prezentaci; `?` je uvnitř stojanu. Neznámé území celý dům skryje. |
| Stavba | Prošlo: srovnávání a nedokončený dům včetně posledního pracovního ticku provozní klády nezobrazují. Stavební podklady jsou beze změny. |
| Změněná kapacita / legacy | Prošlo: přesný údaj 8/9 místo tichého předstírání šesti; staré kompaktní půdorysy zachovávají dosavadní renderer. |
| Geometrie a kontakty celého domu | Odloženo uživatelem. Známý přesah patek/stojanu a nesoulad kresby s půdorysem zůstávají; zvýšený základ potvrzuje shodné kotvy zásob, nikoli opravu této vady. |
| Nový indikátor přítomnosti, jiné objekty | N/A — nejsou součástí opravy zásob. |

## 4. Testy a pozitivní kontroly

- Aktuální zaměřená sada: **8/8 bez okna**, [log](verification/focused-headless.log).
- Stejná sada s nativním vykreslením: **8/8**, včetně nového alfa výběru,
  šesti čel a nočního kontrastu, [log](verification/focused-native.log).
- Celková herní sada: **743/743**, [log](verification/full-headless.log).
- Obrazový runner: **35 výstupů a 18 pozitivních porovnání**, konkrétní
  hodnoty a otisky v [manifestu](capture-manifest.json).

První nativní běh správně selhal na validaci rozměrů JSON manifestu
(číselné typy v poli). Nešlo o úspěšnou kontrolu. Opraveno explicitním
převodem rozměrů; následné běhy načítají skutečné textury a ověřují jejich
viditelné pixely. [Původní selhání](verification/initial-load-failure.log)
zůstává evidované. Samotná změna dat bez nakreslených klád by pozitivními
pixelovými kontrolami neprošla.

## 5. Výsledek a otevřený bod

Zobrazování skutečné zásoby je opravené v běžné herní cestě a nevyžaduje
migraci pozice. Při spuštění nové herní instance se zásoba načte z
existujících uložených dat. [Plný stojan s HUD](game-stock-complete.png).
Půdorys, vzhled domu a 33 stavebních změn zůstávají beze změny podle
výslovného pokynu uživatele; druhý nahlášený problém čeká na další domluvu.
