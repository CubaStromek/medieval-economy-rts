# Chop W: jeden celý zásah z původního průběhu

Datum: **2026-09-10**. Agent `walk_preview`. Doplněk k
[nezávislému posudku směru a vybavení](independent-review.md).
**Podmíněný PASS pro kurátorský výběr raw 01–10 při 7,5 fps**;
výhrada k fyzické dráze zakrytého úchopu zůstává.

Prohlédnut celý [kontaktní arch](contact.png) 00–16 a samostatně
detaily 01, 02, 06, 10, 11 a 16. Raw průběh obsahuje dva údery,
ale jejich výdrže nejsou při opakování 01–16 stejně dlouhé.

| Raw snímky | Fáze | Výběr |
|---|---|---|
| 00 | Vstupní reference | Pouze zachovaný raw |
| 01 | Připravená sekera před tělem | Ano |
| 02–05 | První nápřah | Ano |
| 06–09 | První dopad vlevo a výdrž | Ano |
| 10 | Zvedání z dolní polohy, návrat přes hranici k 01 | Ano |
| 11–15 | Druhý nápřah | Zachovat raw, nepřehrávat |
| 16 | Druhý dopad, s jinou výdrží při spojení do smyčky | Zachovat raw, nepřehrávat |

**10 / 7,5 = 1,333… s**, tedy stejná délka jednoho zásahu jako
16 snímků při 12 fps u ostatních směrů. Výběr 01–10 zachovává první
přípravnou mezifázi a první návrat; nezdvojuje dopad přidáním koncového
16. Jde o explicitní výběr, nikoli o odstraňování přesných duplikátů.

## Spoj 10 → 01 a omezení

Raw 10 zvedá čepel z dolní polohy, 01 pokračuje do připravené pozice
před tělem a 02 začíná vysoký nápřah. Hranice tak patří k návratu
jednoho cyklu. Původní 16→01 by také udržel viditelnou sekeru, ale
vynechal by delší výdrž druhého zásahu a vytvořil nestejný rytmus.
Výběr je odůvodněný fází pohybu, nikoli jen nejnižším rozdílem pixelů.

Při nápřahu jsou dvě ruce na jediné sekerě. V dopadu 06–09 je jedna
ruka poblíž čepele vlevo před postavou, druhá zůstává za pravým bokem.
Střed topůrka zakrývá trup. Neobjevuje se druhý nástroj a čepel dopadá
na správnou levou stranu W, ale **společný fyzicky správný obouruční
úder před tělem z těchto pixelů nelze bezvýhradně potvrdit**. Návrat
10→01 tuto zadní ruku přesune dopředu; jde o rychlou změnu a neověřenou
zakrytou dráhu. Výběr snímků tuto kresbu neopravuje.

Nápřah i dolní výdrž trvají několik podobných póz, vlastní úder 05→06
je prudký. Kadence jednoho zásahu je sjednocená, ale fyzika úchopu,
plynulost a skutečný kontakt s kmenem se musí posoudit v kontextu hry.
Tento záznam není bezvýhradným přijetím výtvarné kvality.

Všech 17 raw PNG zůstalo zachováno; žádné rovnání bot, změna kotvy,
zrcadlení, oprava pixelů nebo vymazání snímků. SHA256 byla ověřena
proti předchozímu `statistics.json`. Přesný výběr, job ID, původní hashe,
alfa a porovnání švů jsou v
[independent-selection.json](independent-selection.json).
