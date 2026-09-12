# Dřevorubec — sekání SE, první pilot

**Stav k 2026-09-10: zamítnuto kvůli nepřesným pózám (`rejected-for-pose-fidelity`). Nahrazení je rozpracované (`superseded-by-revision-in-progress`); zatím není schválená náhradní verze.** Uživatel požaduje skutečnou návaznost na původní animaci KaM. Tato varianta přidala vlastní obouruční úchop a odlišný postoj, proto neslouží jako schválená předloha pro další tvorbu. Obrázky, prompty i historické technické kontroly zůstávají zachované.

Vlastní malovaná postava podle šesti původních KaM póz, sestavená do desetifázové sekvence **A, B, A, C, D, D, D, E, C, F**. Fáze D se drží tři časové sloty. Jde o přibližnou výtvarnou interpretaci; obouruční úchop v této kresbě není ověřenou přesnou kopií KaM úchopu.

- `keyposes-sheet.png`: nezměněná kopie výsledku 1809 × 869 px, šest póz v mřížce 3 × 2.
- `raw-keyposes/A.png` až `F.png`: celé původní buňky; horní řada 603 × 434, dolní 603 × 435 px.
- `unique-frames/A.png` až `F.png`: šest póz na společném plátně 640 × 480 px.
- `frames/00.png` až `09.png`: deset fází v původním pořadí; opakované fáze jsou bitově totožné soubory.
- `sprite-sheet.png`: registrovaná sekvence 5 × 2, celkem 3200 × 960 px.
- `review-10fps.gif`, `review-5fps.gif`: náhledy s přesnou tříslotovou výdrží D. GIF používá jednu společnou 256barevnou paletu, PNG zůstávají plně RGB.
- `manifest.json`: všechny výřezy, měření podrážky, celočíselné posuny, hashe a kontrolní výsledky.
- `pack.py`: opakovatelný převod; vyžaduje Python s Pillow a původní uvedené vstupy.

Zarovnání používá střed nejnižších čtyř řádků přední podrážky. Tento bod leží ve všech pózách na **[256, 440]**. Měřené původní kotvy A–F jsou **[352,429], [339,429], [307,429], [352,399], [343,399], [312,399]**. Použily se pouze celočíselné posuny a doplnění bílého plátna; ořez odstranil jen prázdné pozadí vlevo. Nezměnilo se měřítko, kresba, barvy ani tvar bot. Případné rozdíly zadní boty zůstávají zachované. Nejvyšší část sekery má po registraci 22 px rezervu od horní hrany.

**Všechny PNG jsou RGB bez skutečné průhlednosti.** Nebyl přidán zemní stín. Původní téměř bílé pozadí se nečistilo; nové okraje plátna jsou #FFFFFF. V rohových vzorcích původních buněk je 291 z 6144 pixelů přesně bílých, hodnoty kanálů [251, 252, 252] až [255, 255, 255].

Vytvořeno 10. 9. 2026 dvěma voláními vestavěného `image_gen`; `prompt-01.txt` a `prompt-02.txt` zůstaly nezměněné. Původní KaM pořadí RX ID: **1614, 1613, 1614, 1616, 2826, 1618, 1618, 1617, 1616, 1615**.

Kontroly ověřily nezměněné pixely původních výřezů i všech zachovaných oblastí po posunu, bezpečné okraje celé siluety, shodné plantární kotvy, šest unikátních póz, bitově totožné opakované soubory a správnou časovou osu dekódovaných GIFů.

Pilot není schválený ani zapojený do hry a neprošel herním QA. Rychlosti 10 a 5 fps jsou pouze náhledové; nepotvrzují původní herní časování.
