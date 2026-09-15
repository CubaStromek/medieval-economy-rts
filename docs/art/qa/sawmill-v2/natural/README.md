# Pila v2 v normální hře — 2026-09-12

Skutečný výchozí v2 renderer, čerstvý Godot4.7.2 / Apple M4 / Compatibility.
`game/tests/sawmill_operation_game_runner.tscn` prošel menu→výběr Relief→
reálnou logistiku a výrobu→noc→izolované save/load. Nebyly vyráběny umělé
zásoby, pracovní stavy ani skok hodin. Mění se pouze ovládání, kamera,
rychlost přehrávání a testovací cesta uložení; hráčovy save soubory se nečtou.

Výsledek: **6 fází,8 screenshotů,34 pohybových vzorků,0 selhání**, exit0,
[čistý nativní log](native.log). [Úplný report](report.json) nese skutečné
načtené vrstvy a hashe aktivního v2 manifestu/artworku.

| Událost | Tick | Skutečný vykreslený stav |
| --- | ---: | --- |
| Počátek |0| Prázdná pila, tesař přichází |
| [Odpočinek](day-rest.png) |2| Tesař u dveří, otevřené levé okno |
| Dodávka nosičem |234| Vstupní zásoba0→1 kláda |
| [Práce](actual-production.png) |237| Kláda zpracovávána na stole, skutečný pracovní frame |
| [Dokončení dávky](produced-planks.png) |296|2 fyzická prkna, obrobek zmizí, tesař odpočívá |
| [Noc doma](night-home.png) |3750|1 vstupní kláda,4 prkna, nedokončená kláda na stole, okno a komín |
| [Načtená noc](loaded-night-home.png) |3750| Tytéž inventáře,35 zbývajících pracovních ticků a tytéž načtené vrstvy |

Dům4 / tesař20 jsou skutečné objekty mapy Relief. Modrý nosič před dveřmi
je jiná jednotka, nikoli duplikát tesaře. Root prohlédl výrobu, dokončení,
načtenou noc i původní pohybové snímky a porovnal jejich vrstvy s reportem.

## Pohyb při rychlosti1×

[Video práce](work-at-1x.mp4) je1152×720,3.599s; kamera2.4×, simulace1×.
34 skutečných vzorků zachycuje všech šest pracovních fází za3.498938s
skutečného času a3.465766s simulace. PNG se zakódovaly až po přehrávání;
žádné ruční simulační krokování během záznamu. Pozdější noc proběhla
zrychleným vykonáním každého skutečného ticku v dávkách, bez přeskočení času.

Video zachovává proměnné intervaly skutečných snímků: min88.678ms,
medián101.349ms,max283.672ms. Maximální odchylka zakódovaného časování
je0.498ms. Poslední obraz je podržen a jednou zopakován pouze pro zakončení:
35 zakódovaných obrazů nepředstírá35 různých pozorování.
[Časování](video-timing.json) a [seznam snímků](work-motion.ffconcat)
umožňují export zopakovat přes `sources/sawmill-v2/export-natural-video.cjs`.

V jiné souběžné headless instanci dobíhala plná testovací sada; případné
nepravidelné intervaly proto nezakrýváme tvrzením o dokonale pravidelných10fps.
Vlastní zdrojové obrázky a scénové kroky se během záznamu neměnily.
