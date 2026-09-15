# Pila — kontrola grafiky uložených zásob

Datum **2026-09-12**. Konkrétní rozsah: vlastní kláda a prkno, 4 sloty vstupů
a 6 slotů výstupů, přesná maska původního popředí. Stav: **asset kontroly a
statické prohlídky prošly; běžná simulace je samostatné QA provozu pily**.
[Brief provozu](../../briefs/sawmill-operation-v1.md) ·
[preflight](geometry-preflight.md) · [původ](../../sources/sawmill-operation-v1/stock-provenance.json).

## Přesné podklady a registrace

Autorita produkce je [geometry.json](../../../../game/art/buildings/sawmill/v1/operation/stock/geometry.json).
`log.png` má 38 × 27 px, `plank.png` 76 × 41 px, každý px odpovídá jednomu
pixelu současného domu 800² a 0.2508 world px. Obě primární PNG se v každém
slotu pouze překládají; množství není další generovaný dům.

Finální levé horní rohy klád jsou `[368,482]`, `[378,478]`, `[368,470]`,
`[378,466]`. Oproti ranému preflightu jsou menší a posunuté tak, aby čela
nezanikla za pravým sloupkem malého lože. Prkna používají x579 a y
479, 473, 467, 443, 437, 431: dvě skutečné police po třech kusech.
Preflight JSON není runtime autorita; obsahuje historický návrh před výrobou.

Samostatný prop contact označuje spodní stranu zboží na podpěře, není to
mapový bod země. V originálu klády má poslední alfa>127 řádek y819 rozsah
x1028…1050, proto spodní kontakt `[1039,820]`; u prkna poslední řádek859
spadá do x1256…1264, kontakt `[1260,860]`. Převod po trimu vede manifest.
Fyzické zemní kontakty drží původní lože a regál z preflightu; neměníme je.

## Skutečná alfa a masky

Oba raw jsou RGB 1536 × 1024. Jejich vlastní technická magenta byla změřena,
nikoli zkopírována z jiného objektu. Kláda: modal `[252,2,251]`, horní prázdný
pás dominance227–252, celý známý vnější prostor206–252, práh198. Prkno:
modal `[252,4,250]`, horní pás224–250, vnější prostor200–250, práh192.
Poslední spodní rohový pixel byl při prvním příliš vysokém prahu slabě viditelný;
měření celého vnějšího prostoru jej odhalilo a výše uvedené prahy ho odstranily.
Finální master má čistý průhledný vnější prostor a zachované hrany.

Produkční alfa klády: 367 nulových / 311 částečných / 348 neprůhledných pixelů.
Prkno: 1 980 nulových / 612 částečných / 524 neprůhledných pixelů. U obou0
zbytkových magenta pixelů při alpha>25 a dominance>45. Vlastní master,
trim, měřítko a hashe jsou v [měření zdrojů](../../sources/sawmill-operation-v1/stock-source-measurements.json).

Maska `occlusion-mask.png` chrání přední lišty a sloupky malého lože, přední
sloupky/čela polic regálu a blízké sloupy/ostění/okap. Záměrně neobsahuje stůl
ani nový pracovní mechanismus. `foreground.png` kopíruje přesné původní house
RGBA pod stejnými polygony jako alternativu překreslení popředí. Doporučená
kompozice vynuluje zásoby pod maskou a ponechá původní dům beze změn; nedochází
k dvojímu zesílení jeho částečně průhledných hran.

Každý export ověřuje původní house SHA
`349924968b535bf299d9933e00d476bdf357f87a3011b628a420a2d7e06315a4`.
Půdorys, dveře, pracovní stůl a stálá architektura se nepřekreslují.

## Co bylo skutečně prohlédnuto a provedeno

- [Všechny klády0–4](log-all-states-3x.png): každý kus přibývá samostatně,
  prázdné lože při nule; maximum má4 čitelná světlá čela, část spodků přirozeně
  zakrývá přední příčka. Žádná kláda neleží přes dveře ani levou hranu stolu.
- [Všechna prkna0–6](plank-all-states-3x.png): nejprve dolní3, poté horní3;
  přední sloupky zůstávají před zbožím a jednotlivé světlé vrstvy jsou čitelné.
- [Společné maximum v detailu](stock-max-detail-4x.png), [celý dům](stock-max.png)
  a [1× world měřítko](stock-max-world1x.png): zboží neruší siluetu domu ani
  uličku. Při1× je množství hlavně čitelné jako velikost zásoby; přesná čísla
  nadále uvádí stávající HUD.
- Technický export Node + Sharp prošel. Všechny sousední množstevní stavy mají
  odlišné skutečné RGBA: změny klád496/632/577/650 pixelů a prken
  802/817/825/837/962/1070 pixelů. Souborové otisky a0stavy jsou v
  [stock-asset-validation.json](stock-asset-validation.json).

Tyto obrázky jsou složení skutečného produkčního domu a props, nikoli nativní
herní screenshoty. Neověřují fyzické předání nosičem, produktivní proces,
mlhu, pauzu, save/load, výkon readeru ani svah. Tyto osy ověřuje runtime
integrace. User schválení finálního herního vzhledu a etalonu není tímto
technickým výsledkem udělené.
