# Pila a dřevorubecká chata — vizuální porovnání

Datum **2026-09-12**, na výslovný požadavek uživatele porovnat kvalitu
zobrazení a natočení. Posuzují se aktuální produkční budovy; nejde o
novou kresbu ani schválení etalonu.

## Stejné podmínky

Godot 4.7.2, nativní Compatibility / Apple M4, skutečný
`res://scenes/main.tscn`. Obě budovy v jediném záběru na rovině,
stejný tick 1750 a kamera, bez obyvatel. Pila obsahuje aktuální provozní
úpravu zadní stěny. Zásoby jsou řízeně nastavené pro porovnání; nejde
o záznam přirozené výroby.

- [Prázdné budovy při 2.4×](empty-zoom-2_4.png)
- [Plné zásoby při 2.4×](full-zoom-2_4.png)
- [Běžné měřítko 1×](empty-zoom-1_0.png)
- [Manifest snímků a hashe](capture-manifest.json)

Reprodukce: nativní Godot s projektem `game` a parametrem `--script`
odkazujícím na zdejší `capture.gd`; zvukový ovladač Dummy. Tři záběry,
návratový kód 0, žádná hlášená runtime chyba. Produkční soubory, herní
kamera, půdorysy ani hráčovy uložené hry se při kontrole neupravily.

## Vizuální závěr

**Chata je v prostorové a materiálové kresbě přesvědčivější. Pila má
příbuzné materiály, ale odlišné natočení a hustotu detailu; sada dosud
není výtvarně sjednocená.** Funkční ověření pily tento nesoulad nevylučuje.

| Oblast | Dřevorubecká chata | Pila |
|---|---|---|
| Natočení | Čelní okapy a trámy výrazně stoupají doprava | Čelní okap a základna jsou téměř vodorovné, průčelí dominuje |
| Nadhled | Čitelné horní plochy stojanu, kozlíku a komína | Horní plochy úspornější, dílna působí plošeji |
| Materiály | Široké zaoblené šindele, mohutné trámy, nepravidelné kameny | Jemný pravidelný šindel, drobnější konstrukční prvky a pravidelnější kamenné řady |
| Čitelnost | Větší tvary drží objem i při malé velikosti | Střešní detail se slévá do pravidelných řádků; tmavá dílna má slabší hierarchii |
| Zásoby | Velké, jasné konce klád v předním stojanu | Výrazně menší klády v úzkém loži; stejné zboží nemá sjednocené vizuální měřítko |
| Identita | Dvě výškově odsazené hmoty, přístřešek vlevo | Dlouhá společná střecha, dílna vpravo; dobrá samostatná silueta |

Odlišný poměr šířky a hloubky sám o sobě není chyba: budovy mají jiný
půdorys a funkci. Závěr o čelnějším pohledu vychází ze směrů konstrukčních
hran a horních ploch. Přesný 3D úhel kamery se z tvarově odlišných malovaných
obrázků neodvozuje. Rozlišení PNG není hlavní problém: chata má 640² při
0.225 world px/px, pila 800² při 0.2508 world px/px. Oba obrysy se v nativním
obrazu kreslí ostře; změna nastavení herní kamery nesrovná jejich kreslené natočení.

Chata rovněž není bezchybný etalon. Její starší měření dveří je přibližně
23 world px vůči 33px člověku; pila má otvor přibližně 32.32 world px.
Geometrii a historii vedou příslušné dosavadní briefy a QA. Staré nedostatky
se nemají přebírat jako standard.

## Doporučení

Překreslit pilu do výraznějšího předolevého nadhledu, sladit směry
konstrukčních hran, zvětšit a zjednodušit šindele a sjednotit práci
s kamenem, hranami a měřítkem klád. Zachovat širokou nízkou siluetu,
otevřenou dílnu, stavové vrstvy, lidské měřítko a půdorys **4 × 2**.
Pouhé otočení či deformování hotového PNG prostorový návrh neopraví.
Tento audit výtvarnou opravu neprovádí.
