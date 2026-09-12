# Chůze s kládou: statické směry a registrace

Datum: **2026-09-10**. Nezávisle prohlédnuty všechny raw obrázky,
[původní contact](contact.png), [registrovaný výběr](registered-log-contact.png)
a [cap diagnostika](registered-cap-diagnostic.png). Pořadí bylo ověřeno
podle obličeje, trupu a postoje, nikoli pouze převzato z názvů.

| Raw index | Skutečný směr | Vybraný vstup | Posun x/y px |
|---|---|---|---:|
| 00 | S | Nepřepisuje dříve animovaný S | beze změny |
| 01 | SE | `registered-inputs/walk_log/SE.png` | −3 / −1 |
| 02 | E | `registered-inputs/walk_log/E.png` | −6 / +6 |
| 03 | NE | `registered-inputs/walk_log/NE.png` | −2 / +8 |
| 04 | N | `registered-inputs/walk_log/N.png` | 0 / +12 |
| 05 | NW | `registered-inputs/walk_log/NW.png` | +5 / +6 |
| 06 | W | `registered-inputs/walk_log/W.png` | +6 / 0 |
| 07 | SW | `registered-inputs/walk_log/SW.png` | +1 / +1 |

Všechny směry mají jednu kládu přibližně podél osy chůze na pravém
rameni. Pravá ruka ji podpírá, levá zůstává dole volná. V S, W a SW je
dobře vidět jediná sekera u levého boku. V bočních a zadních pohledech
je část sekery zakrytá postavou a v některých směrech je jasně čitelná
hlavně násada. U NW/W je pravá podpůrná paže na vzdálené straně a většina
paže je zakrytá; ruka je vidět u klády. Nebyla pozorována druhá sekera,
druhá kláda ani dvě ruce nesoucí kládu. Zakrytý úchop či celou čepel
nelze ze statické siluety plně prokázat: musí se ověřit kontinuita
výbavy v celé animaci. Kláda nesmí při přepínání směru změnit rameno.

## Provedená registrace

Kláda je v řadě pohledů nad hlavou; **horní alfa obrys nebyl použit
jako vrchol čepice**. Každá čepice dostala vizuálně vymezenou ROI a
ručně zkontrolované Y koruny. Praktický X střed se měří z oranžové
oblasti uvnitř této ROI (H .025–.11, S ≥.35, V ≥.15, alfa ≥32).
Log a ruce mimo ROI se do centra nezapočítávají. Po celočíselném posunu
je cap top y52 a zaokrouhlený barevný střed x128; jde o obrazový
landmark s přesností přibližně jednoho zdrojového pixelu.

Celý RGBA canvas zůstává 256 × 256. Žádný resampling, zrcadlení,
překreslení, rovnání bot ani samostatný posun nástroje. Každý viditelný
zdrojový RGBA pixel byl ověřen na přesně posunuté souřadnici; počty
viditelných pixelů jsou shodné, **0 viditelných pixelů se ořízlo**,
včetně celé klády. Exportované PNG byly znovu otevřeny a ověřeny.
Raw zdroje jsou nezměněné.

[direction-registration.json](direction-registration.json) obsahuje
konkrétní ROI, Y, zdrojové/výstupní SHA256, posuny a meze alfy.
S zůstal přesně zachován se SHA256
`979e1a464722a1217a3531ccd89ac54976c2471b38d7efb9fbbd778fdc8a1fcd`.
Reprodukce: [register-selected-directions.py](register-selected-directions.py).

Jsou dostupné všechny osmi směrové **statické** vstupy. Tato kontrola
neprokazuje hotových osm animací, smyčky, stabilní měřítko těla během
pohybu, kontakt nohou se zemí nebo přijetí v běžné hře. Cap registrace
neurčuje fyzickou ground kotvu, stín nebo hloubkové řazení.
