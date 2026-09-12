# Kontrola dřevorubce — PixelLab chůze v1

Datum: **2026-09-10**. Kontrolující: hlavní agent a nezávislý agent
`walk_preview`. Stav: **ověřen dílčí výstup; známé výtvarné vady, hra nezapojena**.
Podle [QA šablony](../../object-qa-template.md),
[integrační záznam](../../briefs/lumberjack-pixellab-walk-v1-integration.md).

## 1. Co se skutečně ověřovalo

Osm statických rotací a devět S animačních snímků; zbývajících sedm
směrů chůze není dodáno. Jeden původní vlastní
[pohled S](../../animation-references/lumberjack-without-log/S.png).
[Úplný záznam sady](../../animations/lumberjack-pixellab-walk-v1/README.md)
odkazuje skutečné požadavky a odpovědi PixelLabu.

Skutečně prohlédnuté obrázky:
[rotace](../../animations/lumberjack-pixellab-walk-v1/rotations/rotations-review.png),
N `rotations/images/frame_04.png`, původní S a
[všech devět S snímků s referencí](../../animations/lumberjack-pixellab-walk-v1/jobs/S/qa/all-returned-frames-contact-sheet.png).
Pohybové hodnocení vychází ze všech fází a porovnání konce se začátkem;
nevydává se za ověření pohybu ve hře.

## 2. Technické a vizuální výsledky

| Kontrola | Výsledek a důkaz |
|---|---|
| Počet a canvas | **Pozor:** požadováno 8, skutečně 9 různých snímků S, všechny 128 × 128 px. Žádný snímek vyhozen |
| Skutečná alfa | **Prošlo 9/9:** viditelné i nulové alfa pixely; žádný neprůhledný pixel na hraně canvas. [Měření](../../animations/lumberjack-pixellab-walk-v1/qa.json) |
| Zachování zdrojů a atlas | **Prošlo 9/9:** původní PNG SHA256 beze změny, každá celá RGBA buňka atlasu přesně shodná se vstupem |
| Duplicity | **9 různých RGBA:** žádná přesná shoda mezi snímky; 08 není kopie 00 |
| Vstup proti prvnímu snímku | API 00 se liší od odeslaného S v 94 pixelech (RGB i alfa). Výklad „zpracovaný první + osm nových“ je inference, ne potvrzený kontrakt přímého endpointu |
| Identita a kamera | Přehled všech rotací/S fází ukazuje souvislou identitu, přední zástěru a vyvýšenou kameru; přesný úhel nebyl měřen |
| Vybavení S | Ve všech devíti snímcích jedna sekera v anatomické pravé ruce, levá volná. Hlava sekery se v pozdějších fázích výrazně zesvětluje a mění čitelnost |
| Vybavení N | **Selhalo / neověřeno:** v samotné rotaci N není viditelná sekera ani topůrko, obě ruce čteme jako prázdné. Nelze bez důkazu tvrdit pouhou okluzi |
| Krok S | Pohyb nohou existuje, nohy si v průběhu vymění předsunutí; není to pouze pohupování statické pózy |
| Uzavření smyčky S | **Selhalo:** konec má opačnou předsunutou nohu než začátek; cyklus se nevrátí. Přechod 08 → 00 změní 3111 pixelů; střední RGBA rozdíl 10,52 proti 4,52–8,48 u sousedních fází. Měření doplňuje vizuální nález, nenahrazuje ho |
| Malý náhled | Jediná škála 108 zdrojových px těla → 33 px; původní canvas a pohyb bot zůstávají zachovány. Není to potvrzení produkční kotvy |
| GIF | Skutečných 9 snímků při 10 fps; žádné doplnění či interpolace. GIF je kontrolní kopie na pozadí, původní alfa PNG jsou autoritou |

Podrobné porovnání vstupu, všech dvojic a přechodu konce na začátek:
[frame-count-analysis.json](../../animations/lumberjack-pixellab-walk-v1/jobs/S/qa/frame-count-analysis.json).
[Kontrola rotací](../../animations/lumberjack-pixellab-walk-v1/rotations/visual-qa.md)
rozlišuje N vadu a možné zakrytí pravé ruky/nástroje v NW/W.

## 3. Běžná hra a nepokryté kontroly

**Neprovedeno:** menu → mapa → skutečný pracovník → pohyb → interiér →
uložení/načtení. Nový atlas není integrován. Kontakt s rovinou/svahem,
řazení a překrývání, klikání, výběr, mlha, tónování, pozemní stín,
časování/pauza simulace a výkon zůstávají neověřené. Žádná rozehraná
pozice se nepřepisovala. Zelená kontrolní barva není herní podklad.

Stavební fáze, zásoby budov, růst stromů a statické rekvizity:
N/A — zde je pohyblivá jednotka. Kláda a pracovní sekání nejsou dodaný klip.

## 4. Běhy a důkazy

`preview_pixellab_walk.py` běžel na skutečném `jobs/S/images/` s
`--input-layout jobs --directions S --expected-frames 8 --body-height-source 108`.
Výsledek: 9 skutečných snímků, transparentní a beze změny zdrojů, přesná
shoda atlasu, upozornění na rozdílný počet. Vložený HTML JavaScript byl
syntakticky zkontrolován; obrazová kontrola náhledu v prohlížeči zde
nebyla provedena. Helper byl dříve ověřen i negativní neprůhlednou RGB
kontrolou, která skutečně vyvolala hlášení chybějící alfy.

[Přehrávač S](../../animations/lumberjack-pixellab-walk-v1/preview.html),
[GIF S](../../animations/lumberjack-pixellab-walk-v1/gifs/S-10fps.gif).
Všechny původní snímky a skutečné odpovědi API zůstaly zachované.

## 5. Výsledek verze

| Rozhodnutí | Stav k 2026-09-10 |
|---|---|
| Technická dodávka | Dílčí: osm rotací + devět fází S, kontrolní artefakty hotové |
| Osmisměrná chůze | **Nedokončena**, sedm směrových klipů chybí |
| Hlavní vizuální vady | S neuzavírá krok; N nemá viditelnou sekeru; proměnlivá světlost čepele S |
| Integrace do hry | Neprovedena |
| Vizuální přijetí uživatelem | Neuděleno |
| Společný etalon sady | Ne |
| Další postup | Oprava N a dokončení osmisměrné chůze vyžadují pokračování API práce; další uploady zastavila automatická schvalovací kontrola. Podrobný důvod je v README sady |
