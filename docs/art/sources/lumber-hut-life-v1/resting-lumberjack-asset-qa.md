# Odpočívající dřevorubec — výrobní kontrola

Datum: **2026-09-12**. Rozsah: jedna samostatná klidová póza pro denní
přítomnost u chatrče. Nejde o nový osmisměrný klip. Tento záznam doplňuje
integrační a herní QA chatrče; nepotvrzuje jejich dosud neprovedené části.
Struktura kontroly vychází z [projektové QA šablony](../../object-qa-template.md)
a [společného postupu](../../object-implementation-workflow.md).

## 1. Zadání, reference a soubory

Identita navazuje na vlastní master
`docs/art/animation-references/lumberjack-without-log/S.png` a současnou
PixelLab referenci `package/references/walk_axe/SE.png`. Vlastní dokončená
chatrč sloužila jen jako reference světla/kamery. Cizí obrázek nebyl vstupem.
Přesná zadání a lokální původ všech tří výstupů jsou v
[provenienci](resting-lumberjack-prompts.json).

Výtvarná výroba: vestavěný `image_gen`; konkrétní model odpověď nástroje
neuvedla. První dva RGB výstupy byly odmítnuty kvůli namalované šachovnici.
První navíc měla sekeru na nesprávném boku. Vybraný třetí vlastní obrázek
je bez sekery a s technickým purpurovým pozadím. Projektový workflow §4
tuto cestu připouští; finální průhlednost je naměřený export, ne tvrzení promptu.

Produkce: [resting_lumberjack.png](../../../../game/art/buildings/lumber_hut/v1/life/resting_lumberjack.png).
Registrace a otisky: [resting_lumberjack.json](../../../../game/art/buildings/lumber_hut/v1/life/resting_lumberjack.json).
Reprodukovatelný technický export: [export-resting-lumberjack.cjs](export-resting-lumberjack.cjs),
Node + Sharp. Nástroj pouze vyváží alfu, mění rozlišení a registruje celé plátno;
nekreslí ani neposouvá části postavy. Původní obrázky jsou zachované.

## 2. Naměřená geometrie

| Veličina | Skutečný výsledek |
|---|---|
| Zdrojové plátno | 1145 × 1374 px, RGB |
| RGBA master, alfa > 25 | [350,49,793,1314], pravá/dolní mez výlučná |
| Produkční plátno | 256 × 256 px, RGBA |
| Produkční obal, alfa > 25 | [94,42,152,206], pravá/dolní mez výlučná |
| Produkční obal, alfa > 127 | [95,43,151,205], pravá/dolní mez výlučná |
| Nulové / částečné / plné pixely alfy | 59 591 / 1 326 / 4 619 |
| Registrace hlavní podrážky | Autorsky vybraný bod zdroje (614,1312), po převodu (128,47;205,23) |
| Čepice → hlavní podrážka | 1263 zdrojových px; 162,71 produkčních px |
| Doporučené herní měřítko | 33 world px / 162,71 px = 0,202815; herní kalibrace je součást integrace |
| Ořez | (346,45), rozměr 451 × 1273 px; celý zdroj je zachován |
| Zmenšení a umístění | 58 × 164 px, levý horní roh (94,42) na 256² |

Kontakt nohy je samostatný od hloubkového řazení a stínu. Mapa, kolize,
sort anchor a stín se tímto výrobním exportem nemění ani neurčují.

## 3. Alfa a provedená obrazová kontrola

**Prošlo v rozsahu samostatného obrázku.** Skutečný modalní klíč je RGB
(251,3,250), nikoli zadané ideální (255,0,255). Prázdné zóny mají naměřenou
purpurovou dominanci 204–251; vybrané vnitřní oblasti postavy −103 až 0.
Export odstraňuje dominanci ≥ 196 a hrany odmatuje proti změřenému klíči.
Tyto hodnoty byly měřeny na tomto konkrétním obrázku.

[Karta průhlednosti](resting-lumberjack-alpha-qa.png) byla skutečně
prohlédnuta na světlém, tmavém a zeleném pozadí. Póza drží čepici, vousy,
olivovou tuniku, světlé rukávy, koženou zástěru a obě boty. Ruce jsou
založené a prázdné, sekera ani kláda nejsou přítomné. Levá noha je ohnutá,
pravá nese váhu; mírné natočení k pravé straně obrazu. Žádná stěna, zem,
předmět nebo upečený stín není součástí vrstvy.

Nezávislé pixelové vzorky produkce: vnější (0,0) alfa 0; otvor mezi nohama
(129,147) alfa 0; vnitřní světlý rukáv (123,83) alfa 255; podrážka (128,204)
alfa 255; pod botou (127,206) alfa 0. Vnitřní otvor je tak ověřen samostatně
od nulových rohů; není jen zkontrolována existence alfa kanálu.

## 4. Co tato kontrola nepokrývá

Nativní import, usazení u zdi, zemní kontakt ve hře, světlost ve dne/noci,
zobrazení podle skutečné fyzické přítomnosti, mlha, výběr a uložení/načtení
patří do navazujícího QA integrace chatrče. Samotná karta je nedokazuje.
Další směry a animace jsou N/A: tento požadavek dodává jedinou klidovou pózu.

## 5. Výsledek

Technický asset: **hotový a ověřený** ve výše uvedeném rozsahu.
Vizuálně použitelná samostatná póza; dojem opření musí potvrdit umístění
proti fasádě v normální hře. Explicitní uživatelské přijetí této kresby
ani schválení společného výtvarného etalonu zatím uděleno nebylo.
