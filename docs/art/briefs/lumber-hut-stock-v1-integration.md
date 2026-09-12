# Implementace objektu: zásoby dřevorubecké chaty v1

Datum **2026-09-10** · ID `lumber_hut` · budova, oprava provozní vrstvy.
Stav: zapojeno a ověřeno ve hře. Postup podle
[implementační šablony](../object-integration-template.md) a
[společného postupu](../object-implementation-workflow.md).

## 1. Rozsah a autority

Uživatel schválil pouze opravu chybějících klád. Druhý nahlášený problém,
nesoulad kresby s půdorysem, výslovně odložil. Tento zásah nemění dům,
jeho stavební fáze, registraci, masku, vstup, výšku terénu ani kameru.

Výtvarný základ a původ zásob vede [zásobní brief v3](lumber-hut-v3-stock.md);
geometrii hotového domu a 12 + 21 kroků vede
[stavební brief](lumber-hut-construction-v1.md). Manuál zůstává v0.2,
žádný nový etalon sady není schválen.

## 2. Geometrie a registrace

Zásobní PNG sdílejí původní canvas domu. Runtime přebírá `rect` a
`source_to_world` přímo z prezentace chaty; nevytváří jiný práh, řazení
ani příjemce stínu. Měřené pozice šesti čel, souřadnice popisku, alfa obaly
a otisky vrstev jsou v
[`stock/manifest.json`](../../../game/art/buildings/lumber_hut/v1/stock/manifest.json).
Přední sloupky a lišty jsou ze zásobní vrstvy vyloučené alfa maskou.

Známé přesahy patek a stojanu z předchozího QA zůstávají otevřeným
samostatným bodem; oprava klád není jejich přejímkou.

## 3. Stavy a datové zdroje

| Vrstva / stav | Zdroj | Zobrazení |
|---|---|---|
| Hotová prázdná chata | Stávající dokončený master | Beze změny |
| Klády 0–6 | `building.outputs.log` | Pevné pozice 3 + 2 + 1; nula má prázdnou alfu |
| Kapacita | Aktuální katalog `output_capacity` | Při změně kapacity explicitní počet; bez tichého ořezu údaje |
| Cizí zásoby při zapnuté mlze | Stejná politika jako HUD | Nečtou se, neutrální `?`, žádná potvrzená nula |
| Nedokončený dům / srovnávání | `world.is_building_complete()` | Žádné provozní klády |
| Přítomnost a práce | N/A pro tuto dodávku | Nový indikátor se nezavádí |

Nesená kláda a rezervace nejsou zásoba domu. Přírůstek nastává při
skutečném odevzdání, úbytek při fyzickém vyzvednutí nosičem. Pauza,
vypnutá výroba či pracovník venku existující zásobu nesmažou.

## 4. Podklady a export

`tools/pack-lumber-hut-stock.cjs` technicky vyjímá malovanou kládu
z již existujícího vlastního konceptu `logs-6.png`, skládá ji do pevných
pozic a exportuje skutečné RGBA vrstvy. Nevytváří novou kresbu domu.
Nové generování obrázků nebylo spuštěno. Původní dům, masky, manifest
a knihovna stavebních fází se ověřují proti otiskům před touto opravou.

## 5. Zapojení a kompatibilita

`LumberHutStockLibrary` cachuje textury a alfa masky; `main_view.gd`
kreslí vrstvu hned po domě ve stejném řádku, s jeho tónováním a mlhou.
Výběr zahrnuje skutečnou alfu klád a zachovává původní výběr obsazené země.
Starší kompaktní půdorysy používají dosavadní renderer. Data simulace
a formát uložených pozic se nemění.

## 6. Předání

Výsledky a skutečné herní snímky obsahuje
[QA záznam](../qa/lumber-hut-stock-v1/README.md). Samostatná nativní ukázka
ověřila jednotlivé stavy; běžná cesta menu → Relief → těžba → odevzdání
ověřila připojení zásob v produkční scéně. Původní dům a všechny jeho
stavební podklady zůstaly shodné podle SHA-256.
