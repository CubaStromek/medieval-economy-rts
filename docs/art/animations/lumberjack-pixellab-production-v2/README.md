# Dřevorubec — PixelLab produkční sada v2

Datum: **2026-09-10**. Stav: **kompletní bezeztrátový balík je hotový: 24 kombinací, 439 animačních
snímků a 24 archivovaných vstupních referencí. Import a úplná samostatná
nativní ukázka prošly. Následné zapojení do běžné hry a jeho QA vlastní
[herní integrační záznam](../../briefs/lumberjack-pixellab-game-v1-integration.md).**
Skutečné animační výstupy existují pro všech 24 kombinací tří činností
v osmi směrech. Finální výběr nahrazuje vadné první pokusy; jejich historická data
a posudky zůstávají zachované.

Uživatel po přechodu na placený Tier 2 zadal dokončit dřevorubce pro hru.
Předchozí omezení opakovaného odeslání odvozeného obrázku je vyřešené:

**Výslovný souhlas uživatele, 2026-09-10:**
> Potvrzuji a zadam o zrušení té původní kontroly

Uživatel potvrzuje opětovné odesílání vlastních odvozených výstupů
PixelLabu stejné službě a ruší původní početní omezení uploadů. Kompletní
výroba 24 směrových klipů, opravy a navazující reference jsou autorizované.
Jeden původní **vlastní výtvarný master** zůstává základem konzistentní
identity; neomezuje počet obrázků odvozených nebo znovu poslaných PixelLabu.
Tento souhlas není uživatelským přijetím výtvarné kvality.

Identita, materiály, kamera a původ reference jsou autoritativně v
[kanonickém zadání dřevorubce](../../briefs/lumberjack-v1.md).
Vlastní master je `docs/art/animation-references/lumberjack-without-log/S.png`;
256px technický vstup a jeho původ jsou v `inputs/S-reference-256.png`
a `inputs/provenance.json`. KaM není produkční master. Kláda se nese
podélně na anatomickém pravém rameni, pravá ruka ji podpírá a jediná
sekera je zavěšená na levém boku. Směry se nezrcadlí.

- [Implementační záznam](../../briefs/lumberjack-pixellab-production-v2-integration.md)
- [QA této verze](../../qa/lumberjack-pixellab-production-v2/README.md)
- [Uzavřený výběr 439 snímků a FPS](delivery-selection.json)
- [Packer](../../../../tools/pack_pixellab_lumberjack.py), [samostatný Godot reader](../../briefs/lumberjack-pixellab-v2-godot-reader.md)

[Stáhnout ZIP](lumberjack-pixellab-v2.zip) · [Přehrát všechny činnosti](preview/index.html) · [Animovaný přehled 3 × 8](preview/overview.apng.png) ·
[Statický přehled](preview/overview.png) · [Manifest balíku](package/manifest.json) ·
[Návod k předání a importu](DELIVERY.md) · [Skutečné nativní QA](../../qa/lumberjack-pixellab-production-v2/native/README.md)

## Skutečný stav činností

| Činnost | Výsledky a výběr k tomuto záznamu | Otevřené body |
|---|---|---|
| `walk_axe` — chůze se sekerou | Všech osm směrů prošlo zdrojovou kontrolou celé chůze, identity a jediné sekery v pravé ruce; levá je volná. Vybráno 176 fází; počet opakování kroku a FPS jsou v uzavřeném výběru a jednotlivých QA. | Nativní čitelnost ověřena; rychlost vůči skutečnému pohybu ve hře neověřena. V W je vzdálená pravá ruka částečně zakrytá. |
| `walk_log` — chůze s kládou | Všech osm směrů prošlo zdrojovým QA. N: raw 1–11 při 13,75 fps; ostatní: raw 1–16 při 20 fps. Celkem 123 fází; každý vybraný dvojkrok trvá 0,8 s. | Přesný kontakt pravého ramene s kládou je zejména v W zakrytý. Balík je ověřen technicky; terén a skutečné předání nákladu dosud neověřeny. |
| `chop` — obouruční kácení | S používá `repairs/chop-S-waist-empty`, raw 1–16 / 12 fps. N používá `repairs/chop-N-forward`, raw 1–12 / 9 fps. NE/NW/SE/SW: raw 1–16 / 12 fps. E/W používají čisté opravy `repairs/chop-{E,W}-slow-24`, raw 1–24 / 18 fps. Celkem 140 fází; jeden zásah trvá 1,333… s. | E i W prošly nezávislou kontrolou čistého obouručního cyklu a společnou nativní ukázkou. Při 1× jsou úchopy drobné; skutečný kontakt se stromem není ověřen. |

