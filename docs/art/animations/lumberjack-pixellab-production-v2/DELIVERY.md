# Dřevorubec · PixelLab v2

Dokončený výběr ze dne 2026-09-10: chůze se sekerou, obouruční sekání a chůze s kládou. Každá činnost má všech osm skutečně vytvořených směrů.

- 439 animačních snímků, plátno 256 × 256 px, skutečné průhledné pozadí.
- Tři atlasy a jednotlivé PNG; 24 vstupních referencí je archivováno zvlášť.
- Kláda podélně na pravém rameni, při nesení jediná sekera na levém boku. Směry nejsou zrcadlené.
- Výběr a rychlost přehrávání každého směru určuje manifest. Nevynucovat jedno společné FPS.

## Náhled

Po rozbalení otevřete `preview/index.html` v prohlížeči. Umožňuje přepínat činnost, pozastavit přehrávání, krokovat a měnit velikost. `preview/overview.apng.png` ukazuje všechny činnosti a směry současně; jednotlivé APNG jsou ve složkách činností. Přehled je zmenšený náhled, plné zdroje jsou v `package/frames`.

## Připraveno pro Godot

1. Obsah `package/` zkopírujte do `art/units/lumberjack-pixellab-v2/` uvnitř svého Godot projektu.
2. Obsah `godot-integration/` přidejte do kořene stejného projektu při zachování podsložek `scripts/` a `tools/`.
3. Otevřete a spusťte scénu `tools/preview_pixellab_lumberjack.tscn`. Prohlížeč načte všechny směry přes přiloženou knihovnu.

Při exportu hry zahrňte JSON soubory do exportního filtru (`*.json`). Knihovna čte `manifest.json` a importované atlasy. Samostatná ukázka hlavní hru nepřepisuje.

Plátno se neořezává. Společná pracovní kotva je (128,205), tělesné měřítko 163 zdrojových px → 33 herních px. Kotva, fyzická poloha, řazení a stín jsou oddělené hodnoty. Vstupní raw00 reference nejsou dodatečná animace stání; `rest_frame` označuje konkrétní vybranou animační fázi.

## Stav předání

Balík prošel skutečným importem a samostatným vykreslením v Godotu 4.7.2: 24/24 kombinací a 439/439 snímků, bez chyb a varování readeru. V `checks/native/` je 15 kontrolních obrázků a záznam běhu. Balík je připravený k importu a samostatnému prohlížení. Napojení do běžné hry, kontakt sekery se stromem, terénní usazení a přechody činností se ještě kalibrují v normální herní scéně. Uživatelské výtvarné přijetí není automaticky odvozené od technického ověření. Podrobná dokumentace a skutečné výsledky kontrol jsou v projektu v `docs/art/qa/lumberjack-pixellab-production-v2/`.

Výroba včetně odmítnutých pokusů: 55 dokončených úloh, 560 zahrnutých generací. Zůstatek po dokončení 4440 z 5000. Další peněžní generovací poplatek 0 USD; cena již zakoupeného předplatného není součástí tohoto údaje.
