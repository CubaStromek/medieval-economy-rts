# walk_log / SW — nezávislé QA

Datum: **2026-09-10**. Výsledek: **PASS pro další kontrolu v balíku**,
bez požadavku na novou generaci tohoto klipu. Není to přijetí běžné hry.

Prohlédnuto všech 17 raw snímků v [kontaktním archu](contact.png) a
samostatně detaily 01, 08 a 16. Vybraný průběh je **raw 1–16**; raw 00
zůstává zachován. Mezi 17 raw snímky není žádná přesná RGBA duplicita.

Ve vybraných 16 snímcích je **jeden celý krokový cyklus**: 01–04
rozvíjí první nohu vepředu, kolem 05 se nohy míjejí, 06–11 se rozvine
opačná noha a 12–16 se postoj vrátí k výchozí fázi. Jsou vidět obě
střídající se nohy, nikoli opakovaný pohyb jedné. Pro cílových 0,8 s
vychází **20 fps** (16 / 20 = 0,8 s). Některé části došlapu jsou
držené déle než jiné; přehrání není rovnoměrnou interpolací póz.

Jedna kláda zůstává podél pravého ramene, podpíraná pravou rukou.
Volná levá ruka zůstává dole. Jediná sekera je dobře čitelná na levém
boku, čepel u pasu a násada dolů. Nebyla pozorována duplikace nástroje,
přehazování klády, změna podpůrné ruky nebo nápadné oddělení klády
od jejího úchopu. Místo opření je zčásti zakryté hlavou a zvednutou
paží; silueta neumožňuje dokázat přesný fyzikální kontakt ramene.

Spoj **16 → 01** vrací odpovídající první krok bez nápadného skoku
klády nebo levé sekery. Rozdíl RGB na obalu sjednocené siluety je
6,45/255; běžné sousední změny 01–16 jsou 4,34–10,71/255. Číslo
podporuje vizuální kontrolu, samo neprokazuje kvalitu smyčky.

Všech 17 PNG je 256 × 256 RGBA se skutečnou alfou; žádný viditelný
pixel neleží na okraji. Nebyla provedena registrace jednotlivých fází,
oprava pixelů nebo odstranění raw snímků. Konkrétní SHA256, job ID
`1d7718f3-3c1b-4ee8-9de6-b65734a2b8ce` a měření jsou v
[independent-statistics.json](independent-statistics.json).

Kontakt bot se zemí, rychlost vůči skutečnému pohybu jednotky a zakrytí
výbavy při herní velikosti se musí ověřit při společném přehrání a ve hře.
