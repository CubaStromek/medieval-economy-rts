# Kontrola a přejímka objektu — šablona

Verze šablony **1.0**, **2026-09-10**. Zkopírujte do QA záznamu konkrétního
objektu a vyplňte hranaté závorky. Tento soubor sám nehlásí provedené testy.
Při kopírování do `docs/art/qa/<object-id>-<version>/README.md` opravte
relativní odkazy podle nového umístění.
Použijte [společný postup](object-implementation-workflow.md) a
[integrační plán](object-integration-template.md); pro budovy také
[výtvarný manuál](building-style-guide.md) a jejich konkrétní brief.

Výsledek každé kontroly: **prošlo / selhalo / neověřeno / N/A — důvod**.
N/A znamená, že daná vlastnost objektu nepřísluší; chybějící kontrola je
neověřeno. Stavební fáze nejsou povinné pro strom, rekvizitu ani jednotku.
Počty stavů, rozměry a testové výsledky vyplňte znovu pro tuto dodávku.

## 1. Co přesně se ověřuje

| Údaj | Vyplnit |
|---|---|
| Objekt, ID, druh | [budova / strom / statická rekvizita / jednotka; ID] |
| Rozsah změny | [nový objekt / revize kresby / animace / oprava integrace] |
| Datum a ověřující | [YYYY-MM-DD, jméno/agent] |
| Brief, integrační plán, styl | [odkazy a konkrétní verze] |
| Běžná herní scéna a mapa | [cesty, způsob vzniku objektu ve hře] |
| Ověřený kód | [revize + identifikace dotčených necommitnutých změn] |
| Prostředí | [Godot, OS, renderer/GPU, velikost okna, zoom] |
| Původ podkladů | [vlastní zdroje, autor/nástroj, skutečný prompt/reference; doložené použití] |
| Přesné soubory | [master, atlas/vrstvy/masky, manifest a SHA-256; lze odkázat na seznam otisků] |
| Importovaná verze | [datum importu, shoda vstupů s otisky a snímky; jak vyloučena stará běžící instance] |

U klíčových tvrzení rozlišujte **změřeno** (postup a výsledek),
**doloženo zdrojem** (odkaz/verze, nemusí platit pro tuto instanci) a
**neověřeno**. Převzatý údaj ani zadání generátoru nejsou měřením exportu.

| Měřený kontrakt | Hodnota, jednotky, zdroj důkazu |
|---|---|
| Canvas/atlas a skutečné viditelné meze | [px, použitý práh alfy] |
| Měřítko zdroj → svět | [poměr; srovnávací herní objekt] |
| Mapová poloha a fyzicky obsazená zem | [maska/kolize nebo výslovně neblokující dekorace] |
| První koncept před výrobou variant | [datum a snímek nad určenou maskou; měřené zemní kontakty uvnitř ní, volný vstup, střešní přesahy zvlášť; N/A při změně bez nové kresby] |
| Obrazový pivot a kontakt se zemí | [práh / kořen / nohy / základna; zdrojové i herní souřadnice] |
| Bod řazení a vrstvy | [samostatná kotva, převod, chování při změně stavu/pohybu] |
| Přesahy a další kotvy | [rozsah; vchod, náklad, zásoby, popisky, efekty podle druhu objektu] |

## 2. Ověření běžnou herní cestou

**Reprodukce:** [menu → nová/načtená hra → mapa → běžný příkaz nebo nalezení
objektu → skutečný průběh děje → výběr/inspektor → uložení/načtení → pokračování].
Uveďte konkrétní souřadnice, objekty a očekávaný výsledek, aby šel pokus zopakovat.

**Skutečně vykonaná simulace:** [co provedli herní pracovníci, pohyb, růst,
stavba, těžba, interakce; případně N/A s důvodem].
**Uměle nastavené QA stavy:** [seznam, účel a omezení]. Kontaktní arch nebo
samostatná ukázková scéna doplňují běžnou hru; nedokládají její úplnou cestu.
Testovací pozice: [izolovaný soubor/svět]; hráčovy uložené hry se nepřepisují.

## 3. Společné kontroly ve hře

Ke každému řádku doplňte výsledek a konkrétní snímek/test. Snímek skutečně
prohlédněte; úspěšný export souboru není vizuální kontrola.

| Kontrola | Scénář a očekávání | Výsledek a důkaz |
|---|---|---|
| Čitelnost a měřítko | Běžný zoom, oddálení, detail a okolní osada; silueta, funkce, proporce vůči člověku/okolí | [zoomy, snímky, nález] |
| Alfa a filtrace | Skutečná průhlednost, vnitřní otvory, světlé/tmavé pozadí, přiblížení; bez barevného lemu či šachovnice | […] |
| Kontakt se zemí | Rovina, zvýšená rovina, povolený svah a přilehlý svah; kořeny/nohy/patky sedí, přesahy neplavou ani neblokují volný průchod | […] |
| Řazení a terén | Viditelný spodek nepřemaluje rovná zem; správné překrytí před/za jiným objektem a vyvýšeným terénem | […] |
| Kotvy a vrstvy | Změny stavů/směrů, ořezů a vrstev drží správný pivot a pořadí; žádné skoky obrazu či nákladu | […] |
| Klikání a výběr | Skutečné neprůhledné pixely včetně spodku, průhledné okraje mimo obsazenou zem, povolená půdorysná políčka, překryté objekty; obrys/popisek nezakrývá kresbu | […] |
| Mlha a soukromí | Vlastní/cizí objekt, viditelné/prozkoumané/neznámé místo; skrytá osoba, aktivita či inventář neunikají ani při kliknutí | […] |
| Světlo a stíny | Den, soumrak, noc; správné tónování, stín podle pravidel objektu bez zdvojení, čitelné UI | […] |
| Čas a skutečný stav | Pauza/rychlost, neaktivita a změny dat; kreslení nic nesimuluje a neukazuje neexistující stav | […] |
| Uložení a pravidla | Uložení/načtení relevantních mezistavů a pokračování; zachovaná poloha, pohyb, kolize, zásoby a pravidla; starší podporované varianty | […] |
| Běžná scéna a výkon | Reálný počet sousedních objektů, posun kamery/zoom; žádné chybějící podklady, chyby skriptů nebo zbytečné nové sestavování terénu | […] |

