# Pila — QA zásob a pracovního cyklu v1

Datum **2026-09-12**. Stav: **finální integrace ověřena**. Tento záznam nenahrazuje
historické výsledky předchozí denní/noční pily.
[Brief](../../briefs/sawmill-operation-v1.md),
[integrace](../../briefs/sawmill-operation-v1-integration.md),
[původní geometrie domu](../../briefs/sawmill-v1.md),
[přesně prohlédnutá reference KaM](../../references/sawmill-kam-study-2026-09-12.md).

## Podklady a registrace

Vlastní imagegen výstupy a prompty jsou v `docs/art/sources/sawmill-operation-v1/`.
Původní KaM grafika zůstává jen v odděleném ignorovaném referenčním adresáři;
žádný původní pixel nebyl použit k výrobě našich vrstev.

- Dům: stejný půdorys 4 × 2, vchod i registrační canvas 800² a měřítko 0.2508.
  Vnější alfa, konstrukční kontakty a výšková projekce se nepřepisují.
- [Preflight](geometry-preflight.md) dokládá lože klád, dvě police prken,
  pracovní otvor a překrytí sloupky. Sloty jsou v produkčním canvasu domu.
- [Zásoby](stock-art-qa.md): 4 samostatné klády a 6 prken; všechny dílčí
  množstevní podoby prohlédnuté. [Měření](stock-asset-validation.json) vede
  skutečnou alfu a přesné otisky.
- [Lokální stěna](backplate-check.png): jen autorská maskovaná úprava
  pracovního pozadí po odstranění zavěšené pily; stůl, budova a stojany
  zůstávají z původního vlastního souboru.
- [Kontaktní zkouška](work-contact-preflight.png) je technická předběžná
  kompozice první pózy v 33 world px; nedokládá finální animační sadu nebo runtime.
- [Finální pracovník](worker-art-qa.md): 6 samostatných PNG, skutečná alfa,
  fixované chodidlo, spodní tělo, hlava a opěrná paže; jeden tuhý pilový list.
  Zdrojové tělo 412 px se kreslí v 33 world px, registrace `[374.5,489]`
  na bod domu `[521,549]`. [Nezávislý Godot odečet](worker-asset-verification.json)
  prošel 6/6, včetně pozitivních pixelů zástěry/bot a nulového zbytku klíčovací barvy.

## Autoritativní stavy a cílená logika

Uložené klády čte `inputs.log`, prkna `outputs.plank`; nosičské rezervace
a nesené kusy se nezapočítávají. Jedna spotřebovaná kláda v řezu má vlastní
vrstvu podle rozpracované dávky. Prkna přibudou až po skutečném dokončení.
Známá zásoba je oddělená od oprávněné informace o domácím pracovníkovi.

[Stavový protokol](state-adapter-tests.md) a [první cílený log](state-adapter-tests.txt)
dokládají **12/12** bezokenních kontrol před finálními obrazovými testy:
fyzické předání a vyzvednutí, výroba, pauza, noc, výživa, privátní mlha,
každý skutečný tick zrychlené hry a reset po načtení stejného světa/ticku.
Tento výsledek není vizuálním schválením ani náhradou běžné hry.

## Závěrečné kontroly

| Kontrola | Stav |
|---|---|
| Všechna množství v nativní hlavní scéně | Prošlo, [12 množstevních pohledů](native/stocks.png); všech 35 kombinací ověřuje cílená sada |
| Pracovní cyklus, pevné nohy/opora/list | Prohlédnuto všech 6 póz ve hře; [nativní cyklus](native/work-cycle.mp4) a [skutečná práce při rychlosti 1×](natural/work-at-1x.mp4) |
| Zásoby při odpočinku, pauze, noci a nepřítomnosti | Prošlo, [stavový přehled](native/activity.png); rozpracovaný kus přetrvává, pracovník při přerušení neřeže |
| Čitelnost při 0.75×, 1×, 2.4×, vyvýšená plošina a přední strom | Prohlédnuto, [kontext](native/context.png); nohy na dlažbě, zásoby za podpěrami, strom před dílnou |
| Nativní pozitivní kontrola pixelů a klikání | 20/20 cílených testů, skutečný framebuffer a výběr pily přes pracovní kresbu |
| Běžné menu → Relief → skutečná výroba → noc → save/load | Prošlo, 6 fází, 8 snímků, 35 pohybových snímků, [report](natural/report.json), 0 selhání |
| Úplná povinná sada | 849/849, bez chyb a varování; [finální protokol](final-runtime-tests.md) |

Řízený nativní runner `preview_sawmill_operation.tscn` má oddělené zásobní,
stavové a kontextové přehledy a skutečný dokončený výrobní proces v testovacím
světě. `sawmill_operation_game_runner.tscn` ověřuje skutečnou běžnou nabídku
a mapu a bufferuje časově změřený úsek práce. Hráčovy savy se nepřepisují.
Podrobnosti a reprodukci oddělují [nativní protokol](native/README.md)
a [protokol běžné hry](natural/README.md).

## Skutečná dodávka a výrobní pohyb

Běžný průchod prošel skutečnou nabídku Nová hra a mapu Relief. Nosič
dodal kládu v ticku 234; pracovní snímek v ticku 237 má spotřebovanou
skladovou kládu a jeden kus na stolici. Tick 296 obsahuje dvě nová prkna
a návrat tesaře k odpočinku. Noční tick 3750 přerušil další skutečnou dávku:
1 volná kláda, 4 prkna, 1 rozpracovaná kláda, spící obyvatel a teplé okno.
Po izolovaném uložení a načtení odpovídají stejné skutečně načtené vrstvy.

Záznam práce při rychlosti 1× má 35 snímků během 3.503 s skutečného času
a 3.45 s simulace, všech šest pracovních pozic. Při přehrávání nebyly
ručně posouvány ticky ani komprimovány PNG; video zachovává změřené
rozestupy snímků. Pohyb je soustředěný do paže a pily, přibližně
3.5 world px zdvihu, tělo zůstává stabilní. Při vzdáleném zoomu je jemný;
bližší záběr umožňuje číst jednotlivé kusy i kontakt u stolice.

## Prostředí a identita důkazů

Godot 4.7.2, macOS, nativní OpenGL Compatibility / Apple M4.
[Nativní manifest](native/capture-manifest.json) vede 71 snímků:
12 množstevních, 6 stavových, 6 kontextových, 40 pracovního cyklu a 7
skutečné dávky v řízeném světě. Hashe 11 produkčních PNG a obou manifestů
jsou stejné před i po tomto běhu. [Finální hashe](final-asset-hashes.json)
a běžný report identifikují ustálené podklady; běžný report přidává hashe
dotčeného runtime. Základní `finished.png` se tímto doplněním nepřepsal.

Finální cílená sada prošla **20/20 bez okna i 20/20 nativně**.
Bezokenní pozitivní kontrola dokládá importované obrazy a alfu, nativní
navíc skutečné pixely hlavní scény. Kompletní **849/849** zahrnuje
regrese simulace, fog, save, výživy, terénu i starších objektů.
Původní `native-preflight/`, první kontaktní kompozice a dřívější
12/12 stavových testů zůstávají jasně označené jako předběžné důkazy.

Nové stavební PNG, příchodové/odchodové klipy uvnitř domu a distribuční
export nejsou touto revizí dodávány. Ověřuje se pracovní tah/vrat, fyzické
zásoby a jejich návaznost na existující domácí stavy. Výtvarné přijetí
finálních obrazů uživatelem ani společného etalonu se neodvozuje z testů.
