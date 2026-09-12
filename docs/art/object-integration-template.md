# Implementace objektu: <název a verze>

Datum: <YYYY-MM-DD> · ID: <object_id> · typ: <budova / strom / dekorace / jednotka / jiný>
Stav: <zadání / výroba / zapojeno / ověřeno / k opravě>.

Kopírovat do `docs/art/briefs/<object-id>-<version>-integration.md` a opravit
relativní odkazy. Postup: [object-implementation-workflow.md](object-implementation-workflow.md).
QA: [object-qa-template.md](object-qa-template.md). U budovy doplnit odkaz
na její [výtvarný brief](building-brief-template.md); jeho obsah neopisovat.
Nevyplněno znamená neověřeno. N/A vždy doplnit důvodem. Čísla z chatrče
jsou příklady, nikoli předvyplněné hodnoty dalšího objektu.

## 1. Co je zadáno a odkud bereme data

- Požadované chování a konkrétní viditelná změna:
- Již autorizovaný rozsah; případné nevyřešené zadání:
- Existující objekt / nová funkce; další dotčené objekty:
- Katalog, simulační zdroj stavu, aktuální verze footprint/save:
- Výtvarný brief a verze směru; skutečně schválená vlastní reference nebo „není“:
- Stavová grafika v rozsahu úkolu; rezervované budoucí vrstvy:
- Referenční zjištění: zdroj/verze/cesta, konkrétní naměřený údaj:
- Co je měření, co vlastní návrh a co dosud odhad:

## 2. Geometrie a registrace

| Údaj | Hodnota a jednotka | Zdroj / důkaz | Stav ověření |
|---|---|---|---|
| Mapová kotva a kolize / maska | <...> | <...> | <...> |
| Práh / kořen / chodidla a výšková projekce | <...> | <...> | <...> |
| Venkovní vstup, volná pole a průchod | <... nebo N/A> | <...> | <...> |
| Referenční člověk a rozměr objektu při 1× | <world px> | <...> | <...> |
| Skutečný canvas | <šířka × výška source px> | <soubor> | <...> |
| Společná obrazová kotva | <x,y source px; význam> | <...> | <...> |
| Měřítko zdroj → svět | <world px / source px> | <...> | <...> |
| Ořez a trim offset každé vrstvy | <source px / bez ořezu> | <...> | <...> |
| Alfa obal a práh měření | <min,max; max výlučné/včetně> | <...> | <...> |
| Samostatný bod řazení | <souřadnice, prostor, vzorec, důvod> | <...> | <...> |
| Společný bod stínu / půdorys stínu | <...> | <...> | <...> |
| Popisek, ukazatel postupu a další UI | <souřadnice a prostor> | <...> | <...> |
| Zemní a střešní přesahy odděleně | <směr/world px/volná pole> | <snímek> | <...> |

- Podklad s předem určenou maskou/kolizí, vstupem a měřítkem předaný při tvorbě:
- Kontrola prvního konceptu nad tímto podkladem před výrobou variant:
  <datum/snímek; kontakty uvnitř obsazené země, střešní přesahy zvlášť;
  opravené odchylky; odkaz na brief místo duplikace měření>
- Změna obrazu při změně skutečné výšky země:
- Stabilita kotvy a řazení napříč fázemi / směry / klipy:
- Důkaz, že pomocná hloubka neposouvá kontakt, kolizi ani příjemce stínu:
- Výsledek zkoušky na hraně vyvýšeného základu ještě před výrobou celé sady:

## 3. Fáze, vrstvy a pravdivé zdroje stavů

Stavební část pro nestavěný objekt: <N/A a důvod, nebo vyplnit>.

| Fáze / klip / varianta | Zdroj simulačního stavu | Masters/masky/snímky | Počet změn a hranice | Podmínka konce |
|---|---|---|---|---|
| <...> | <soubor/pole/událost> | <...> | <...> | <...> |

- Počet grafických změn a výchozí stav zvlášť; zdroj požadovaného počtu:
- Trvání, dělení fází, způsob zaokrouhlení a nezávisle stanovené hraniční vzorky:
- Stav bez práce, srovnávání, dodávka materiálu, pauza a poslední krok:
- Skutečné dokončení / povolení produkce; rozdíl od posledního obrazu:
- Logické pořadí částí a odstranění dočasných prvků v průhledných místech:
- U směrů/animací: orientace, počet snímků, výdrže, kořen/chodidla, vazba na pohyb:

| Vrstva / indikátor | Statická / proměnlivá | Přesný zdroj dat | Kotva a pořadí | Právo zobrazení | Dodána / jen návrh |
|---|---|---|---|---|---|
| <...> | <...> | <... nebo N/A> | <...> | <vlastní/cizí, mlha, interiér> | <...> |

- Množství a kapacita; nula, jednotlivé stupně a změněná kapacita:
- Skutečné předání/odebrání versus rezervace a nesené zboží:
- Přítomnost uvnitř versus přidělení, povolená práce a skutečná činnost:
- Neutrální skrytý stav, který netvrdí „nula“ nebo „nikdo uvnitř“:

## 4. Produkční soubory a převod

- Vlastní masters a obrazové vstupy; externí pohledové/stylové reference zvlášť,
  včetně jejich případného skutečného použití v zadání generátoru:
- Nástroj, známý model/verze, skutečná zadání a datum:
- Uchované masters, odmítnuté pokusy a důvod odmítnutí:
- Přímá RGBA / technické pozadí; naměřené pozadí a pravidla exportu alfy:
- Kontrola otvorů a okrajů na tmavém/světlém/herním podkladu:
- Formát masky, platné indexy, význam nuly, převedení průhledných míst:
- Přesný exportní nástroj a parametry pro tento objekt:
- Reprodukovatelný export; původní zdroje zůstaly zachované:

| Soubor / metadata | Role | Rozměr/formát | SHA256 | Skutečný runtime čtenář |
|---|---|---|---|---|
| <...> | <...> | <...> | <...> | <soubor/funkce; nebo dosud nezapojeno> |

Tato tabulka není runtime schema. Zapsat přesné názvy polí podporované
aktuálním čtenářem, jednotky a povinné hodnoty. Nepředpokládat, že změna
ID v manifestu chatrče automaticky aktivuje nový objekt.

## 5. Napojení a kompatibilita

- Běžná cesta spuštění / vytvoření / načtení objektu:
- Dotčená větev rendereru a případné sdílené části:
- Metadata, která jsou skutečně čtena; vlastní konstanty, které zbývá parametrizovat:
- Cache a její klíč (objekt/verze), náběh a naměřená paměť při potřebném rozsahu:
- Registrace obrázku, hloubkové řazení a shodná pravidla při klikání:
- Zachování výběru obsazené země a alfa testu mimo ni:
- Pozemní výběr, UI, tónování, stíny a mlha:
- Chybějící/neplatné podklady; požadované chování a ověřený fallback:
- Starší verze objektu / save a ověřená cesta načtení:
- Běžné importy; samostatný exportní balík pouze pokud je součástí dodávky:
- Jak byla použita nová herní instance po úpravě assetů:

## 6. Předání

- Vyplněný QA záznam a přesné ověřené assety:
- Skutečná herní ukázka / animace:
- Dokončené změny a uživatelský způsob použití:
- Zbývající konkrétní nedostatky a jejich dopad:
- Technický výsledek:
- Vizuální výsledek:
- Uživatelské schválení konkrétního assetu a schválení etalonu sady zvlášť:
