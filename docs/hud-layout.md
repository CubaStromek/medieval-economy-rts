# HUD layout, scaling and Czech names

Stav k **2026-09-12**. Tento dokument je závazný popis rámce HUD: rozměry,
škálování a vrstva českých názvů. Grafické kontrakty budov a jednotek popisují
vlastní dokumenty v `docs/art/`.

## 1. Rám obrazovky

Celý rám vychází z jedné sady konstant v `game/scripts/view/game_hud.gd`.
Kamera si čte `MAP_LEFT`, `MAP_TOP` a `MAP_BOTTOM`, takže změna konstanty
přerozdělí plochu mapy bez dalšího zásahu.

| Konstanta | Hodnota | Význam |
|---|---|---|
| `EDGE` | 12 | vnější okraj všech panelů |
| `DOCK_WIDTH` | 280 | šířka postranního panelu |
| `OVERVIEW_HEIGHT` | 56 | výška horní lišty |
| `STATUS_HEIGHT` | 40 | výška spodní lišty |
| `MAP_LEFT` | 304 | `EDGE + DOCK_WIDTH + EDGE` |
| `MAP_TOP` | 78 | `EDGE + OVERVIEW_HEIGHT + 10` |
| `STATUS_TOP` | 52 | odsazení spodní lišty od dolního okraje |
| `DOCK_BOTTOM` = `MAP_BOTTOM` | 62 | dolní hrana postranního panelu |
| `BUILD_FOOTER_HEIGHT` | 104 | vyhrazená patička seznamu staveb |

Rozmístění:

- **Horní lišta** — pět klíčových surovin a počet obyvatel/vojáků, vpravo
  přepínač **Vše**. Nemá herní branding; název hry nese titulek okna.
- **Postranní panel** — záložky **Stavět** / **Detail**. V režimu stavby jedna
  řada kategorií (Obec, Jídlo, Těžba, Armáda), pod ní rolovatelný seznam a dole
  pevná patička.
- **Spodní lišta** — čas a fáze dne, poslední událost, rychlost simulace,
  **Terén**, **Ovládání** a **Menu**. Proužek událostí je součástí této lišty,
  takže ho překryvné panely nemohou uříznout.
- **Překryvy** — panel zásob (pod horní lištou, vpravo od postranního panelu)
  a Ovládání (vpravo dole, nad spodní lištou). Otevření jednoho zavře druhý.

### Pravidla, která musí platit dál

1. **Výběr nástroje nesmí přeskládat seznam staveb.** Patička má konstantní
   výšku: jednořádkový název nástroje s elipsou, rolovatelná nápověda pevné
   výšky a slot tlačítka, který si drží rozměr i když je tlačítko skryté.
   Dřívější varianta přidávala řádky přímo do sloupce, takže seznam se pod
   kurzorem zmenšil zhruba na polovinu a rozpůlil poslední řádek.
2. **Panel zásob se přizpůsobuje otevřené kategorii.** `_fit_stock_panel()`
   měří mřížku dlaždic až po přepočtu rozvržení a nastaví `offset_bottom`;
   měřit obalový `ScrollContainer` nelze, sám žádné minimum nehlásí.
3. **Postranní panel musí nechat mapě alespoň tři čtvrtiny šířky.** Hlídají to
   `hud_layout_tests` i `window_layout_tests`.
4. **Panely se nepřekrývají s proužkem událostí.** Události patří do spodní
   lišty, ne do samostatného plovoucího panelu.

## 2. Škálování

`game/scripts/view/ui_scale.gd` drží celou politiku. Samotné nastavení
`canvas_items` + `expand` škáluje plátno poměrem `výška okna / 720`, takže
1080p zvětšilo celý HUD 1,5× a postranní panel si dál bral stejný podíl šířky.

HUD proto pohltí jen část přírůstku (`GROWTH = 0.45`, strop `MAX_FACTOR = 1.9`)
a zbytek se stane logickou plochou, kterou kamera utratí za mapu:

| Výška okna | Surové škálování | HUD | Podíl postranního panelu |
|---|---|---|---|
| 720 | 1,00× | 1,00× | ~24 % |
| 1080 | 1,50× | ~1,23× | ~18 % |
| 1440 | 2,00× | ~1,45× | ~16 % |
| 2160 | 3,00× | 1,90× (strop) | ~14 % |

Pod základní výškou se nic nepřepisuje; další zmenšování by text znečitelnilo.
Politiku aplikuje `game_session._configure_window()` a znovu při každé změně
velikosti okna. `SubViewport` v testech ji nedostává automaticky — testovací
i snímkovací runner si ji volají samy.

## 3. České názvy

`game/scripts/ui_text.gd` je sdílená tabulka jmen. Leží mimo `view/`, protože ji
potřebuje i simulace (`production_status`, protokol událostí), a vrstva kreslení
nesmí být závislostí simulace.

- Datový katalog si **ponechává anglické `display_name`**. Jsou to identifikátory,
  na které se odkazují savy, testy a dokumentace; překlad je čistě zobrazení.
- Neznámé id propadne na katalogový název, takže nově přidaná surovina zůstane
  vidět místo prázdného místa.
- **Počty se skloňují helperem.** Číslo nikdy nebere nominativ množného čísla
  z dlaždic zásob: `1 prkno`, `3 prkna`, `9 prken`. Čeština drží genitiv i nad
  dvacítkou (`22 obyvatel`), na rozdíl od polštiny nebo ruštiny.
- Stavy sytosti (`Fed`, `Hungry`, …) zůstávají v simulaci anglicky, kde se
  porovnávají a ukládají; překládá se až popisek.

## 4. Kontrola vzhledu

Automatická sada (`./tests/run-headless.sh`) pokrývá rozvržení, škálování,
jména i skloňování. Skutečné snímky HUD vyrobí runner s displejem:

```sh
godot --path game --scene res://tests/hud_layout_capture.tscn --resolution 1152x720
```

Zapíše do `.ui-review/` (mimo Git) klidový stav, panel zásob, Ovládání, režim
umísťování a detail budovy i jednotky ve třech rozlišeních. Runner mění jen
velikost okna, výběr, režim stavby a viditelnost panelů; nic nesimuluje.
