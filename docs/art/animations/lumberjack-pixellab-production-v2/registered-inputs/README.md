# Obrazová registrace statických pracovních referencí

Datum: **2026-09-10**. Skutečně provedeno pro osm vybraných `walk_axe`
pohledů a `chop/S`. Výběr W/NW byl doplněn až po výslovném pokynu rootu
použít opravy `axe-low-W-pro-v2` a `axe-low-NW-pro-v2`. Kláda se v tomto
kroku neupravovala.

Pozdější výběr a registrace šesti dalších `chop` směrů má samostatný
[směrový QA záznam](../rotations-chop/qa/direction-review.md) a provenance.
Čistý `chop/E` v těchto rotacích chybí; byl samostatně doplněn z opravy
`edits/chop-E-pro`. Slabý úhlový rozdíl původního SE/E byl následně
řešen samostatnou opravou `edits/chop-SE-pro`, vybranou rootem; staré
SE pixely a provenance zůstaly v historii QA. Je dostupných osm
statických vstupů; nejde o přijatou animaci. Již použitý `chop/S.png` se tímto doplněním
nezměnil. Tabulka a manifest níže zachycují původní statický výběr.

Později byl samostatně registrován také `walk_log/S.png` z opravy
`edits/log-S-left-holster/images/frame_00.png`. Log je podél pravého
ramene, pravá ruka jej podpírá, levá je prázdná a jediná sekera je
zavěšená na levém boku (v S na obrazovce vpravo). Protože kláda sahá
nad hlavu, cap landmark byl vymezen ručně: vrchol y80, střed oranžového
lemu x133. Posun celého RGBA (−5, −28) dává y52/x128, bez změny měřítka
a bez ořezu viditelných pixelů. [Provenance](walk_log/S-registration.json)
a [prohlédnuté porovnání](walk_log/S-registration-review.png) obsahují
konkrétní zdroj a měření. Vykročené nohy nejsou důkaz fyzického kontaktu.

Dalších sedm log směrů je nyní registrováno také; S zůstalo přesně
beze změny. [Samostatné log QA](../rotations-log/qa/direction-review.md)
obsahuje skutečnou mapu S/SE/E/NE/N/NW/W/SW, cap ROI, posuny, provenance
a omezení zakrytého úchopu/výbavy v zadních pohledech.

Referencí je původní `direction-inputs/walk_axe/S.png`. V něm byl ověřen
vrchol čepice na **y = 52** a barevný střed kolem **x = 128**. Každý celý
RGBA obraz dostal pouze celočíselný posun. Canvas zůstává 256 × 256 px;
žádná změna velikosti, zrcadlení, vyrovnávání bot nebo oprava kresby.

| Výstup | Vybraný zdroj | Posun x/y px |
|---|---|---:|
| `walk_axe/S.png` | `direction-inputs/walk_axe/S.png` | 0 / 0 |
| `walk_axe/SE.png` | `edits/axe-low-SE-pro/images/frame_00.png` | 0 / +4 |
| `walk_axe/E.png` | `edits/axe-low-E-pro/images/frame_00.png` | −1 / +5 |
| `walk_axe/NE.png` | `edits/axe-low-NE-pro/images/frame_00.png` | −1 / +12 |
| `walk_axe/N.png` | `edits/axe-low-N-pro/images/frame_00.png` | +2 / +13 |
| `walk_axe/SW.png` | `direction-inputs/walk_axe/SW.png` | +1 / +2 |
| `walk_axe/W.png` | `edits/axe-low-W-pro-v2/images/frame_00.png` | +29 / +4 |
| `walk_axe/NW.png` | `edits/axe-low-NW-pro-v2/images/frame_00.png` | +4 / +10 |
| `chop/S.png` | `edits/chop-S-pro-v3/images/frame_00.png` | +4 / 0 |

[Společný kontaktní arch](registered-contact.png) a
[diagnostika čepice](cap-landmark-diagnostic.png) byly skutečně
prohlédnuty. Růžová čára ukazuje cílovou horní polohu/střed, azurový
obdélník barevnou oblast použitou pro registrační odhad.

## Metoda a přesné důkazy

U těchto konkrétních vybraných obrazů bylo vizuálně ověřeno, že čepice
je nejvyšší viditelnou částí; nízko nesená sekera ji nepřesahuje. Její
vrchol proto odpovídá horní hranici skutečného alfa obrysu. Barevný
registrační střed se měří z oranžové oblasti v horním 21px pásu,
v prostoru x 65–189: alfa ≥32, HSV H 0.025–0.11, S ≥0.35, V ≥0.15.
Jde o praktický barevný landmark čepice, ne přesně nalezenou kostru.
Volba hloubky horního pásu ovlivňuje u některých šikmých profilů X
přibližně o pixel; nevyvozujeme anatomickou přesnost lepší než tento
rastr. Nepoužívá se rozměr klády, sekery ani celé siluety pro škálování.

Střed obalu se zaokrouhluje jako `floor(center + 0.5)`. Po registraci
je tento rasterový střed všech snímků x128. N, NW a chop mají geometrický
střed barevného obalu x127.5, ostatní x128; půlpixel se neřeší resamplingem.
Vrchol všech čepic je přesně y52. Barvy/maska slouží pouze k měření,
nikoli k přemalování nebo změně alfy exportu.

[provenance.json](provenance.json) obsahuje zdrojové/výstupní SHA256,
celé meze alfy, parametry landmarku, posuny a počty viditelných pixelů.
Každý viditelný zdrojový RGBA pixel byl ověřen na přesně posunuté
souřadnici; **0 viditelných pixelů je oříznuto**. Počet viditelných pixelů
se nemění. Exportované PNG byly znovu otevřeny a celé výsledné RGBA
ověřeno. Původní zdroje zůstaly nezměněné. Prázdné okraje canvas se
přesunem přerozdělily, žádná viditelná část nástroje se neztratila.

Reprodukce: [register-selected-static.py](register-selected-static.py).
Skript je určen pro tento konkrétní výběr, nikoli obecný detektor hlav
nebo normalizátor animace. Starý `selected-sources-contact.png` zachycuje
prvních šest vstupů a chop před doplněním W/NW; autoritou výsledného
devítipoložkového výběru jsou aktuální `registered-contact.png` a manifest.

## Vizuální poznámky

W má po opravě prázdnou blízkou levou ruku; jediná sekera je ve vzdálené
pravé ruce. NW má také blízkou levou ruku volnou a topůrko jediné sekery
na pravé vzdálené straně zčásti zakryté tělem. Jeho zakrytí se musí
znovu posoudit v celé animaci; statická reference neprokazuje kontinuitu.

Chop S má oba úchopy na jednom souvislém topůrku a jednu čepel. Jeho
podoba a obrys jsou kompletní uvnitř canvas, včetně rezervy pro nástroj.
Ponechává vykročené nohy původní S reference. Není to automaticky
ověřený stabilní pracovní postoj: kontakt obou bot se zemí a přechod
do zásahu se musí posoudit v animaci a běžné hře. Registrace ho sama
nemění na neutrálně stojící postavu.

**Čepice je pouze obrazová registrace.** Fyzická pozice, ground kotva,
stín a hloubkové řazení z ní nebyly určeny. Dolní obrysy bot nadále
odpovídají původním různým postojům jednotlivých směrů. Tato kontrola
neprokazuje přijetí vzhledu, měřítko ve hře nebo správný kontakt se stromem.
