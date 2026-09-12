# walk_log / NW — nezávislé QA

Datum: **2026-09-10**. Výsledek: **PASS pro další kontrolu v balíku**,
bez požadavku na novou generaci tohoto klipu. Není to přijetí běžné hry.

Prohlédnuto všech 17 raw snímků v [kontaktním archu](contact.png) a
samostatně detaily 01, 08 a 16. Vybraný průběh je **raw 1–16**; raw 00
zůstává zachován. Mezi 17 raw snímky není žádná přesná RGBA duplicita.

Ve vybraných 16 snímcích je **jeden celý krokový cyklus**: první půle
01–07 vede jednu nohu dozadu a přes návrat, 08 přechází přes postoj
s nohama blízko sebe; 09–15 rozvine opačný krok a 16 se vrací do první
fáze. Nejde o dvě opakování stejného cyklu. Pro cílových 0,8 s vychází
**20 fps** (16 / 20 = 0,8 s).

Jedna kláda zůstává podél pravého ramene. Pravá podpůrná ruka na
vzdálené straně zůstává u klády; paže je většinou zakrytá. Levá ruka
je volná a mírně se pohybuje. Jediná sekera zůstává u levého boku;
čepel je v první části zakrytá levou paží a kolem 08–15 se odkrývá.
To odpovídá změně překryvu, ne vzniku druhého nástroje. Nebyla
pozorována druhá kláda, přehazování mezi rameny nebo oddělení klády
od podpůrné ruky. Přesný tlak klády na rameno je částečně zakrytý
hlavou/paží; samotná silueta neprokazuje fyzikální kontakt.

Spoj **16 → 01** vrací odpovídající postoj bez nápadného skoku klády
nebo výměny nohou. Rozdíl RGB na obalu sjednocené siluety je 5,31/255;
běžné sousední změny 01–16 jsou 5,63–10,66/255. Číslo podporuje
vizuální kontrolu, samo neprokazuje kvalitu smyčky.

Všech 17 PNG je 256 × 256 RGBA se skutečnou alfou; žádný viditelný
pixel neleží na okraji. Nebyla provedena registrace jednotlivých fází,
oprava pixelů nebo odstranění raw snímků. Konkrétní SHA256, job ID
`77a773bb-5a3d-4039-8003-f5f7d2ac07ac` a měření jsou v
[independent-statistics.json](independent-statistics.json).

Kontakt bot se zemí, rychlost vůči skutečnému pohybu jednotky a čitelnost
sekery při herní velikosti se musí ověřit při společném přehrání a ve hře.
