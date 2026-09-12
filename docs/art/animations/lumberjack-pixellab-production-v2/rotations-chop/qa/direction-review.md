# Chop rotations: nezávislá kontrola směru a registrace

Datum: **2026-09-10**. Skutečně prohlédnuty všechny raw obrázky,
[původní contact](contact.png), [výběr po registraci](registered-chop-contact.png)
a [oblast čepice](cap-roi-review.png). Raw rotace tvoří neúplný pilot.
Později byly samostatně opraveny E a SE, takže nyní existuje osm statických
vstupů; nejde o přijatou směrovou kresbu ani hotovou animaci.

| Raw index | Vizuální směr | Rozhodnutí | Sekera / úchop |
|---|---|---|---|
| 00 | S | Nevybrán; zachován přesně dosavadní animovaný `chop/S.png` | Jedna sekera, oba úchopy |
| 01 | SE blíže pravému profilu | Původní předběžný SE byl následně nahrazen opravou Pro | Jedna sekera, dva úchopy svislého topůrka |
| 02 | NE | Vybrán | Jedna sekera; vzdálený úchop je zčásti zakrytý |
| 03 | N | Vybrán | Jedna sekera; vzdálený úchop u ramene je zčásti zakrytý |
| 04 | NW | Vybrán | Jedna sekera, dva úchopy; vzdálený hůře čitelný |
| 05 | W | Vybrán | Jedna sekera, oba úchopy |
| 06 | SW | Vybrán | Jedna sekera, oba úchopy |
| 07 | Téměř S / S–SW | Nevybrán; nenahrazuje E | Jedna sekera přes přední část těla, oba úchopy |

**V raw rotacích čistý E chybí.** Navržená a následně provedená oprava: odvodit dvouruční pracovní postoj
z ověřeného `registered-inputs/walk_axe/E.png`, zachovat jeho pravý
profil, velikost těla a čepici, změnit pouze držení jediné sekery na
obouruční. API/prompt zajistil root. Výstup `edits/chop-E-pro/images/frame_00.png`
byl samostatně prohlédnut: pravý profil, oba úchopy jedné sekery.
Byl doplněn jako `registered-inputs/chop/E.png` bez posunu (0,0).
Pouhé přejmenování 02 na E by
označilo pohled na záda jako pravý profil. Stejně tak index 07 není NW.

Mezi pohledy se navíc mění pozice sekery a fáze postoje: svislá před
obličejem, u ramene, nízko před tělem. Nejde o rigidní otočení stejné
pózy. Zadní pohledy mají úchop zakrytý; kontinuitu obou rukou nelze
prokázat samotným statickým obrázkem a musí se znovu ověřit v animaci.
Nohy zůstávají v různých vykročených polohách.
V původním výběru byl úhlový rozdíl SE a opraveného E slabý. Root proto
výslovně vybral novou opravu `edits/chop-SE-pro/images/frame_00.png`.
Ta byla nezávisle prohlédnuta: SE nyní ukazuje zřetelně více přední
části hrudi než E a oba úchopy jediné sekery. Registrace (+5,0) nahradila
dosud neanimovaný `chop/SE.png`. Původní registrované SE pixely i celý
předchozí manifest zůstávají zachovány v [historii](history/).

## Metadata a skutečná registrace

Job `bba125f7-2220-472a-983d-f04203305500`, endpoint
`/generate-8-rotations-v3`, seed `20260945`, dokončen za 8 generací,
USD 0. Odpověď obsahuje pole osmi obrázků bez směrových štítků.
`flow_kind: animation` ani shoda počtu snímků nejsou důkaz směrové
správnosti. `images.json` výslovně uvádí, že pořadí nebylo předpokládáno.

Všech osm raw obrázků má 256 × 256 RGBA, skutečnou průhlednost a žádný
viditelný pixel na okraji. Pro pět vybraných rotací a samostatné E/SE se provedl
pouze celočíselný posun celého 256px canvas. Cíl je cap top y52,
rasterový střed x128. Žádná změna velikosti, zrcadlení nebo rovnání bot.

| Směr | Posun x/y px |
|---|---:|
| SE (nová samostatná oprava) | +5 / 0 |
| NE | −8 / +4 |
| N | −4 / +7 |
| NW | +3 / +5 |
| W | +7 / +2 |
| SW | +9 / +2 |
| E (samostatná oprava) | 0 / 0 |

Čepice je u těchto konkrétních sedmi zdrojů nejvyšší část siluety.
Oranžové topůrko v okolí hlavy ale zkresluje prostý barevný obal;
proto byl X rozsah pro každý zdroj vizuálně omezen na čepici. Barevný
landmark je přibližná obrazová registrace s nejistotou zhruba pixel,
nikoli anatomický střed nebo fyzická ground kotva.

[direction-registration.json](direction-registration.json) obsahuje
zdrojové/výstupní SHA256, explicitní ROI, meze alfy a posuny.
Každý viditelný RGBA pixel byl ověřen na přesně posunuté pozici;
**0 viditelných pixelů je oříznuto**, exportované RGBA byly znovu otevřeny
a ověřeny. Zdroje jsou nezměněné. Dosavadní `chop/S.png` zůstal přesně
beze změny: SHA256
`6a3e84d8a534e618c5f4c73db9dc2b97daa39a7d6f44b9dce1e47a6a9718e497`.

Reprodukce: [register-selected-directions.py](register-selected-directions.py).
Registrace sama neprokazuje přijetí kresby, výšku zásahu do stromu,
smyčku, kontakt se zemí ani chování v běžné hře.
