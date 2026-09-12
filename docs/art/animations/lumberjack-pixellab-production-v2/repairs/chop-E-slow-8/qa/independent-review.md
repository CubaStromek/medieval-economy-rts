# Nezávislá kontrola: chop E slow 8

2026-09-10 · agent animation_services · **PASS — čistý čitelný cyklus**.
Prohlédnut [celý arch](contact.png), všech 9 raw fází 0–8, a detailně
[02](../images/frame_02.png), [05](../images/frame_05.png),
[08](../images/frame_08.png). Zamýšlená smyčka je **raw 1–8**;
raw 00 zůstává zdrojovou referencí.

- **Směr:** čepel při úderu zůstává před postavou doprava, ve správném
  směru E. Nápřah 1–2, klesání 3–4, dopad/podržení 5–6, návrat 7–8
  tvoří jednu srozumitelnou akci. Čepel nepřejde za tělo doleva.
- **Vybavení a ruce:** jedna souvislá sekera, dvě čitelné ruce na topůrku
  před tělem. Nevidím odpojenou čepel, druhý nástroj ani přesun jedné
  ruky za opačný bok. V koncové póze zůstává čepel přibližně u pasu.
- **Čistota:** žádný vějíř, pohybová stopa, částice, strom, špalek nebo
  jiné přidané prostředí. Dřívější FX z E-forward raw 02 zde není.
- **Postoj:** nohy zůstávají ve stejném pracovním postoji. V naměřeném
  alfa obalu je levá mez stále x=99 a dolní y=206; malé změny ostatních
  mezí souvisejí s pohybem sekery, ne s odplouváním jednotky.
- **Smyčka:** raw 8 vrací sekeru do původního šikmého držení a raw 1
  pokračuje do dalšího nápřahu. Jde o jeden úder v osmi vybraných fázích.

Při navržených **6 fps** trvá cyklus `8/6 = 1,333… s`. Tato varianta má
jen osm časových poloh, takže může při přehrávání působit úsečněji než
dobře vytvořená delší sekvence. To není důvod zahodit čistou geometrii;
24fázový pokus bude potřeba posoudit podle skutečných výsledků, nikoli
automaticky upřednostnit kvůli vyššímu počtu obrázků.

[Technická kontrola](statistics.json): 9 skutečných RGBA snímků, bez
varování a přesných duplikátů; zdroje nezměněné. Tento posudek připouští
raw 1–8 k dalšímu balení. Skutečný kontakt s kmenem, nativní čitelnost
při 33 px a uživatelské výtvarné přijetí dosud nejsou tímto archem doložené.
PNG, API data, fps a runtime balík jsem při kontrole neměnil.
