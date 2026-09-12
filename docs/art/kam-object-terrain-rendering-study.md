# KaM: poloha objektů, terén a pořadí překrývání

Ověřeno **2026-09-10** v lokálním zdrojovém kódu **KaM Remake**,
revize `a3b3e5268e1475460e4561f9143df6f1a532e681`. Jde o doložené chování
Remaku používajícího původní grafická data; není to rozbor původního
spustitelného programu Knights and Merchants 1.60.

## Tři různé významy „výšky“

1. **Posun podle skutečného terénu.** Poloha domu na obrazovce odečítá
   `RenderHeight / CELL_HEIGHT_DIV`. Pole má 40 px a dělitel je 33.333.
   Při standardním 2D vykreslení se tím obraz domu posune vzhůru společně
   s vyvýšenou zemí. Nejde o volitelný bonus typu „dům levituje o 20 px“.
2. **Pixelový pivot konkrétní kresby.** RX data obsahují posunutí obrázku
   vůči mapové kotvě. Do polohy vstupuje také výška samotného obrázku,
   protože renderer zadává jeho spodní levý roh a kreslí od něj nahoru.
3. **Samostatný bod `Feet` pro řazení objektů.** `Loc` je poloha kresby;
   `Feet.Y` je pořadí překrývání. U budovy se `Feet.Y` odvozuje od spodního
   okraje obou stavebních spritů a má ještě posun o půl políčka vzhledem
   k tomuto okraji. Tento pomocný bod je stabilní po celou výstavbu;
   **neposouvá kresbu ani dveře** a není skutečnou výškou objektu nad zemí.

## Přesná registrace domu

`KM_RenderPool.pas`, `AddHouse`, řádky 767–792:

```text
CornerX = mapX + pivotX / 40 - 1
CornerY = mapY + (pivotY + imageHeight) / 40 - 1
          - terrainRenderHeight / 33.333

FeetY = mapY + max(woodPivotY + woodHeight,
                   finishedPivotY + finishedHeight) / 40 - 1.5
```

`CornerY` je spodní roh obrázku. Jeho horní roh při kreslení odečítá
`imageHeight / 40`. Rozdíl `−1` versus `−1.5` tedy znamená posun bodu
řazení o **půl políčka**, ne dodatečné zvednutí domu o půl políčka.
Pozici domu podle terénu určuje `LandExt[mapY+1,mapX].RenderHeight`.
Jednotky a stromy používají obdobně interpolovanou výšku v místě pohybu.

V původních datech dřevorubce mají obě kresby stejný spodní okraj vůči
pivotu: hotová `−60 + 91 = 31 px`, konstrukční `−34 + 65 = 31 px`.
Proto se jeho bod řazení při přepnutí fáze nezmění. Nejde o horní hranu
střechy, průběžný neprůhledný ořez rostoucí stavby ani o odhad podle dveří.

## Pořadí průchodů rendereru

`KM_RenderPool.Render`, řádky 304–354:

1. Vykreslí se **celý terén**. Z-test je zde zapnutý kvůli správnému
   překrytí terénních pruhů a jejich světla/stínů.
2. Z-test se vypne. Přidají se terénní plány, obvody a pozadí výběru.
3. Budovy, stromy, jednotky a projektily vytvoří společný seznam.
4. Samostatné objekty se seřadí podle `Feet.Y`; jejich podvrstvy (např.
   dokončovaná vrstva domu a zboží) se vykreslí společně za rodičem.
5. Mlha se vykreslí nad objekty.

Terén sice má pomocné hodnoty Z (`tY−1`) pro své pruhy, ale tento Z-test
se **nepoužívá k zakrývání budov trávou**. Konstrukční stencil zase
určuje odkrývání 12/21 masek, nikoli prostorovou výšku budovy.

## Důsledek pro naši chybu

Naše `main_view.gd` prokládá terénní řádky (`2×row`) a objektové řádky
(`2×row+1`). Nová bitmapa byla zařazena podle uložené mapové kotvy domu,
přestože její viditelný předek sahá dále dolů než práh. Následující
terénní řádek tak přemaloval spodní část obrázku i na rovině.

První nativní QA tento problém přímo ukázalo. Předčasný závěr, že je
potřeba přesunout dvorek a prodloužit stěny domu, nebyl úplnou diagnózou:
nejprve je nutné oddělit mapovou kotvu, práh a stabilní bod pro řazení.
Půdorys, výšková simulace a umístění dveří se kvůli tomu nemění.

Pro naši stávající práci s kopci je možné použít stejný princip vlastního
bodu řazení bez plošného převzetí všech průchodů Remaku. Konkrétní
implementaci a skutečné vizuální ověření vede brief stavební sady;
tato studie sama o sobě není dokladem vyřešení chyby ve hře.

## Zdrojové soubory

- `reference/kam_remake/src/render/KM_RenderPool.pas`: 304–354 průchody,
  767–792 dům, 1052–1054 jednotka, 1218–1222 kreslení, 1997–2031 řazení,
  2100–2106 rozdíl `Loc`/`Feet`, 2137–2142 podvrstvy.
- `reference/kam_remake/src/common/KM_Defaults.pas`: 9–10 velikost pole
  a výškový dělitel.
- `reference/kam_remake/src/terrain/KM_Terrain.pas`: 5131–5144 výšková projekce.
- `reference/kam_remake/src/render/KM_RenderTerrain.pas`: 961–964 pomocné Z terénu.
- `game/scripts/view/main_view.gd`: `_world_draw_entries`, `_draw`,
  `_sync_dynamic_rows`; `game/scripts/view/terrain_renderer.gd`: `point_occluded`.
