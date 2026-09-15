# Pila — nativní kontrola života budovy

Datum **2026-09-12**, Godot **4.7.2**, OpenGL Compatibility / Apple M4.
Skutečná `Main` scéna s produkčním sprite loaderem a `ProductionBuildingLife`.
Samostatné přesné stavové vzorky nepřepisují hru, nastavení ani uložené pozice;
žádný GameSession nebo hudební přehrávač se nespouští.

## Výsledky

- **12/12** cílených případů v `production_building_life_tests.gd` prošlo.
  Reálná simulace dovedla tesaře do pily, spotřebovala jednu kládu, vyrobila
  dvě prkna a nechala ho odpočívat uvnitř. Nová kláda spustila práci a
  odpočinková kresba skončila. Ověřen skutečný návrat při pauze a na noc.
- Test cizí mlhy počítá volání `workplace_worker`: u cizí budovy je **0**,
  takže nejde pouze o skrytí výsledku po načtení privátního obyvatele.
- Importovaný tesař má měřenou výšku **165 source px → 33 world px**.
  Skutečná alfa určuje klikání; prázdné okraje nejsou další jednotka.
- Všechny tři importované pohledy zachovaly každý RGBA pixel od řádku 79
  dolů. V 96 nativních snímcích zůstala celá registrovaná `rest_rect` totožná.
  Prohlédnuté levé/střední/pravé vzorky mění hlavu bez pohybu opření a bot.
- **12 nativních scénářových snímků** pokrývá přítomnost/nepřítomnost,
  práci/odpočinek/pauzu, den/noc, 0.75×/1×/2.4×, vyvýšený podklad
  a přední strom. Dva přehledové archy byly po exportu vizuálně zkontrolovány.

## Obrazové kontroly

| Kontrola | Výsledek |
|---|---|
| Dveře při pobytu doma | Otvor kryje původní zavřený list; žádná klika nebo pásový pant nezůstává přes tmavý průchod |
| Levé okno za dne | Otevřený tmavý vnitřek a okenice, bez emisivního svitu |
| Levé okno v noci | Teplé čtyřpolové okno, zachovaný obvodový rám; kouř vychází z otvoru komína |
| Aktivní výroba | Bez odpočívající postavy a domácího kouře, dveře otevřené podle skutečné přítomnosti |
| Nepřítomný obyvatel | Bez odpočinkové postavy a nočního svitu/kouře |
| Klidová postava | Vedle levého předního sloupku; neucpává dveře a nese skutečné ID tesaře |
| Přední strom | Zakrývá dílnu přes stejné nativní řazení; life vrstva není globálně nad objekty |
| Vyvýšená rovina | Dům i postava drží stejnou výškovou projekci; skutečný obrys je stále 4×2 polí |

Přesný půdorysný důkaz a měření kontaktů vlastní nadřazený QA záznam
a `../asset-validation.json`; tyto obrázky jsou jeho nativní vizuální doplnění.
Schválení výtvarného směru celé budoucí sady se z průchodu těchto testů
neodvozuje. Vzorky dne/noci jsou řízené QA stavy; běžnou cestu menu a
normálního hraní dokládá samostatný projektový záznam.

## Výstupy

- [Stavy domácnosti](states.png)
- [Měřítko, zemní kontakt a zakrytí](context.png)
- [Jemné rozhlížení — video 12 sekund](resting-carpenter.mp4)
- [Manifest snímků a produkční otisk](capture-manifest.json)

Video má **640×460, 8 fps, 96 snímků, 12.000 s** podle `ffprobe`. Jde pouze
o zakódování 96 skutečných nativních snímků, ne o náhradní animaci domu.
Při přehrávání drží tělo stejný kontakt; dlouhé klidné výdrže přerušují
krátké otočky hlavy. Světlo, stín a čas pocházejí ze skutečné hlavní scény.

Opakování: `game/tools/preview_sawmill_life.tscn`, volitelně
`--output=/absolute/path`. `--sheets-only` přeskupí již uložené nativní
obrázky do přehledů bez opakování herních vzorků. Technický 1024²
generační podklad před návrhem zůstává samostatně v `../guide.png`.
