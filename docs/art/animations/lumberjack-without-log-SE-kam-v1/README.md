# Dřevorubec bez klády — první SE pilot podle KaM póz

První pilot vlastní malované postavy ve směru SE bez kresleného zemního stínu, vytvořený 10. 9. 2026. Původní osmisnímková animace KaM určuje předlohu pohybu, vlastní reference SE určuje vzhled postavy. Jde o přibližnou generativní interpretaci póz, nikoli pixelově přesnou shodu s KaM.

- `sprite-sheet.png`: původní výsledek 1536 × 1024 px, zkopírovaný beze změny.
- `frames/00.png` až `07.png`: přesné výřezy mřížky 4 × 2, každý 384 × 512 px, pořadí po řádcích.
- `review-10fps.gif` a `review-5fps.gif`: všech osm fází v původním pořadí, bez individuálního škálování či posunu. GIF používá společnou 256barevnou paletu; redukce barev platí jen pro GIF.
- `manifest.json`: rozměry, původ, SHA-256 souborů a pixelů, naměřené vlastnosti pozadí a stav ověření.

**Výsledek je RGB s neprůhledným téměř bílým pozadím. Nemá skutečný alfa kanál.** Rohové vzorky mají kanály 253–255; jen 828 z 8192 vzorkovaných pixelů je přesně #FFFFFF. Pozadí tedy není dokonale jednotné a nebylo upraveno.

Obraz vznikl třemi voláními vestavěného `image_gen`. Původní zadání `prompt-01.txt`, `prompt-02.txt` a `prompt-03.txt` jsou zachována. První dvě obsahují požadavek na průhlednost; ten výsledný soubor nesplňuje. Původní KaM fáze používají tělo RX 2228–2235 a překryv ruky se sekerou RX 3435–3442.

Při balení se neupravovaly barvy PNG, tvary, pózy, alfa, výřezy podle obrysu ani velikost či zarovnání jednotlivých postav. Zpětné složení osmi PNG je pixelově totožné se vstupním sheetem. Původní obrázek a zadání zůstaly nezměněné.

Pilot není schválený, není zapojený do hry a nebyl ve hře ověřený. Náhledová rychlost 10 nebo 5 fps není potvrzením správného herního časování ani neklouzání chodidel.

Aktualizace 2026-09-10: navazující kompletní osmisměrná revize je v [lumberjack-without-log-kam-v2](../lumberjack-without-log-kam-v2/README.md). Tento původní pilot zůstává zachovaný; nejde o aktuální export.
