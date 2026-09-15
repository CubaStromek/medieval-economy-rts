# Truhlář — návrh jednotky v2

Datum: 2026-09-13. ID existující jednotky: `carpenter`.
Rozsah: jeden celotělový výtvarný koncept ve směru S podle skillu
`pixellab-godot-unit-pipeline`. Návrh čeká na reakci uživatele; nejde o
schválený etalon ani hotovou směrovou animační sadu.

Aktuální kandidát: [revize 02 — větší pila a opravený úchop](../sources/carpenter-concept-v2/carpenter-master-02-saw-grip.png).
Uživatel 2026-09-13 požádal o větší pilu a přirozenější držení. Větší list
visí mimo nohu až k dolní části holeně; prostornější držadlo umožňuje sevřít
prsty kolem rukojeti. Identita, oděv a kamera navazují na první návrh.
[Zadání opravy](../sources/carpenter-concept-v2/prompt-02-saw-grip.txt) a
[provenience revize](../sources/carpenter-concept-v2/provenance-02-saw-grip.json)
zachovávají návaznost na původní nezměněný master.

## Autority a vlastní předlohy

- [Dosavadní identita a odpočinek truhláře](carpenter-rest-v1.md).
- [Vlastní jižní reference dřevorubce](../animation-references/lumberjack-without-log/S.png):
  nadhled, malované materiály a dospělé proporce; nepřenášet jeho čepici,
  vousy, zelenou tuniku nebo sekeru.
- [Původ pracovní postavy u pily](../sources/sawmill-operation-v1/worker-README.md):
  třetí obrazová reference slouží pouze pro podobu ruční pily.
- `game/data/units.json`, záznam `carpenter`, a `game/scripts/ui_text.gd`:
  existující Truhlář pracuje v pile i ve zbraňové a zbrojířské dílně.
  Tento návrh nezavádí novou profesi.

## Identita a měřítko

Krátké kaštanové vlasy, oholená dospělá tvář, světlá lněná košile s vyhrnutými
rukávy, hnědá kožená náprsní zástěra na dvou popruzích, opasek, tmavé kalhoty
a hnědé boty. Světlá ramena, holá hlava a dlouhá zástěra odlišují truhláře od
dřevorubce i bez nástroje. Sdílí s ním přírodní paletu a velké malované plochy.

Kamera je zvýšená, přibližně čelní ve směru S: viditelný vršek hlavy, ramen
a bot. Nejde o kalibraci přesného číselného úhlu. Osvětlení je měkké shora
zleva. Obě nohy stojí na zemi; postava nemá podstavec ani okolní scénu.

Pro následnou produkci zachovat cílovou běžnou výšku těla 33 world px podle
dosavadního briefu truhláře. Měřítko počítat bez nástroje. U tohoto RGB
konceptu ještě nebyla určena výrobní kotva, alfa ani přesné kontaktní meze;
ty se musí změřit na budoucím produkčním souboru.

## Stav a vybavení

| Rozsah / stav | Vybavení a chování |
|---|---|
| Dodaný statický koncept S | Jedna ruční pila s dřevěným uzavřeným držadlem v anatomické pravé ruce (v obrázku vlevo), čepel dolů vedle nohy; levá ruka prázdná. Bez nákladu. |
| Budoucí práce u pily | Stejná identita, jedna pila; pracovní úchop a opření druhé ruky ověřit proti oddělenému materiálu a pracovnímu stolu. Nevyráběno v této dodávce. |
| Budoucí odpočinek | Prázdné ruce; navázat na stávající odpočinek a skutečnou přítomnost doma. Nevyráběno v této dodávce. |
| Další dílny a pohyb | Konkrétní nástroj, směry a cykly odvodit od skutečného stavu profese před výrobou. Koncept nepředepisuje pilu pro všechny činnosti. |

## Výroba, registrace a dodávka

První návrh vytvořen vestavěným ImageGen podle tří vlastních prohlédnutých předloh.
Následovala jedna cílená úprava podle uživatelovy korekce pily a úchopu;
přesný model nástroj neoznámil. PixelLab úlohy ani
animační cykly nebyly spuštěny. Aktuální autorizovaný rozsah je výtvarný návrh.

- [Master PNG](../sources/carpenter-concept-v2/carpenter-master.png):
  1254 × 1254, osmibitové RGB, světlé neprůhledné pozadí.
- [Přesné zadání](../sources/carpenter-concept-v2/prompt-01.txt).
- [Původ, vstupy a SHA-256](../sources/carpenter-concept-v2/provenance.json).
- [Skutečně provedená kontrola](../qa/carpenter-concept-v2/README.md).

Zdrojové kotvy, trim offsety, směrové odvozeniny, FPS, pracovní kontakty,
řazení, stíny a herní import jsou mimo rozsah tohoto konceptu a nejsou
ověřené. Před případnou integrací použít projektový
[postup objektové implementace](../object-implementation-workflow.md)
a navázat na existující záznamy místo přepisování jejich hodnot.
Soubory hry ani stávající odpočinkové/pracovní obrázky se touto dodávkou nemění.
