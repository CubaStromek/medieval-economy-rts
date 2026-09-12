# Lokální podklady KaM a instalace na Macu

Stav k **2026-09-10**. Účel: získat původní animační fáze jako pohybovou
referenci pro vlastní grafiku dřevorubce. Nejde o schválení ani integraci
původní grafiky do naší hry.

## Ověřený stav instalace

- Uživatel vlastní Knights and Merchants v knihovně GOG. Byl stažen jeho
  offline Windows instalátor 1.60 (67017); nový nákup nebyl potřeba.
- Nainstalován Sikarugir Creator 1.0.1 a vytvořen wrapper
  `/Users/openclaw/Applications/Sikarugir/KaM Remake.app`, šablona 1.0.15,
  engine WS12WineCX24.0.7_7.
- Původní hra je instalována uvnitř wrapperu v
  `Contents/SharedSupport/prefix/drive_c/GOGGames/KnightsAndMerchants`.
  Instalátor skončil s kódem 0 a záznamem `Installation process succeeded`;
  ověřena přítomnost `KM_TPR.exe` a `data/gfx/res/units.rx`.
- OpenAL z oficiálního webu je nainstalován ve stejném prostředí. Instalátor
  skončil s kódem 0; ověřena přítomnost `windows/syswow64/OpenAL32.dll`.
- **KaM Remake r6720 je nainstalován a spuštění potvrzeno.** Uživatel
  dokončil běžné stažení oficiálního instalátoru. Instalace skončila s kódem
  0; wrapper otevírá `/KaMRemake/KaM_Remake.exe`. Nastavena čeština, režim
  okna a vypnutá hudba. Uživatel dne 2026-09-10 potvrdil „hra bezi“.
  Log navíc potvrzuje inicializaci hlavního menu, OpenAL a vykreslování
  přes Apple M4; klientské okno má 1024 × 768 px.

Podrobný lokální záznam s cestami a kontrolními součty je v ignorovaném
`original_game_data/kam-mac-installation.json`. Originální data zůstávají
v instalované aplikaci nebo v ignorovaném `original_game_data/`.

## Vyexportovaná pohybová reference

Přímým bezeztrátovým čtením originálních `units.rx`, `unit.dat` a `pal0.bbm`
bylo získáno **8 fází dřevorubce SE se sekerou, bez klády**. Výstup je v
`original_game_data/kam-reference-export/lumberjack-SE-with-axe-no-log/`:
`frames/00.png` až `07.png`, přehled `contact-sheet-6x.png`, původní indexované
vrstvy s pivoty v `raw-layers/` a úplný původ dat v `metadata.json`.

Postava se skládá z těla (RX ID 2228–2235) a překryvu ruky se sekerou
(3435–3442). Společné plátno má 36 × 46 px a pevnou vykreslovací kotvu
[16, 39]. Pořadí fází pochází z původní tabulky; rychlost přehrávání zde
nebyla odhadována. Barvy hráče ani původní šachovnicový stín nebyly
převáděny do vzhledu Remaku.

Ověřeno úplné přečtení RX, shoda indexů pixelů a palety po opětovném načtení
PNG a nezměněné kontrolní součty zdrojových souborů. Přehled byl také
vizuálně zkontrolován. Tento přímý export není ověřením spuštění Remaku.

## Nastavení Remaku r6720

Byl použit plný instalátor z [oficiální stránky](https://www.kamremake.com/download/)
a stejné prostředí, ve kterém je skutečně instalována původní hra.
Před prvním spuštěním byl vedle `KaM_Remake.exe` nastaven
soubor `KaM_Remake_Settings.ini`:

```ini
[Game]
Locale=cze

[GFX]
FullScreen=0

[SFX]
MusicDisabled=1
MusicVolume=0
```

Zvukové efekty ponechat beze změny. Klíče byly ověřeny ve skutečném
[zdroji r6720](https://github.com/Kromster80/kam_remake/blob/ecd9718c24890b216d68d580efc9a14c420a345a/src/KM_Settings.pas#L294).
Novější lokální zdroj používá odlišný formát nastavení; nepřenášet jej
automaticky do této starší verze.

Pro export dřevorubce v r6720 použít **F11 → Export Data → Resources → Units.rx**.
Výstup do `Export/Units.rx/` obsahuje PNG, masky a soubory pivotů.
Položka **Unit Anim v r6720 exportuje jen vojáky**, nikoli dřevorubce.
Viz [export spritů](https://github.com/Kromster80/kam_remake/blob/ecd9718c24890b216d68d580efc9a14c420a345a/src/res/KM_ResSprites.pas#L381)
a [výběr jednotek](https://github.com/Kromster80/kam_remake/blob/ecd9718c24890b216d68d580efc9a14c420a345a/src/res/KM_Resource.pas#L242).

## Zdroje prostředí

- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir)
- [Mac/Linux postup KaM Remake](https://www.kamremake.com/mac-osx-and-linux/)
- [OpenAL](https://www.openal.org/downloads/)

Spuštění a načtení hlavního menu jsou potvrzené. Delší hraní ani export
přes menu F11 zatím nebyly testovány; osm referenčních fází bylo získáno
přímým čtením původních dat popsaným výše.
