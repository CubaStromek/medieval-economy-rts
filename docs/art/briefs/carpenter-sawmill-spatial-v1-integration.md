# Truhlář u pily — usazení animace v prostoru

Datum: 2026-09-13. ID `carpenter`, budova `sawmill` v2.
Rozsah: oprava vykreslení existující pracovní animace a odpočinku.
Záznam podle [společného postupu](../object-implementation-workflow.md)
a [integrační šablony](../object-integration-template.md).
Stav: zapojeno a ověřeno v běžné hře; 856/856 povinných kontrol bez okna,
45/45 cílených nativních kontrol a skutečná výroba/noc/save-load bez selhání.

## 1. Zadání a autority

Uživatel popsal původní pracovní animaci jako prostorově odtrženou od dílny
a požádal upravit stíny a případně výšku truhláře. Nativní kontrola potvrdila,
že pracovní figura neměla žádný kontaktní stín a nedostávala místní zastínění
pod střechou. Nešlo o numerickou chybu dvojího škálování.

Autority: [provoz pily](sawmill-operation-v1-integration.md),
[registrace domu v2](sawmill-v2-integration.md),
[odpočinková postava](carpenter-rest-v1.md),
[vlastní původ šesti pracovních póz](../sources/sawmill-operation-v1/worker-README.md).
Novější [koncept truhláře](carpenter-concept-v2.md) zůstává samostatným návrhem;
tato oprava pracuje s již implementovanými obrázky.

## 2. Geometrie a registrace

Autoritativní výsledné hodnoty: `game/art/buildings/sawmill/v2/operation/manifest.json`
pro práci, `game/art/buildings/sawmill/v2/manifest.json` → `life.rest_sprite`
pro odpočinek. [Měření a původní nastavení](../sources/carpenter-sawmill-spatial-v1/geometry.json)
uchovává přesný výpočet a vazbu na zdrojový obraz.

| Kontrakt | Výsledek |
|---|---|
| Pracovní canvas / měřená výška ve zdroji | Původních 512² RGBA / 412 source px |
| Výška ohnuté pracovní pózy | 31 world px; původně 33; výtvarná korekce přibližně 6 % |
| Odpočinek | Původních 256² a 165 source px → 33 world px |
| Pracovní zdrojová kotva | Beze změny (374.5,489); společná všem šesti pózám |
| Nová pracovní kotva v canvasu domu | (615.81276512,561.48566048); posun −1.0413,−1.1796 world px směrem ke stolu |
| Opřená dlaň | Source (160,246) zůstává v house-source (529.65065635,463.87543935) |
| Pozemní kontakty | Dvě pracovní boty; u odpočinku jediná zatížená bota, druhá je zvednutá |
| Fyzická zem a řazení | Existující projekce prahu domu, půdorys a řada domu beze změny |

Uniformní zmenšení zachovává opěrný bod ruky; nejde o nezávislé zarovnávání
jednotlivých snímků podle jejich alfa obalu. Stíny mají vlastní pevná centra
v source px a mění měřítko společně s figurou. Nepřebírají pomocný bod řazení.

## 3. Vrstvy a zdroje stavů

`SawmillOperationArt` čte volitelné `work.body_height_world` a `work.appearance`.
Nový `BuildingWorkerAppearance` kreslí měkké kontaktní elipsy těsně pod
zatíženými podrážkami a jemný barevný přechod přes tělo. Horní část pracovníka
je více zastíněná střechou, dolní dostává více okolního světla. Barvy se
násobí existujícím denním/nočním ambientem právě jednou.

Pořadí: dům a obrobek → kontaktní stín → postava → dosavadní přední podpěry.
Stín je místní ztmavení při kontaktu, nikoli druhý odhad slunečního stínu.
Nemá vlastní klikací masku. Průhledné okraje ani původní alfy se nemění.

Odpočinek používá tentýž helper s jemnějším zastíněním a kontaktem u soklu.
Bez volitelných metadat funguje původní vzhled; neplatná metadata se odmítají.
Existující stavové podmínky stále vyřazují osobu i její stín při práci jinde,
nepřítomnosti, noci nebo skrytém cizím stavu.

Šest původních fází a šest cyklů na dávku zůstává řízeno pozorovanou produktivní
prací. Nevznikají prolnuté dvojité nástroje ani nová simulace v rendereru.
Chůze, recepty, zásoby, kolize, kamera, uložené pozice a noční režim se nemění.

## 4. Podklady a soubory

Neproběhlo nové generování ani přemalování PNG. Zachovány původní vlastní
pracovní pózy, odpočinek, otočení hlavy a všechny vrstvy domu i zásob.
Přesné výsledné otisky vede [QA](../qa/carpenter-sawmill-spatial-v1/README.md).

Dotčené runtime komponenty: `building_worker_appearance.gd`,
`sawmill_operation_art.gd`, `production_building_life.gd` a dva v2 manifesty.
Nastavení je deklarativní v manifestech; starý export domu ze dne 2026-09-12
zachycuje původní kalibraci. Při jeho opakování znovu aplikovat novou
kalibraci z výše odkazovaného měření, nikoli obnovit staré hodnoty 33/raw974,890.

## 5. Napojení a ověření

Normální `GameSession` → Relief → `Main` používá stejné doplněné čtenáře.
Obraz i výběr nadále sdílejí jednotnou registraci. Textury a jejich původní
masky se cachují; lokální gradient nevyrábí ani nepřepisuje zdrojové obrázky.

Cílené testy kontrolují zachovaný kontakt dlaně, výšku pózy, pevné nohy,
neklikatelné stíny a odmítnutí vadných dat. Samostatné nativní pixelové testy
prokazují skutečný barevný přechod, beze změny alfy, ztmavení podlahy pod
nohama a přesný původní výsledek bez metadat. Výsledky v QA rozlišují
kontrolu bez okna, skutečné pixely a normální průchod hrou.

## 6. Předání

Technické a výtvarné výsledky a časovaná ukázka patří do
[QA záznamu](../qa/carpenter-sawmill-spatial-v1/README.md).
Tato oprava netvrdí dodání nových směrových animací ani schválení celé sady.
