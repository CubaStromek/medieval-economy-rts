# Chop N: výběr jednoho celého zásahu

Datum: **2026-09-10**. Výsledek: **PASS pro výslovně kurátorovaný výběr
raw 01–12 při 9 fps**. Samotné přehrání všech 01–16 není doporučeno,
protože končí uprostřed dalšího nápřahu.

Bylo prohlédnuto všech 17 původních obrázků v
[kontaktním archu](contact.png) a samostatně detaily 01, 03, 06, 11,
12, 13 a 16. Výběr je podle fáze pracovního pohybu:

| Raw snímky | Skutečně pozorovaná fáze | Rozhodnutí |
|---|---|---|
| 00 | Vstupní/reference podobný postoj | Zachovat v raw; nevybírat do smyčky |
| 01–05 | Zvednutí sekery do nápřahu nad hlavou | Vybrat |
| 06–11 | Jediný úder dopředu a delší výdrž v dolní poloze | Vybrat |
| 12 | Návrat do polohy blízké 01 | Vybrat jako konec celého cyklu |
| 13–16 | Nový nápřah, který nemá další úder ani návrat | Uchovat raw, vynechat z přehrávání |

Celkem **12 snímků / 9 fps = 1,333… s**. To je stejná délka jednoho
zásahu jako 16 snímků při 12 fps u ostatních směrů. Tento výběr
nemění pořadí, nevyrábí nové fáze a nepřesouvá jednotlivé části těla.
Raw 12 není přesnou kopií 01; nebyl odstraněn jako údajný duplikát.

## Spoj a výbava

Spoj **12 → 01** se vrací mezi podobnými polohami nástroje u ramene;
nevytváří další nedokončený výpad. Původní **16 → 01** by skočil
z druhého vysokého nápřahu zpět dolů bez úderu. RGB rozdíl na obalu
sjednocené siluety je 4,44/255 pro 12→01, oproti 7,68/255 pro 16→01.
Pro porovnání návrat 11→12 má 5,06/255 a nápřah 01→02 má 6,57/255.
Tyto metriky podporují skutečně prohlédnutý spoj; samotná číselná
podobnost není důkaz správné animace.

Po celou dobu je přítomná **jedna sekera**. V horním nápřahu jsou
viditelné dvě oddělené ruce svírající stejné souvislé topůrko. V dolní
poloze jsou úchopy na vzdálené straně před trupem z větší části zakryté;
čepel a konec topůrka vystupují po stranách těla. Pohyb již nevypadá
jako samostatné seknutí za bokem nebo do zad. Nebyla pozorována druhá
čepel, druhá sekera ani samovolné přehazování nástroje mezi rukama.
Zakrytí nicméně neumožňuje ověřit každý prst dolního úchopu.

## Konkrétní omezení

Přechod 05→06 je rychlý a dolní výdrž 06–11 je poměrně dlouhá; pohyb
má důraz na zásah a pauzu, ne rovnoměrnou plynulou křivku. Výběr 01–12
řeší celý cyklus, nikoli tuto stylizaci. Dole je velká část kontaktu
sekery zakrytá postavou; skutečný zásah do stromu, výška dotyku a
fyzické umístění jednotky musí být posouzeny v běžné hře. Zde se
neprovádělo rovnání bot ani změna ground kotvy.

Všech 17 raw PNG má 256 × 256 RGBA a skutečnou průhlednost, bez
viditelných pixelů na hraně canvas. Jejich SHA256 byly porovnány s
předchozím `statistics.json` a zůstaly stejné. Výběr, job ID, konkrétní
měření a hashe jsou v [independent-selection.json](independent-selection.json).
Žádný původní obrázek se nesmazal, neposunul ani nepřekreslil.
