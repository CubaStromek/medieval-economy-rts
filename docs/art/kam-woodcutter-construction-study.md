# Výstavba dřevorubecké chatrče v datech KaM

Ověřeno **2026-09-10** z původní uživatelovy GOG instalace Knights and
Merchants 1.60. Výklad skládání masek vychází ze zdrojového kódu KaM Remake,
lokální revize `a3b3e5268e1475460e4561f9143df6f1a532e681`.
Jde o rozbor reference; nemění vlastní koncept chaty ani herní kód.

## Co je skutečně nakresleno

1. **Vymezení a příprava země:** Remake kreslí provazy kolem plánu,
   později obvodová prkna. Dělník srovnává jednotlivá pole. Tělo domu
   v této přípravné fázi ještě neroste.
2. **Roubené stěny, 12 stupňů masky:** postupně přibývají vodorovné
   klády v rozích a stěnách. Na konci první fáze stojí otevřená dřevěná
   stavba bez střechy, s rozdílně vysokými stěnami a otvorem pro vstup.
   V tomto konkrétním spritu není samostatná vysoká soustava lešení.
3. **Dokončení, 21 stupňů masky:** rozestavěný obraz postupně nahrazuje
   finální roubenka. Doplní se konečné stěny, zelená střecha, její horní
   části a drobné vybavení. Technický název `Stone` popisuje stavební
   etapu spotřebovávající kámen; neznamená, že se dům vizuálně změní ve
   zděnou budovu.
4. **Hotový dům:** kreslí se finální sprite. Herní zásoby, stavitelé,
   vlajky a další provozní prvky jsou samostatné vrstvy/stavy.

Přesné pořadí malovaných částí lze projít v lokálním
[přehledu osmi mezistavů](../../original_game_data/kam-reference-export/woodcutter-construction/construction-overview.png),
[všech 12 stupních konstrukce](../../original_game_data/kam-reference-export/woodcutter-construction/wood-all-steps.png)
a [všech 21 stupních dokončení](../../original_game_data/kam-reference-export/woodcutter-construction/stone-all-steps.png).
[Animovaná ukázka](../../original_game_data/kam-reference-export/woodcutter-construction/construction.gif)
má záměrně ilustrační tempo, nikoli změřenou délku stavby ve hře.

## Jak jsou fáze uloženy

Nejde o 33 samostatně namalovaných snímků. `houses.dat` odkazuje na
**dva barevné obrázky a dvě masky pořadí** v `houses.rx`.
Hodnota pixelu masky říká, ve kterém kroku se dané místo odkryje.
Proto stavba nemusí vznikat pouhým rovnoměrným odříznutím obrázku odspodu.

| Význam | Pole v DAT | RX ID, počítáno od 1 | Velikost | Původní pivot |
| --- | --- | ---: | --- | --- |
| Rozestavěná dřevěná konstrukce | `WoodPic` | 143 | 99 × 65 px | −45, −34 |
| Maska konstrukce, hodnoty 0–11 | `WoodPal` | 145 | 99 × 65 px | −45, −34 |
| Dokončená chatrč | `StonePic` | 142 | 124 × 91 px | −62, −60 |
| Maska dokončení, hodnoty 0–20 | `StonePal` | 144 | 124 × 91 px | −62, −60 |

V DAT jsou identifikátory o jedna menší. Dřevorubec je záznam s indexem 9,
na offsetu 17 292 B; záznam má 1 688 B a tabulce předchází 2 100 B animací
zvířat. Ověřeny hodnoty `WoodPicSteps=12`, `StonePicSteps=21` a stavební
náklady **3 prkna + 2 kameny**.

Remake převádí hodnotu masky `k` na `255 − round(k / počet_kroků × 255)`
a kreslí pixely nad prahem `1 − průběh`. Během dokončování zároveň
vyřízne dřevěný podklad v místech odkryté finální masky, aby se vrstvy
a jejich stíny nesčítaly. Po úplném dokončení použije jen finální obrázek.

Maskové stupně nejsou totéž co údery kladivem. V uvedené revizi Remaku
kus materiálu poskytne 50 bodů práce, úder přidá 5. Tato chata tedy má
30 zásahů v první etapě a 20 ve druhé, bez přípravy terénu a dopravy.
Etapy odpovídají 60 % a 40 % této stavební práce. Procenta v obrazovém
přehledu jsou vždy **uvnitř příslušné etapy**, ne z celkové stavby.

Dodaný nevyužitý materiál se vykresluje zvlášť podle skutečného množství
a kotev `BuildSupply`. Prkna používají RX ID 260–265, kameny 267–272.
Obvodová prkna staveniště mizí při zahájení druhé etapy.

## Původ a ověření výstupu

Export zůstává v ignorovaném `original_game_data/kam-reference-export/woodcutter-construction/`.
Obsahuje nezměněné indexované vrstvy, všech 33 maskových mezistavů,
přehledy, GIF, opakovatelný exportér a `manifest.json` s původními cestami,
SHA-256, rozměry, pivoty a přesnými hodnotami.

Ověřeno přečtení všech 2 000 slotů RX až na konec souboru, shoda původních
indexovaných pixelů po exportu a nezměněné kontrolní součty vstupů.
Nezávislá kontrola porovnala všech 33 mezistavů s původními indexy a maskami:
všech 33 souhlasí pixel po pixelu, jsou navzájem odlišné a jejich SHA-256
odpovídají manifestu. Poslední konstrukční a dokončovací mezistav přesně
odpovídají celým původním obrázkům. GIF obsahuje 33 snímků.
Obrazový přehled byl vizuálně prohlédnut.

**Náhled je rekonstrukce z originálních spritů a masek, nikoli screenshot
ze hry.** Zachovává původní paletu a šachovnicové rastrování stínů.
Nezahrnuje terén, obvod staveniště, zásoby stavebnin, stavitele ani provozní
vrstvy; neprovádí novější změkčení stínů a rozšiřování masek z Remaku.
Původní bitmapy zůstávají jen lokální referencí, nejsou vlastní produkční
grafikou ani schválením stylu našeho domu.

## Zdrojové doklady

- [Struktura houses.dat](../../reference/kam_remake/src/res/KM_ResHouses.pas#L23)
  a načítání záznamů kolem řádku 901.
- [Interpretace masek](../../reference/kam_remake/src/res/KM_ResSpritesEdit.pas#L102),
  `AdjoinHouseMasks` kolem řádku 403.
- [Vykreslení domu](../../reference/kam_remake/src/render/KM_RenderPool.pas#L795),
  `RenderSpriteAlphaTest` kolem řádku 1247, skládání kolem řádku 2165,
  stavební zásoby kolem řádku 716.
- [Průběh stavby](../../reference/kam_remake/src/houses/KM_Houses.pas#L1234),
  výpočet obrazového průběhu kolem řádku 2403.
- [Příprava terénu a odstranění obvodu](../../reference/kam_remake/src/units/tasks/KM_UnitTaskBuild.pas#L723),
  odstranění obvodu kolem řádku 875.
- [Obvodové grafické prvky](../../reference/kam_remake/src/render/KM_RenderTerrain.pas#L1352).
- [Oficiální vysvětlení vztahu Remaku k původním datům](https://www.kamremake.com/about/):
  nový engine využívá řadu původních herních souborů; popis Remaku nelze
  bez dalšího vydávat za rozbor původního spustitelného programu.