Opravené řazení samo neprokazuje správné usazení patek na svahu. Vadu kresby
nezamaskujte ořezem terénu, posunem fyzické výšky či automatickým rozšířením
kolize. Případná výslovně zadaná změna půdorysu má vlastní důkazy pro kolize,
průchod a starší pozice; není precedens pro další generované objekty.
Měřené přesahy posuďte i na sousedních skutečně průchozích políčkách.

## 4. Použitelné větve podle objektu

Vyberte příslušné větve; ostatní označte N/A. Počet potřebných stavů určuje
aktuální integrační plán a simulace, nikoli tato šablona.

| Větev | Konkrétní pokrytí k vyplnění | Výsledek a důkaz |
|---|---|---|
| Budova — stavba | [příprava země, dodávky, skutečná práce, všechny požadované kroky a hranice fází, dokončení, zastavení/obnovení] | […] |
| Budova — provozní vrstvy | [jen implementované zásoby/přítomnost/práce; každý nezávislý zdroj, nula až kapacita, fyzické předání; nevydávat přidělení za pobyt uvnitř] | […] |
| Strom | [druhy a růstové stavy, kořen, těžba/zánik a případná animace podle existujících pravidel] | […] |
| Statická rekvizita | [varianty, umístění, blokující/neblokující chování, případná interakce; stavba a pohyb jen pokud existují] | […] |
| Jednotka | [všechny dodané směry/klipy, přechody, rychlost a interpolace, kontakt nohou, nesený náklad, interiér/skrytí podle existujících pravidel] | […] |

## 5. Důkazy a přesný rozsah testů

Příkazy ověřte proti aktuální [testovací dokumentaci](../../tests/README.md).
Test načítá skutečný projekt, jeho data a produkční cestu vykreslování.
Rozlišujte výpočty bez okna, nativní pixely a ruční prohlídku; úspěch jedné
kategorie se nepřenáší automaticky na ostatní.

| Běh/kontrola | Datum, přesný příkaz či kroky | Skutečné pokrytí | Výsledek, log/snímky |
|---|---|---|---|
| Zaměřené testy | […] | [jména případů; ověřené/požadované stavy, směry, přechody] | [prošlo / celkem; vynechané případy a chyby] |
| Dotčené regrese / úplná sada | […] | [co bylo skutečně spuštěno a proč] | [aktuální počet, návratový kód, log] |
| Nativní grafické kontroly | […] | [renderer, konkrétní pixely/překryvy, zoomy] | […] |
| Prohlídka běžné hry | […] | [herní cesta a prohlédnuté soubory] | […] |

Při opravě ořezu, alfy, mlhy či světla popište také **nezávislý očekávaný
výsledek**: [např. stejný pixel téhož spritu v nezakrytém kontrolním vykreslení
se shodným měřítkem a osvětlením]. **Pozitivní kontrola:** [jak bylo ověřeno,
že se správný objekt skutečně vykreslil a kontrolovaný pixel/stav byl dosažen].
Uveďte souřadnice, toleranci a výsledek. Prázdný obraz, neprovedená větev nebo
porovnání pomocné hodnoty se sebou samou nesmějí dát zelený výsledek.

Manifest snímků: [cesta; soubor → stav/tick → mapa/poloha → zoom/světlo/mlha
→ hash ověřených podkladů]. Video/GIF: [zdrojové snímky a skutečné či
ilustrační tempo]. Výběr několika obrázků neoznačujte za ověření všech stavů.

## 6. Výsledek této verze

| Rozhodnutí | Vyplnit samostatně |
|---|---|
| Technická integrace | [prošla / selhala / neúplná; datum a rozsah] |
| Provedená vizuální kontrola | [kdo, které herní snímky, konkrétní nálezy] |
| Vizuální přijetí uživatelem | [neuděleno / přijato / k přepracování; datum, odkaz na výslovné vyjádření a přesnou verzi/snímky] |
| Otevřené vady a neověřené oblasti | [dopad, důkaz, další krok; případně žádné doložené vady v uvedeném rozsahu] |
| Použití jako společný etalon | [ano pouze v doloženém přijatém rozsahu / ne] |

Nevyřízené vizuální přijetí není obecný pokyn zastavit již zadanou integraci.
Technicky úspěšný pilot však sám nezakládá schválení vzhledu nebo etalonu
pro další sadu. Při další revizi určete dotčené důkazy a obnovte příslušné
testy/snímky; historická čísla nepřepisujte jako výsledky nové verze.
