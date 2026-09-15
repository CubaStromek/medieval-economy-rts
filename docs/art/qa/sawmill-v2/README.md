# QA pily v2 — 2026-09-12

[Brief](../../briefs/sawmill-v2.md) · [integrace](../../briefs/sawmill-v2-integration.md) ·
[zdroje a prompty](../../sources/sawmill-v2/README.md).
Struktura podle [společné šablony](../../object-qa-template.md).
Níže jsou nové důkazy v2; výsledky v1 nejsou přebírány.

## Dodávka a původ

Vlastní imagegen master04 po třech cílených opravách.800² skutečné RGBA,
stejná4×2 zem a footprint_version1. Měřená geometrie je v
[concept-04-geometry.json](concept-04-geometry.json), skutečný export/import
v [base-export.json](base-export.json). Vybraný PNG SHA256:
`642c85d997c985c62750bbb0e70270e60fe7bd7834b77729f5a8be3bc140591a`.
Importovaný RGBA SHA256:
`5fbf68bcf3df8c38c9e8f9d1e29494d605b425e4b986ec923ea2b81c3dee2cd1`.

14 referencovaných PNG mají pravou alfu a existující importy; deklarované
hash identity byly [nezávisle zkontrolovány](pre-switch-resource-audit.json).
Dům, zásoby, pracovní obrobek a postava jsou oddělené vrstvy. Stará vlastní
postava se přebírá v přesném pixelovém znění, všechny domovní kontakty jsou nové.

## Vizuální a geometrická kontrola

| Oblast | Nový skutečný důkaz | Výsledek |
| --- | --- | --- |
| První koncept před derivací | [7 nativních snímků](base-native/README.md), společná chata,33world člověk, rovina i raised4×2 | Pevné kontakty uvnitř, dveře průchozí; střecha posouzena samostatně |
| Natočení, materiály, rozlišení | [Stejný plný záběr s chatou](dynamic-native/full-pair-zoom-2_4.png) | Společný předolevý nadhled/hrubší kresba, rozdílná silueta a otevřená dílna |
| Detail a herní přehled | [Nativní context](dynamic-native/context.png),0.75×/1×/2.4× | Čitelné objemy, práce a stojany; žádná změna kamery hry |
| Zásoby | [Nová geometrie a jednotlivé přírůstky](stock/README.md), všech35 nativních kombinací v dynamic-native |0–4 klády a0–6 prken viditelné po předních maskách; přístup volný |
| Shoda klád s chatou | [Nezávislý rozměrový důkaz](stock/final-size-ground-check.json) | Shodný source→world přepočet; drobný rozdíl AABB pochází z překrytí rámem a filtrace |
| Práce a obrobek | [Technických6 fází](work-contact-preflight.png), [nativní práce](dynamic-native/frames/day-work.png) a motion | Stabilní nohy, podpůrná ruka a tah pily nad kládou; žádný duplicitní odpočinek |
| Denní odpočinek | [Skutečné nativní rest zobrazení](dynamic-native/frames/day-rest.png) | Opření vedle vstupu, čisté dveřní/okenní otvory a správné měřítko |
| Noc / pozastavená dávka | [Noční dům](dynamic-native/frames/night-home.png), activity sheet | Okno a kouř podle pobytu; uložené zásoby i obrobek přetrvávají |
| Přední strom a vyvýšení | [Context](dynamic-native/context.png) | Dílna se zakrývá ve stejné řadě domu; pevné kontakty sedí na podkladu |

`dynamic-native/capture-manifest.json` obsahuje94 skutečných záběrů,
světlo/tick/zoom/stavy a stejné asset hashe před i po běhu. Je to samostatná
nativní geometrická matice plus skutečně provedená výrobní dávka, nikoli
náhrada normální cesty z menu. Root prohlédl společné srovnání, zvýšený
půdorys, práci, odpočinek, noc i6 fází kontaktu. Geometrická větev navíc
prohlédla kompletní zásobovací matici, context a překrytí.

## Testy a normální herní cesta

Výchozí manifest je **v2**. Cílené headless i nativní kontroly prošly
**41/41**; celá povinná sada **854/854**, čisté logy bez chyb a varování.
[Runtime protokol a logy](runtime-migration-audit.md) oddělují headless
a skutečné framebuffer větve.

[Normální menu→Relief→logistika→výroba→noc→save/load](natural/README.md)
prošlo v čerstvé instanci: **6 fází,8 screenshotů,34 pohybových vzorků,
0 selhání**. [Video při skutečné rychlosti1×](natural/work-at-1x.mp4)
zachovává naměřené časování. Před/po načtení zůstala shodná zásoba1kláda/
4prkna i nedokončená dávka s35 zbývajícími pracovními ticky.

Technická integrace a uvedená vizuální kontrola jsou hotové.
[Plán kontrol](verification-plan.md) dokumentuje reprodukci; jeho předpokládaný
počet850 byl nahrazen skutečně dosaženým výsledkem854 aktuálního workspace.

## Omezení a status přijetí

Pevný kontakt se odděluje od téměř průhledné filtrace. Několik jižních pixelů
s alfou nejvýše3/255 sahá asi0.305world za hranici; nevzniká viditelný přesah
zdiva. Bitmapové stavební fáze nejsou nově vyráběny, zachovává se dosavadní
standardní průběh. Postava vykonává menší pracovní pohyb než původní KaM.

Výtvarná revize byla uživatelem autorizována; přijetí konkrétního finálního
exportu ani společného etalonu pro celý katalog zatím doloženo není.
