# Dřevorubecká chata — denní okno a rozhlížení

**2026-09-12 · technické a nativní ověření prošlo.** Doplnění
[briefu life v1](../../briefs/lumber-hut-life-v1.md) a
[implementačního záznamu](../../briefs/lumber-hut-life-v1-integration.md).
Původní [QA dveří, odpočinku a kouře](../lumber-hut-life-v1/README.md)
zůstává zachované jako historická dodávka. Tato revize přidává otevřené
nesvítící okno při denním odpočinku a jemné rozhlížení hlavy.

[**Animace odpočinku — 12 s**](rest-in-game-preview.gif) ·
[Denní a noční přehled](showcase.png) ·
[Tři polohy hlavy](head-poses.png) ·
[Běžné přiblížení 1×](look-zoom-1-00.png) ·
[0.75×](look-zoom-0-75.png) · [2.4×](look-zoom-2-40.png)

## Výsledky

| Kontrola | Výsledek a důkaz |
|---|---|
| Zaměřené testy | **13 případů, 0 selhání**; [log](focused-tests.txt). Zahrnují skutečné zdroje přítomnosti, denní okno, pauzu, importované pózy a všech 18 připravených přechodových textur. Kontrola zdrojového těla pod límcem porovnává RGBA pixely beze změn. |
| Nativní obrazové kontroly | **12/12**, návratový kód **0**, **272 záznamů**; [log](native-run.txt), [manifest](capture-manifest.json), [otisky a kontrola GIF](native-verification.json). Godot 4.7.2, Apple M4, Compatibility/OpenGL přes Metal, viewport 480 × 420. |
| Denní okno | Při odpočinku `window_open=true`, `light_strength=0`. Pixel ve zdroji domu (495,351) je při otevření tmavší: pokles luminance **0.260 / 0.259 / 0.276** při 0.75× / 1× / 2.4×; požadované minimum 0.03. Noční okno zůstává teplé a svítící. |
| Pohyb hlavy | **240 nativních fází** celého 12sekundového cyklu při 20 fps. Oblast hlavy mění nejvýše **259 pixelů**, změna nastala v **98 snímcích** vůči výchozí klidové póze; skutečně dosažené oba krajní pohledy. |
| Pevné tělo a chodidla | Ve všech 240 snímcích **0 změněných pixelů** těla i chodidel. Měřený screen ROI těla `(292,282,29,56)`, chodidel `(292,328,29,12)`, hlavy `(294,257,22,23)`. Tělo se měří od zdrojového y=91, pod filtrovaným okrajem hlavy; nejde o tvrzení, že se nemění jediný pixel celé scény mimo hlavu. Registrace celého spritu je shodná. |
| Pauza | Zastavení uprostřed otočení, čekání 0.4 s a skutečné `_process(0.4)` při nulové rychlosti: **0 změněných pixelů celého snímku**. |
| Mlha | Vlastník cizí chaty doma/venku: ve dne i v noci, prozkoumaná i neznámá oblast, všechny čtyři páry mají **0 změněných pixelů**. Skrytý stav zůstává `known=false`. |
| Terén a překrytí | [Vyvýšený základ](frames/raised-home.png) zachovává kontakt a průchozí dveře; [strom před chatou](frames/occlusion-home.png) správně zakrývá spodní část postavy. |

Produkční základ postavy má canvas 256² a tělo 33 world px. Autoritu
pro kotvu, zachovaný límec na source y=82 a přesné podklady vede
`game/art/buildings/lumber_hut/v1/life/look/look.json`; geometrie domu
se nemění. Prohlédnuté herní koncové pózy i mezipoloha `look-044.png`
neukazují barevný lem, skok krku nebo posunuté nohy. Otevřené denní okno
je tmavé a dobře se liší od nočního svitu. V oddálení je pohyb hlavy
přirozeně velmi drobný; detail a animace slouží k jeho kontrole.

## Oddělení vzorků a běžné hry

Nativní `preview_lumber_hut_life_look.tscn` vytvoří izolovanou chatu na
(14,12) ve světě 32 × 24 a používá skutečný `Main` renderer. Přidělený
pracovník vstupuje/vystupuje přes `IndoorWorkers`; činnost a čas se pro
přesné obrazové vzorky výslovně nastavují. Dvanáctisekundová ukázka
udržuje stav odpočinku, aby zachytila celý pohybový cyklus. **Nedokládá,
že každý běžný návrat pracovníka trvá dvanáct sekund.** Vzorkování čte
skutečné produkční fáze i denní osvětlení z nastaveného simulačního času;
okolní stíny se mohou mezi fázemi lišit.

Samostatný běh hlavního agenta prošel **skutečným menu → výběrem Relief →
novou hrou → chůzí → kácením → zvednutím klády → odevzdáním → odpočinkem →
odchodem → přirozeně dosaženou nocí**. Výsledek: **10 fází, 20 snímků,
0 selhání**, návratový kód 0. Dřevorubec 19, domácí chata 2:

- [Denní odpočinek, tick 117](natural-final/day-rest.png): otevřené dveře
  i okno, bez svitu; uvnitř skutečně přítomný pracovník nemá druhý venkovní sprite.
- [Odchod, tick 130](natural-final/day-exit.png): dveře i okno zavřené,
  odpočinková postava odstraněná, skutečný pracovník jde znovu těžit.
- [Spánek doma, tick 3774](natural-final/night-home.png): zavřené dveře,
  otevřené teplé okno a kouř; noční čas byl dosažen vykonáním všech
  simulačních ticků, nikoli skokem hodin nebo vložením spánku.

[Report běžné hry](natural-final/report.json) · [log](natural-final/run.log).
Jeho zděděný obecný text `coverage_limit` popisuje původní ranní test;
konkrétní `phases`, tick a snímek `night-home` dokládají rozšíření o noc.
Hráčovy uložené hry ani nastavení nebyly přepsané. Hudba se nepouštěla.

## Reprodukce a obrazové soubory

```text
godot --path game --windowed --log-file /tmp/lumber-hut-look-native.log res://tools/preview_lumber_hut_life_look.tscn
```

GIF obsahuje všech **240 zachycených snímků, 20 fps, přesně 12.000 s**.
Sdílená paleta s průhlednými nezměněnými oblastmi zmenšila soubor na
**498 204 B**. Žádné snímky se negenerovaly ani neinterpolovaly; pět
dekódovaných vzorků má proti nativním PNG průměrnou chybu palety
2.58–2.64 na kanál z 255. Všechny původní PNG a jejich časové záznamy
zůstávají zachované. Malý pohyb je záměrný, celé tělo se nekývá.

Výtvarná kontrola hlavním i QA agentem: **prošla v uvedeném rozsahu**.
Uživatelské přijetí této nové revize ani schválení společného etalonu
budov není tímto záznamem tvrzené. Nový distribuovaný export ani všechny
možné sousední svahy nebyly předmětem této doplňující kontroly.
