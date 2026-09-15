# Pila: normální hra, pracovní pohyb a uložení

Ověřeno **2026-09-12**, Godot **4.7.2**, nativní Compatibility / Apple M4.
Runner `game/tests/sawmill_operation_game_runner.tscn` je samostatný
subclass původního life runneru; původní runner nebyl změněn.

Skutečné [hlavní menu](00-menu.png) → [výběr Relief](01-map-selection.png)
→ doprava klády → práce tesaře → výstup → přirozená noc → izolovaný
save/load. Nebyly přepsány zásoby, stavy pracovníků ani hodiny světa.
Runner mění pouze UI, kameru, rychlost přehrávání a dočasné cílové cesty
testovacího uložení. Hudba je vypnutá, hráčovy uložené hry se nečtou.

## Výsledky skutečné cesty

| Fáze | Tick | Vykreslené klády / prkna | Obrobek | Pracovní figura |
| --- | ---: | --- | --- | --- |
| počáteční stav | 0 | 0 / 0 | ne | ne |
| odpočinek | 2 | 0 / 0 | ne | ne |
| skutečně přijatá kláda, pozorování zásoby | 234 | zásoba vzrostla 0 → 1 | — | — |
| výroba | 237 | 0 / 0 | ano | ano |
| dokončená první dávka | 296 | 0 / 2 | ne | ne |
| noc doma | 3750 | 1 / 4 | ano | ne |
| po načtení | 3750 | 1 / 4 | ano | ne |

V [práci](actual-production.png) není duplicitní odpočívající tesař.
Po [výrobě](produced-planks.png) jsou vidět dvě skutečně uložená prkna
a tesař se vrací k odpočinku. [Noc](night-home.png) přirozeně přerušila
další dávku při 42 %: obrobek zůstal na stolici, pracovní figura zmizela,
okno se rozsvítilo a z komína jde kouř. Po [načtení](loaded-night-home.png)
zůstaly stejné skutečně načtené vrstvy, nikoli pouze stejné stavové příznaky.
Modrá postava před dveřmi je jiný běžný pracovník, ne duplikát tesaře.

Kontrola porovnává počty skutečně kreslených stock textur s inventářem,
přítomnost textury obrobku s dávkou a načtený pracovní frame s aktivitou.
Každá vykreslená vrstva musí mít neprázdnou texturu, obdélník a alfa masku.
Ve všech sledovaných fázích nebyly potřeba náhradní textové počty.

## Pohyb při skutečné rychlosti 1×

[Video práce při 1×](work-at-1x.mp4), 1152 × 720, přibližně **3,6 s**.
Kamera je přiblížená na 2,4×; **1× znamená rychlost simulace**.
Měřítko kamery 1× je navíc ověřené v [nativním přehledu](../native/context.png).

Bylo zachyceno **35 skutečných framebufferů** při přibližně 10 vzorcích/s.
Mezi prvním a posledním je **3,502965 s skutečného času** a **3,45 s
simulace**. Všechny vzorky mají rychlost simulace 1,0 a obsahují všech
šest skutečně načtených pracovních póz. Medián rozestupu je **98,4865 ms**,
minimum **30,740 ms**, maximum **273,218 ms**. Záznam tedy netvrdí
dokonale pravidelnou snímkovou frekvenci. GPU readback trval nejvýše
**0,776 ms** na snímek. PNG se zakódovala až po zastavení přehrávání.

MP4 má proměnná časování z původních wall timestamps, nikoli vynucené
pravidelné 10fps přehrání. Maximální odchylka PTS prvních 35 obrazů od
změřených časů je **0,49 ms**. Poslední snímek je pro zakončení podržen
o medián intervalu a zopakován jako koncový bod: soubor má 36 zakódovaných
obrazů, které nepředstírají 36 různých pozorování. Seznam pro opakovatelný
export je [`work-motion.ffconcat`](work-motion.ffconcat).

Prohlédnuty byly běžné herní snímky práce, více původních pohybových
vzorků, dokončení i noc před/po načtení. Postava drží podlahový kontakt,
obrobek je na stolici a tah pily je čitelný v pracovním prostoru.
Pohyb je záměrně menší než celotělový původní cyklus KaM.

[`report.json`](report.json) obsahuje všechny skutečné časové značky,
stav ke každému snímku, identifikátory vybraných pracovních póz, kontrolní
součty PNG/rendererů i protokol save/load. Výsledek: **6 fází, 8 screenshotů,
35 pohybových vzorků, 0 selhání**. Pozdější noc byla zrychlena vykonáním
každého skutečného simulačního ticku v dávkách po 32; během pohybového
záznamu takové ruční krokování neprobíhalo.