Výstupy skutečně mají canvas **256 × 256 RGBA**. Původní plán přibližně
24 fází není univerzální počet výsledků: joby vracejí různé počty a některé
obsahují opakovaný půlkrok nebo další neúplný nápřah. Kurátorský výběr
vychází z prohlédnutého celého cyklu a má explicitní zdrojové indexy.
Všechny raw snímky, včetně 00 a vynechaných konců, zůstávají zachované.

Dřívější vadné reference a joby nejsou potichu nahrazené: historická QA
zůstávají u [prvních pracovních návrhů](edits/reference-review.md),
[Pro v2](edits/pro-v2-independent-qa.md), [chop rotací](rotations-chop/qa/direction-review.md)
a jednotlivých odmítnutých animací. Příčná kláda, neprůhledné či špatně
přerámované obrazy a efekty přidané do sekání nejsou produkční etalony.

## Registrace a měřítko

[Statické reference](registered-inputs/README.md) byly registrovány
celočíselným posunem celého RGBA canvas podle vrcholu/středu čepice.
Kláda ani sekera se nepoužívají pro přepočet velikosti člověka. Cap ROI
byly vizuálně vymezené; log může sahat nad hlavu. Zdrojové obrázky zůstaly
zachované a žádný viditelný pixel se registračním posunem neořízl.
**Animované fáze se jednotlivě nevyrovnávají podle bot.**

Pracovní společná kotva je **(128,205)**, tělesné měřítko **163 → 33 px**.
Jde o původní kalibraci pro balení a samostatnou ukázku; následné ověření
kontaktu se zemí a stromem je v uvedeném herním integračním záznamu. Cap registrace,
fyzická ground kotva, hloubkové řazení a stín jsou odlišné veličiny.

## Ověřené nástroje a skutečný finální export

Skutečný [pilot walk_axe/S](pilot-walk-S/README.md) byl bezeztrátově
zabalen, importován a vykreslen v samostatném Godotu. Jeho archivovaná
verze má 24 vybraných snímků / 12 fps; není to finální tempo celé sady.
[Jeho nativní QA](../../qa/lumberjack-pixellab-v2-S-pilot/README.md) a pět
snímků dokazují samostatný prohlížeč, nikoli normální herní cestu.

[Probe FPS jednotlivých směrů](../../qa/lumberjack-pixellab-direction-fps-probe/README.md)
ověřil Godot fallback/override, pauzu, krokování a nativní vykreslení.
[Samostatné testy packeru](../../qa/lumberjack-pixellab-direction-fps-probe/packer-timing-review.md)
ověřily manifest, společný čas a přesné APNG časování. Efektivní hodnota
je `direction.fps`, pokud je zadaná, jinak `clip.fps`.

Finální [manifest](package/manifest.json) obsahuje **439 animačních PNG**
(176 walk_axe + 140 chop + 123 walk_log), tři RGBA atlasy a zvlášť
**24 raw00 referencí**, které nejsou dalšími animačními klipy.
[Kontrola balení](pack-validation.json) prošla bez varování: PNG bajty,
každá atlasová buňka i zdrojová oblast dekódovaných APNG přesně souhlasí.
[Evidence dodávky](delivery-files.json) potvrzuje nulové symlinky.
Balení nezavedlo nové generování, trim, zrcadlení, rovnání chodidel ani
změnu velikosti zdroje.

