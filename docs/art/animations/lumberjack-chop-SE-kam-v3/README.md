# Dřevorubec — sekání SE, v3

Varianta z 2026-09-10 používá **obě ruce na jednom topůrku** ve všech šesti vybraných pózách. Nahrazuje v2 zamítnutou pro chybný jednoruční úchop. Jde o přibližné generativní překreslení původních póz KaM, nikoli přesné trasování. **Není schválená ani zapojená či ověřená ve hře.**

Finální A/B pocházejí ze čtvrtého průchodu (2 × 1, 2092 × 752 px), C/D/E/F ze druhého průchodu (buňky 2/3/4/5 mřížky 3 × 2, 1808 × 870 px). První a třetí průchod měly vadné úchopy A/B a ve finálních snímcích se nepoužívají. Všechna čtyři původní zadání jsou zachovaná.

Použit byl vestavěný generátor OpenAI `image_gen`. Zadání: [první oprava](prompt-01.txt), [oprava úchopů A/B/F](prompt-02.txt), [neúspěšná oprava A/B](prompt-03.txt), [finální samostatné A/B](prompt-04.txt). U zdroje `source-final-CDEF.png` jsou finální pouze C–F; jeho původní horní A/B se nepoužívají.

- `source-final-AB.png`, `source-final-CDEF.png`: obě zdrojové sheets zkopírované beze změn.
- `raw-keyposes/A.png` až `F.png`: přesné původní výřezy.
- `unique-frames/A.png` až `F.png`: šest finálních póz na plátně 640 × 480 px, kotva přední podrážky **[256,440]**.
- `frames/00.png` až `09.png`: pořadí **A,B,A,C,D,D,D,E,C,F**. Opakované fáze jsou bitově totožné PNG.
- `keyposes-sheet.png`: šest registrovaných póz 3 × 2; `sprite-sheet.png`: deset fází 5 × 2.
- `review-10fps.gif`, `review-5fps.gif`: přesná tříslotová výdrž D; společná 256barevná paleta.
- `manifest.json`: původ, měření, posuny, převzorkování a SHA-256; `pack.py`: opakovatelný převod.

**A/B jsou převzorkované, nikoli pixelově totožné se zdrojem.** Výška od vrcholu čepice k podrážce je u obou 580 px; průměr C–F je 351,25 px. Jediný společný faktor **0.605603448** převádí oba výřezy 1046 × 752 na **633 × 455 px** filtrem Lanczos. Měřilo se v úzkém výřezu koruny čepice, bez sekery. C–F se nezvětšovaly ani nezmenšovaly; používají pouze celočíselné posuny. Zachované pixely C–F i pracovní pixely A/B po převzorkování jsou posunuty beze změny. Ořez se týká jen prázdného pozadí, siluety jsou celé.

**RGB, neprůhledné téměř bílé pozadí, žádný skutečný alfa kanál.** Samostatný zemní stín není na vybraných zdrojích patrný. Pozadí se neodstraňovalo ani nepřebarvovalo; doplněné okraje jsou #FFFFFF. Kontroly potvrdily společné kotvy, šest unikátních póz, nezměněné zdrojové kopie a výřezy, bezpečné okraje a správnou časovou osu dekódovaných GIFů. Náhledové FPS nejsou potvrzením původního herního časování.
