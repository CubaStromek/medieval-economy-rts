# Animace jednotek v KaM Remake — ověřené poznatky

Datum: **2026-09-09**. Podnět: uživatel zamítl náš první generovaný cyklus
dřevorubce bez klády. Tato studie popisuje referenční techniku; neschvaluje
novou grafiku ani nemění herní renderer.

Zkoumaný zdroj: lokální `reference/kam_remake`, commit
`a3b3e5268e1475460e4561f9143df6f1a532e681`.

## Co engine přehrává

KaM Remake používá původní grafické podklady v novém enginu, jak popisuje
[oficiální stránka projektu](https://www.kamremake.com/about/).
Jednotky vykresluje jako připravené 2D snímky. Animaci vybírá podle typu
jednotky, činnosti, jednoho z osmi směrů a fáze cyklu.

V `data/defines/interp.dat` byly nezávisle ověřeny záznamy `utWoodcutter`
pro `uaWalk`, `uaWalkTool`, `uaWalkBooty` a `uaWalkTool2`:

- Každá z těchto činností má ve všech osmi směrech **8 aktivních základních fází**.
- Každá fáze má **8 kladných identifikátorů snímků** v interpolační tabulce.
- Zbylých 22 rezervovaných fází každého směru obsahuje pouze `-1`.
- Jedna základní osmisměrná sada tedy představuje 8 × 8 = **64 fází**.
  Nejde o počet snímků celé postavy se všemi pracovními animacemi.

Kontrola struktury: dvoubajtová délka ANSI značky `UnitAction`, data od
bajtu 12, pole 36 jednotek × 13 činností × 8 směrů × 30 rezervovaných fází
× 8 podfází × 4 bajty. Na očekávaném offsetu 3 594 252 byla ověřena další
značka `SerfCarry `. První položka podfází odpovídá původnímu snímku;
další odkazují na předpočítané mezisnímky.

Zdroj schématu a přehrávání:
[KM_ResInterpolation.pas](../../reference/kam_remake/src/res/KM_ResInterpolation.pas),
[KM_Defaults.pas](../../reference/kam_remake/src/common/KM_Defaults.pas),
[AnimInterpForm.pas](../../reference/kam_remake/Utils/AnimInterp/AnimInterpForm.pas).
Počet osmi základních fází je ověřen pro uvedené záznamy dřevorubce;
není univerzálním limitem všech animací.

## Jak Remake získává větší plynulost

Lewinův [popis výrobního postupu](<../../reference/kam_remake/Docs/Misc/Interpolater Graphics creating workflow.txt>)
uvádí tento sled:

1. Exportovat dva sousední, již existující snímky animace.
2. Pomocí Dain-App vytvořit **sedm mezisnímků** mezi nimi.
3. Znovu spojit samostatně zpracované stíny a barvy hráče.
4. Uložit výsledné PNG a jejich mapování do `interp.dat`.

Nástroj `AnimInterp` páruje také poslední fázi s první. Při přehrávání engine
vybere původní nebo předpočítaný snímek podle průběhu fáze. Při vypnuté
interpolaci nebo chybějícím záznamu použije původní snímek.
Jde o vyhlazení existujícího cyklu: správné střídání nohou musí obsahovat
již jeho základní pózy. Runtime neanimuje 3D kostru postavy.

## Umístění a časování

Každý snímek má uloženou kotvu (pivot), podle které se umístí vůči herní
pozici. Renderer pracuje také se stabilním referenčním snímkem pro výšku
řazení. Nevypočítává nové měřítko postavy podle ořezu každé fáze.

`KM_UnitActionWalkTo.pas` posouvá jednotku po cestě a současně zvyšuje její
animační krok. `KM_UnitVisual.pas` vyhlazuje zobrazovanou pozici mezi kroky
simulace a řeší návaznost fáze při zahájení pohybu i změně směru/činnosti.
Samotné automatické pohupování statického obrázku tuto informaci nenahrazuje.

Zdroj:
[vykreslení](../../reference/kam_remake/src/render/KM_RenderPool.pas),
[pohyb po cestě](../../reference/kam_remake/src/units/actions/KM_UnitActionWalkTo.pas),
[vizuální návaznost](../../reference/kam_remake/src/units/KM_UnitVisual.pas).

## Co je známo o výrobě původních obrázků

[Oficiální modding návod](https://github.com/reyandme/kam_remake/wiki/Modding-graphics)
popisuje export jednotlivých PNG přes F11 → Export Data → Resources → Units,
jejich identifikátory, pivoty a oddělené masky. Krom v
[článku z roku 2014](https://www.knightsprovince.com/2014/03/so-writing-a-new-game/)
uvádí přibližně 300–500 spritů pro kompletní novou jednotku včetně různých
činností a směrů.

Tyto zdroje **nedokládají**, že všechny původní jednotky vznikly ruční kresbou,
ani že všechny vznikly renderováním 3D modelů. DAIN popisuje pozdější
vyhlazování animací Remaku, nikoli původní výrobu základních póz.
Lokální reference obsahovala zdrojový kód a interpolační tabulku; originální
bitmapy jednotek zde nebyly nalezeny. Studie proto neobsahuje vizuální
kontrolu původního cyklu snímek po snímku.

## Poučení pro náš dřevorubec

První generované archy neudržely potřebné střídání opěrných nohou a návaznost
póz. Přerovnání snímků, registrace nebo přidání mezisnímků takový základ
neopraví. Výsledek v1 je zamítnutý a nesmí se integrovat.

Doporučený další postup pro naše vlastní podklady:

1. Nejprve vytvořit a posoudit **jeden směr** se správným celým cyklem:
   kontakt, pokles, průchod, vzestup a totéž pro opačnou nohu.
2. Udržet neměnnou postavu, proporce, kameru, pravou ruku se sekerou a kotvu;
   kontrolovat i spojení poslední fáze s první při malé herní velikosti.
3. Teprve po přijetí cyklu vyrobit ostatní směry a případné mezisnímky.
4. Pro opakovatelnost zvážit jeden rigovaný 3D model a render osmi směrů,
   případně řízenou 2D animaci. **To je naše výrobní doporučení, nikoli
   historicky doložená metoda původního KaM.**

Výroba další sady ani integrace nebyla touto studií zahájena.

Aktualizace **2026-09-10**: původní hra z uživatelovy knihovny GOG je nyní
lokálně instalována a originální `units.rx` je dostupný pro rozbor.
Dokončení instalace Remaku a rozdíly exportu ve starší revizi r6720 sleduje
[lokální instalační záznam](kam-local-reference-setup.md).

Následný [audit celé původní sady dřevorubce](kam-lumberjack-animation-audit.md)
ověřuje i skutečné bitmapy, skládání vrstev, kácení, kládu, sazenice
a zvláštní varianty hostince. Obsahuje přesné počty a lokální export.
