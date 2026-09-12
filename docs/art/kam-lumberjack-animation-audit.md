# Původní animační sada dřevorubce

Ověřeno **2026-09-10** z uživatelovy instalace GOG Knights and Merchants
1.60 a ze zdrojového kódu KaM Remake r6720. Jde o pohybovou referenci;
vlastní grafika ani integrace do naší hry tím nevznikla.

## Obsah skutečných dat

| Činnost | Fáze na variantu | Varianty | Složení |
| --- | ---: | --- | --- |
| Obyčejná chůze | 8 | 8 směrů | tělo + výchozí paže |
| Chůze se sekerou bez klády | 8 | 8 směrů | tělo + ruce a sekera |
| Chůze s kládou | 8 | 8 směrů | tělo + ruce a náklad |
| Chůze se sazenicí | 8 | 8 směrů | tělo + ruce a sazenice |
| Kácení stromu | 10 | NE, SE, SW, NW | celé pracovní snímky |
| Sázení stromku | 8 | jediná orientace N | celé pracovní snímky |
| Jídlo a pití v hostinci | 30 časových slotů | 4 jídla × 2 strany stolu | sedící horní část postavy |
| Úmrtí | 14–18 | 8 směrových slotů | jednorázová sekvence |

Jídlo má opakované obrázky ve 30 časových slotech. Jeho osm položek není
osm kompasových natočení: víno, chléb, uzeniny a ryba mají vždy přední
a zadní pohled. Úmrtí má počty N/NE 16, E/SE 14, S/SW 15 a W/NW 18.

Původní tabulka obsahuje 14 akcí × 8 slotů. Šest akcí je neaktivních;
záznam `Count=1` se snímkem `-1` neznamená skutečný jednosnímkový pohyb.
Samostatná akce paží po složení duplikuje obyčejnou chůzi a některé její
fáze jsou záměrně prázdné. Tělo se v nich dále vykresluje.

## Co bylo ověřeno

- Bezeztrátově vyexportováno 451 původních spritů a 734 sestavených
  časových slotů včetně opakování a duplicitní obyčejné chůze.
- Zachovány indexy palety, průhlednost, původní pořadí a kotvy vrstev.
  Načtení RX došlo přesně na konec souboru; zdrojové soubory se nezměnily.
- Všech 734 cest, rozměrů a kontrolních součtů prošlo kontrolou.
  Osm dříve exportovaných SE fází se sekerou odpovídá pixel po pixelu.
- Vizuálně prohlédnuty přehledy, návrat s kládou ve všech směrech a všech
  deset fází kácení SE. Ověřeno přehrávání a krokování interaktivního
  náhledu, změna činnosti a rozložení při šířkách 736 a 360 px.

Skládání do náhledu nemění kresbu. Šachovnicová pole barvy hráče a stínu
zůstala v původní podobě `pal0.bbm`; nejsou to vady póz. Náhled používá
nastavitelnou rychlost, výchozí 10 sn./s, bez generovaných mezisnímků.
Toto tempo odpovídá výchozímu hernímu ticku 100 ms při rychlosti 1×;
náhled nesimuluje přesun po mapě, přerušení úkolu ani rychlost celé hry.

## Podstatné pro vlastní animaci

Chůze používá společný cyklus těla a mění vrstvy paží, nástroje či nákladu.
Nejde tedy o sadu nezávisle nakreslených celých postav pro každou činnost.
V SE kácení je čitelný nápřah, švih dolů, několik spodních poloh
a návrat do nápřahu. Tyto fáze dávají konkrétní předlohu pro rytmus a
držení nástroje.

Pro první vlastní směr už máme přesné pózy, jejich pořadí a vzájemné
umístění. Nová kresba musí navíc udržet vlastní proporce a objem postavy
mezi snímky; samotné zvětšení nebo přebarvení originálu to neřeší.

## Lokální výstup a důkazy

Kompletní export je v ignorovaném
`original_game_data/kam-reference-export/lumberjack-full-set/`:
`manifest.json`, `raw-layers/`, `frames/`, `contact-sheets/`,
`chop-SE-all-10-review.png` a `preview-validation.json`.
Opakovatelný exportér je ve stejném adresáři jako `export_full_set.py`.
Manifest obsahuje zdrojové cesty, SHA-256, původní identifikátory,
pivoty a význam jednotlivých slotů. Práva k původní kresbě zůstávají
jejím vlastníkům; původní assety nejsou součástí produkční grafiky projektu.

Zdrojové důkazy r6720:
[skládání vrstev](https://github.com/Kromster80/kam_remake/blob/ecd9718c24890b216d68d580efc9a14c420a345a/src/units/KM_Units.pas#L319),
[pracovní činnosti](https://github.com/Kromster80/kam_remake/blob/ecd9718c24890b216d68d580efc9a14c420a345a/src/units/KM_Units_WorkPlan.pas#L236),
[hostinec](https://github.com/Kromster80/kam_remake/blob/ecd9718c24890b216d68d580efc9a14c420a345a/src/houses/KM_HouseInn.pas#L112),
[herní časovač](https://github.com/Kromster80/kam_remake/blob/ecd9718c24890b216d68d580efc9a14c420a345a/src/KM_Game.pas#L1097).