Předávací [ZIP](lumberjack-pixellab-v2.zip) obsahuje balík, náhledy,
Godot reader/prohlížeč, skutečné validační logy a [návod](DELIVERY.md).
[Kontrola archivu](qa/zip-validation.json) ověřila CRC a shodu bajtů
se zdrojovou dodávkou; obsahuje autoritativní počet souborů a velikost.

[Plný nativní běh](../../qa/lumberjack-pixellab-production-v2/native/README.md)
prošel v Godotu 4.7.2: nový import, `require-complete`, **439/439 fází
a 24/24 kombinací**, bez chyb či varování readeru. Bylo vytvořeno
a prohlédnuto **15 nativních PNG**: čtyři fáze každé činnosti při 3×
a tmavém pozadí a jeden obraz každé činnosti při 1× na zeleném.
Postava a kláda jsou při 1× čitelné, přesný úchop je drobný detail.
Jde o samostatnou scénu, nikoli simulovanou běžnou hru.

| Skutečný výstup finálního běhu | Úloha |
|---|---|
| `package/frames/<clip>/<dir>/NN.png` | Přesné kopie explicitně vybraných zdrojových PNG |
| `package/atlases/<clip>.png` | RGBA atlas s ověřenou shodou každé celé fáze |
| `package/manifest.json` | Kotva, tělesné měřítko, směrová FPS, klidová fáze, indexy a hashe |
| `package/provenance/` a reference uvedené v jeho indexu | Uzavřený výběr a 24 samostatných raw00 referencí; nejsou přimíchané do smyček |
| `preview/<clip>/<dir>.apng.png`, `preview/index.html` | Plné barvy, všechny dostupné fáze, časování a ovládání |
| `preview/overview.apng.png`, `preview/overview.png` | Mechanický 4sekundový přehled 3 × 8; celý canvas zobrazený na 128 px, nikoli nové výtvarné detaily |
| `pack-validation.json` | Skutečné počty, výběr, alfa, duplicity, pixely a zachování vstupů |

Samostatný [exportér přehledu](../../../../tools/render_pixellab_overview.py)
byl ověřen na skutečném pilotu a testu směrových FPS/atlasového čtení.
Finální [přehled](preview/overview.apng.png) skutečně obsahuje všech
24 buněk, 120 plnobarevných snímků a přesný interval 1/30 s.
[Validace](preview/overview-validation.json) ověřila dekódované RGB
a zachování vstupů. Rozložení bylo prohlédnuto v čase 0 / 0,5 / 1 / 1,5 s.
Jde o označený čtyřsekundový výňatek, nikoli důkaz všech herních přechodů.

## Náklady a předání

Tier 2 na začátku výroby potvrdil 5 000 zahrnutých generací a nulové
peněžní kredity. Agent nový nákup neprovedl. Interní limit výroby je
800 zahrnutých generací s kontrolami a rezervami před odesláním.

**Audit dokončených jobů: 2026-09-10 17:43:52 UTC** —
[55 unikátních dokončených serverových úloh, 560 zahrnutých generací,
0 USD účtovaných za generování](qa/cost-audit.md), bez běžících rezerv.
Cena předplatného v tom není zahrnutá. Audit zahrnuje i odmítnuté pokusy
a finální opravy E/W; do limitu 800 zbývá 240 generací. Úlohy se sčítají
podle unikátních serverových ID a potvrzeného účtování, nikoli podle
rozdílů souběžných globálních zůstatků.

**Přejímka a běžná herní integrace nejsou hotové.** Samostatný reader
musí být teprve ověřen v produkční cestě menu → mapa → chůze → kácení →
skutečný náklad. Zůstává fyzická kalibrace terénu/stromu, přechody stavů,
mlha, interiér, světlo, stín, řazení, pauza, UI a potlačení dvojí kresby
nákladu. Uživatelské přijetí vzhledu ani schválený etalon této sady
nejsou udělené.
