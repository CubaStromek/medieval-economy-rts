# Dřevorubec — sekání SE, varianta v2

**Stav k 2026-09-10: zamítnuto pro chybný jednoruční úchop (`rejected-for-incorrect-one-handed-grip`); nahrazení variantou v3 je rozpracované (`superseded-by-v3-awaiting-user-review`).** 2026-09-10: Původní KaM sekání používá podle upřesnění uživatele obouruční úchop. Naše dřívější interpretace jedné držící ruky a druhé volné paže byla chybná; v2 proto není věrnou předlohou a byla zamítnuta. Historické obrázky a prompty zůstávají zachované; v3 zatím není schválená.

Vytvořeno 2026-09-10 přímým generativním překreslením původního šestipózového KaM přehledu. Jediná vzhledová reference je ořez tváře a tuniky vlastní chodící postavy (`costume-reference.png`); zamítnutá sekací kresba v1 nebyla vstupem. Proběhla dvě volání vestavěného `image_gen`; původní zadání i cílená oprava kratšího dosahu horní pózy C zůstávají v `prompt-01.txt` a `prompt-02.txt`. První průchod je zaznamenaný jako draft, finální zdroj je opravená verze.

V2 vznikla jako náhrada zamítnuté v1, ale byla následně zamítnuta také. **Jednoruční držení sekery a volná druhá paže v této kresbě jsou chybnou interpretací původní animace. Požadovaný původní úchop je obouruční, obě ruce na jednom topůrku.** Přesná shoda geometrie není potvrzená a v2 nebyla ověřena ve hře.

- `keyposes-sheet.png`: nezměněná kopie 1809 × 869 px, mřížka 3 × 2.
- `raw-keyposes/A.png` až `F.png`: přesné celé buňky; všechny šířky 603 px, výšky řad 434 a 435 px.
- `unique-frames/A.png` až `F.png`: šest registrovaných póz, 640 × 480 px.
- `frames/00.png` až `09.png`: pořadí **A, B, A, C, D, D, D, E, C, F**; opakované soubory jsou bitově totožné.
- `sprite-sheet.png`: deset registrovaných fází 5 × 2, 3200 × 960 px.
- `review-10fps.gif`, `review-5fps.gif`: náhledy se správnou tříslotovou výdrží D; jedna společná 256barevná paleta. PNG zůstávají plně RGB.
- `manifest.json`: měření kotvy, výřezy, celočíselné posuny, kontrolní hashe a původ.
- `pack.py`: opakovatelný převod s Pythonem a Pillow.

Kotva přední podrážky je ve všech pózách **[256,440]**. Měří se ve čtyřech nejnižších řádcích jejího obrysu. Zdrojové kotvy A–F: **[297,399], [272,399], [236,399], [294,402], [275,402], [275,402]**. Použity byly pouze celočíselné posuny a bílé doplnění plátna; ořez se dotkl pouze prázdného pozadí. Bez změny měřítka, barev, tvarů, úchopu či póz. Nejvyšší sekera má 48 px rezervu od horní hrany. Rozdíly tvaru bot zůstávají zachované.

**RGB bez skutečného alfa kanálu.** Samostatný zemní stín při prohlídce není patrný. Původní téměř bílé pozadí se nečistilo; nové okraje jsou #FFFFFF. V rohových vzorcích původních buněk je 624 z 6144 pixelů přesně bílých, kanály [252, 253, 253] až [255, 255, 255].

Původní KaM pořadí RX ID: **1614,1613,1614,1616,2826,1618,1618,1617,1616,1615**. Kontroly potvrzují bezeztrátové výřezy, nezměněné zachované pixely po posunu, celé neuseknuté siluety, shodné plantární kotvy, šest unikátních póz a správnou časovou osu dekódovaných GIFů. Náhledové FPS nejsou potvrzením původního herního časování.
