# Pro editace — nezávislé pozorování prvních výstupů

Datum: **2026-09-10**. Kontroloval agent `walk_preview`.
Skutečně prohlédnuty všechny tři uvedené `images/frame_00.png` v nativním
rozlišení. Jde o pozorování pracovních referencí, **nikoli přijetí assetů,
animace nebo herní integrace**. Žádný obrázek ani prompt nebyl při této
kontrole upravován a žádná data nebyla odeslána do API.

## Naměřené soubory

Všechny výstupy mají canvas 256 × 256 px, viditelný obsah a skutečnou
alfu. Meze jsou při alfa > 0; pravá/dolní hrana výlučná. Počet barev
je počet různých RGBA hodnot pouze u viditelných pixelů. Vznikl měřením
Pillow po dekódování skutečného PNG, nikoli z promptu.

| Soubor | Alfa obal | Viditelné RGBA barvy | Alfa pixely na horní / levé hraně |
|---|---|---:|---:|
| [log-S-pro-v2](log-S-pro-v2/images/frame_00.png) | [0, 0, 93, 190] | 98 | 7 / 6 |
| [chop-S-pro-v2](chop-S-pro-v2/images/frame_00.png) | [0, 0, 114, 162] | 92 | 6 / 5 |
| [axe-low-E-pro](axe-low-E-pro/images/frame_00.png) | [100, 47, 171, 201] | 3914 | 0 / 0 |

Pravá/dolní hrana má u všech tří nulový počet viditelných alfa pixelů.
Původ vstupů podle skutečných `provenance.json`: log/chop použily RGB
`inputs/S-reference-256.png` (`png_color_type:2`); E použilo RGBA
`direction-inputs/walk_axe/E.png` (`png_color_type:6`).

SHA256 přesně prohlédnutých PNG:

- log: `23a29dffed78bbe5955debe8a716c9a2cf54169c93b5d0045e02d625ca33f955`
- chop: `dde7d62e419c17b38988fa7a1e3a47a24b98548aaf3ee7461a4926e20eace22d`
- E: `e69e7f5f853c6eaa91056b5bf0033d3aef9ab8b35530ca03b7ee34e0816608b2`

## Kláda — lepší nosná póza, chybný bok sekery

Kláda už směřuje podélně od předního kruhového řezu dozadu přes
anatomické pravé rameno. Nepůsobí jako příčná tyč přes obě ramena.
Pravá paže podpírá přední část; levá paže na obrazové pravé straně
zůstává volně dole. Jde o podstatný rozdíl proti předchozímu odmítnutému
příčnému návrhu.

**Sekera je však zavěšena na obrazové levé straně u boku**, tedy na
anatomické pravé straně stejně jako kláda. Požadovaný anatomický levý
bok odpovídá v tomto čelním pohledu obrazové pravé straně. Tato konkrétní
vada má být opravena; přítomnost jedné sekery sama nesplňuje kontrakt.

Celá kresba se přesunula do levého horního rohu původního canvas a
kláda se dotýká jeho hran. Původní společná registrace není zachována.
Přítomnost alfa pixelů na hraně dokládá chybějící rezervu, ale bez
neomezeného zdroje sama neprokazuje, kolik kresby případně chybí.

## Sekání — platný obouruční úchop, změněná registrace

Obě ruce obepínají **jedno souvislé topůrko**, které vede k jediné
kovové hlavě sekery. Paže a úchopy v této statické póze působí čitelně.
Nebylo požadováno ani tvrzeno uživatelské schválení konkrétního pořadí
pravé/levé ruky na topůrku.

Koruna čepice a levá část paže se však dostaly až k hraně canvas.
Kresba je v levém horním rohu a neudržela polohu původní postavy.
Dotyk s hranou vyžaduje kontrolu možného ořezu; nelze to vydávat za
ověřenou plnou rezervu pro následný rozmach. Z této jedné pózy také
nevyplývá správný zásah, návrat ani úplná animační smyčka.

## Východní chůzová reference

E si ponechává postavu uvnitř původního canvas s rezervami na všech
hranách. Sekera je držena nízko pravou rukou a je přítomna jedna čepel
i jedno topůrko. Výrazně bohatší barevná gradace odpovídá vizuálně
jemnějšímu výsledku než u dvojice log/chop. Konkrétní počet barev však
není sám o sobě měřítkem umělecké kvality nebo přijetí animace.

## Co lze a nelze uzavřít

Rozdíl RGB vstupu oproti RGBA vstupu **koreluje** s pozorovaným posunem
a výrazným omezením palety. Tento malý nesrovnatelný vzorek ale
**neprokazuje příčinu** uvnitř služby; liší se i obsah editací. Další
pokusy s RGBA odvozeným S mohou hypotézu prověřit. Tento záznam jim
nepřisuzuje dopředu správné výsledky.

Log vyžaduje opravu boku sekery a registrace, chop registrace/hraniční
rezervy. Vizuální přijetí těchto referencí a herní QA zůstávají
**neudělené / neprovedené**.
