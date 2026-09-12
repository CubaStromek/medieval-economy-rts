# Výtvarný manuál budov

Verze výtvarného návrhu: **0.2, 2026-09-09** · technický stav doplněn
**2026-09-10** · projekt Medieval Economy RTS.

## 1. Rozhodnutí a stav

**Požadavek uživatele z 9. 9. 2026:** nové budovy mají být inspirované grafickým
stylem původního Knights and Merchants, ale mají být naše, s vlastním duchem.
Všechny další budovy se mají tvořit podle stejných pravidel.

Tento dokument je společný předpis pro návrh, tvorbu a přejímku budov.
Proces, původnost a technické hranice platí odteď. Níže navržená konkrétní
architektura a paleta jsou **pracovní směr**, nikoli uživatelem schválený obraz.
První vlastní schválená budova zatím neexistuje. Uživatel následně vybral jako
první skutečný koncept **dřevorubeckou chatu**; [lesnická chata](briefs/forester-hut-v1.md)
zůstává pozdějším nevyrobeným návrhem. Původní
[dřevorubec v3](briefs/lumber-hut-v3.md) zůstává RGB konceptem.
Na výslovný požadavek uživatele z něj dne **2026-09-10** vznikla
[stavební sada v1](briefs/lumber-hut-construction-v1.md): vlastní RGBA
a 12 + 21 kroků zapojených v běžné hře. [Herní QA](qa/lumber-hut-construction-v1/README.md)
odděluje ověřenou integraci od nedoladěných kontaktů patek a proporcí dveří.
Pilot není schváleným etalonem celé sady. Výtvarný směr v0.2 se tím nemění.
Obecnou produkci a integraci vede [společný postup objektů](object-implementation-workflow.md).

**Upřesnění uživatele z 9. 9. 2026 — závazné od v0.2:**

- Zachovat mírně izometrický/prostorový dojem budov jako v KaM Remake:
  vyvýšený pohled **zpředu mírně zleva**, vidět čelo, část střechy a menší
  **levý bok**. Nesmí to být čistě čelní nárys. V následném upřesnění uživatel
  požádal o **výraznější pohled shora** a kontrolu originální KaM budovy:
  horní plochy střechy a pracovního prostoru musí být čitelné, ne pohled od země.
  Konkrétní elevaci porovnat s prohlédnutou referencí; zůstává ke kalibraci.
- Při návrhu každé budovy už počítat s budoucím zobrazováním skutečných zásob
  a informace, zda je uvnitř jednotka. Připravit místo a vrstvy, ne předstírat,
  že koncept již takový systém implementuje.
- Tato oprava nahrazuje příliš čelní výklad v0.1. Čtvercová mřížka terénu
  neurčuje, že fasáda musí být kreslená bez bočního pohledu. Změna výtvarného
  zadání nemění projekci enginu, mapy, uložené půdorysy ani vstupy.

Výtvarný cíl jednou větou:

> Malovaná řemeslnická osada na lesnatém pomezí: přívětivá, pracovitá,
> ručně postavená z místních materiálů, s dobře čitelnou funkcí každého domu.

## 2. Co přebíráme jako inspiraci a co tvoříme vlastní

Z KaM: mírně vyvýšený šikmý pohled na budovy, čitelnost při malé velikosti,
jasné objemy střech, přírodní barvy, pocit obývané středověké osady a názornost
pracovního procesu. Pro naši sadu uživatel určil pohled zpředu mírně zleva.

Naše: návrh stavebních hmot, skladba střech a přístřešků, konstrukční detaily,
rozmístění oken a pracovního vybavení, znaky profesí a drobné příběhy používání.
Půdorys a vchod určuje hra; jejich zachování neznamená obkreslit původní dům.

Nedělat originální sprite s pouhou změnou barvy, přeostřením nebo zvětšením.
Nepoužívat jednu původní budovu jako kompoziční šablonu každého nového domu.
Samotný počet změněných detailů není zárukou původnosti. Kontrolujeme dojem
z celého návrhu: měl by působit jako náš dům, ne jako restaurovaný KaM asset.

Originální soubory z KaM zůstávají pouze oddělenou referencí. Do distribuované
grafiky je automaticky nepřibalovat; vlastní díla mají vlastní záznam původu.
Tyto zásady jsou výtvarné a projektové, nikoli tvrzení o právním vypořádání
libovolné předlohy.

## 3. Společný stavební jazyk

Navržené prvky, které se vracejí napříč osadou:

- Nízká podezdívka z teplého nepravidelného kamene, čitelná při dotyku s terénem.
- Nosné dřevěné trámy a praktické výplně z prken nebo světlé hlíny/omítky.
- Střechy s rozumným přesahem, jednoduchými podpěrami a viditelnou konstrukcí.
- Menší pracovní přístřešek, výdejní pult nebo dvorek podle funkce domu.
- Střídmé opravy: náhradní prkno, ošlapaný práh, ztmavnutí kolem ohniště.
- Jeden malý řemeslnický znak, pouze tam, kde něco sděluje. Žádné povinné
  dekorativní vlajky na každém domě.

Ne všechny stavby musejí být roubenky. Kovárna potřebuje více kamene, statek
větší střechu a vojenská budova pevnější konstrukci. Rodinu spojuje zpracování
materiálu a řemeslná logika, nikoli opakování stejné fasády.

Budovy jsou lehce nepravidelné, ale stojí věrohodně. Žádné extrémně prohnuté
pohádkové střechy, obří fantasy ozdoby, plastový mobilní vzhled nebo fotorealismus.
Historická uvěřitelnost má přednost před archeologickou přesností.

## 4. Co je pevné a co se smí měnit

| Společné pro celou sadu | Individuální pro budovu |
|---|---|
| Projekce, měřítko člověka a registrační princip | Půdorys z katalogu a prostorové uspořádání |
| Malované materiály, kontrast a ostrost hran | Poměr dřeva, kamene, omítky a krytiny |
| Neutrální světelná modelace a oddělené zemní stíny | Funkčně zdůvodněná silueta a pracovní přístřešek |
| Hustota detailů při skutečné herní velikosti | Jedno hlavní a nejvýše dvě podpůrná profesní vodítka |
| Omezená přírodní paleta a zacházení s akcentem | Konkrétní malý akcent a stopy používání |
| Průhlednost, kotva, QA a záznam verze | Jen výslovně navržené animace / varianty |
| Příprava oddělených stavových vrstev a pravdivá data | Profesně vhodný skladovací prostor a umístění indikátoru |

Povolání musí být čitelné z **tvaru**, potom z **vybavení**, až nakonec z barvy
a drobností. Dům musí zůstat rozpoznatelný i v odstínech šedi.
Stejná pravidla neznamenají stejné domy.

## 5. Paleta a materiály — návrh ke kalibraci

Výchozí rodiny základních odstínů, nikoli přebarvovací filtr ani uzavřená paleta:

| Materiál | Výchozí odstíny sRGB | Zpracování |
|---|---|---|
| Nosné / starší dřevo | `#594331`, `#856447` | Široké tahy a několik spojů; ne kresba každého vlákna |
| Čerstvé dřevo | `#B29261` | Lokální pracovní akcent, ne celá zářící fasáda |
| Teplý kámen | `#807C69`, `#A49B80` | Několik nestejných bloků, matný povrch |
| Hliněná výplň / omítka | `#C2B38D` | Jemná variace, nezářivě bílá |
| Šindele | `#6B6046`, `#7A7651` | Klidné skupiny řad, mech jen místy |
| Sláma / rákos | `#A28A53` | Sjednocené objemy, několik svazků |
| Pálená krytina | `#925D47` | Tlumená, převážně u zděných a významnějších domů |
| Železo | `#555D5A` | Nízký lesk, omezené světelné hrany |
| Drobný akcent | `#627449` nebo `#526E72` | Vegetace, látka či značka, nepřekrývá materiál |

Kontrolovat vedle [terénu V1](../modern-terrain-textures.md), našich stromů
a jednotek. Odstíny budou v různých denních dobách přirozeně tónované hrou.
Hodnoty `color` v dnešním katalogu jsou převážně barvy placeholderů, nikoli
automaticky finální paleta této sady.

Venkovské/lesní stavby: převážně dřevo, šindel nebo rákos.
Horká výroba: více kamene, lokální saze a technické zařízení.
Občanské/vojenské stavby: větší pevné objemy, kámen a střídmá pálená krytina.
Výjimku odůvodnit v briefu; neměnit styl kvůli jedné efektní budově.

## 6. Čitelnost a detail

Pořadí práce: silueta → velké materiálové plochy → konstrukce → profesní zařízení
→ několik drobných stop života. Detail nesmí opravovat nerozpoznatelnou siluetu.

Při 1× musí být patrné dveře, střecha a hlavní pracovní vybavení.
Při 0.75× zůstane funkce rozeznatelná bez nápisu; při větším oddálení alespoň
hlavní rodina/silueta. Při 2.4× nemají být patrné rušivé generované vady.
Mikrodetail, který se při 1× mění v šum, odstranit či sjednotit do ploch.

Žádný silný černý obrys kolem celého domu. Hrany jsou malované, čisté, ale
ne vektorově sterilní. Vyšší rozlišení slouží příjemnému přiblížení, nikoli
jinému měřítku nebo plošnému přidávání kontrastu.

Nenamalovat do budovy pracovníka ani obsluhu. Jednotky vykresluje hra.
Profesní rekvizita nesmí předstírat množství skutečných zásob, hotový výrobek
nebo aktivní práci, které simulace právě nemá. Dekoraci odlišit od stavových prvků.

### Stavová připravenost od prvního konceptu — v0.2

Každý brief musí vyhradit čitelný prostor pro zásoby a nezávislý stav přítomnosti.
Je to výtvarný a datový kontrakt pro budoucí implementaci, nikoli tvrzení, že
renderer dnes umí tyto bitmapové vrstvy. Pro budovu bez skladovaných produktů
zapsat zásoby jako N/A s důvodem; nevymýšlet nové herní zboží.

**Statický základ** obsahuje dům, prázdný skladovací prostor a trvalé vybavení.
Proměnlivé klády, pytle, výrobky, jednotky, oheň, pracovní kouř či svítící stavová
okna nejsou napevno součástí této kresby. Případná konceptová ukázka naplnění
musí být označena jako ukázka, nikoli označena za hotovou oddělenou vrstvu.

| Stav | Zdroj / pravidlo |
|---|---|
| Fyzicky uskladněné množství | Konkrétní inventář budovy podle role; nikdy počet viditelných dekorací |
| Kapacita | Aktuální definice budovy/simulační pravidlo, ne konstanta odhadnutá výtvarníkem |
| Jednotka uvnitř | Skutečné `inside_building_id == building.id` |
| Přidělený pracovník | `home_id` / `workplace_worker()`; není totéž co fyzická přítomnost |
| Provoz / činnost | Samostatný povolený a skutečně vykonávaný stav; není odvozen z přítomnosti |
| Spánek / přerušení práce | Člověk může zůstat uvnitř, ale nepracovat |

**Ověřený příklad dřevorubce, 2026-09-09:**

- ID `lumber_hut`, výrobek `log`, množství
  `building["outputs"].get("log", 0)`; dnešní `output_capacity` je **6**.
  Nečíst `storage` (sklad), `inputs` ani globální součet surovin.
- Kláda v `worker["carrying"]` ještě není zásoba chaty. Při dokončení těžby
  ji nese pracovník; do `outputs` přibude až při skutečném odevzdání doma.
  Při skutečném vyzvednutí nosičem se ze zásoby odečte.
- Nezapočítávat příchozí rezervace, klády na cestě ani stromy v krajině.
  Nula znamená opravdu prázdné místo. Pro nynějších šest kusů plánovat
  jednotlivé čitelné pozice; například stabilní skladbu 3 + 2 + 1.
  Výběr počtu vždy vychází z aktuálních dat. Pokud se kapacita změní, výslovně
  upravit vizuální mapování; neskrýt přebytek tichým ořezáním na šest.
- Přítomnost znamená alespoň jednoho oprávněně zobrazitelného obyvatele
  z `world.workers` s `inside_building_id == building["id"]`.
  Přesný počet uvnitř lze počítat zvlášť; brief musí říct, zda ukazuje počet,
  nebo pouze ano/ne.
- Dřevorubec může být přidělený a přitom těžit venku, jíst jinde nebo cestovat.
  Naopak pozastavený či spící pracovník může být uvnitř. Pohyb ke dveřím
  nesmí přepnout přítomnost dřív, než ji přepne simulace.

**Vizuální plán:** prázdný nízký skladovací stojan/přístřešek na viditelné straně,
mimo skutečný vstup; samostatně přidávané kusy zásob a malé přepínatelné znamení
přítomnosti u dveří. Přítomnost nevyjadřovat automaticky kouřem, pracovním ohněm
nebo postavou napevno v okně. Přesné číslo se kreslí až samostatným UI prvkem,
pokud jej brief požaduje; není texturou střechy nebo namalovanou cedulí.

Povinně plánovat `door_threshold`, `stock_origin`, pojmenované pozice kusů
zásob, `occupancy_indicator` a případně `stock_count_label`. Každá kotva má
v produkci měřené souřadnice ve společném canvasu, stejný pivot a měřítko.
Nezměřené konceptové kotvy označit jako návrh, ne pixelově hotová metadata.

Doporučené vnitřní pořadí vrstev: prázdný dům/zadní část skladovacího přístřešku
→ zásoby → přední sloupky a lišty překrývající zásoby → dveřní stavový prvek.
Rozdělit překrývající architekturu, pokud by jinak zásoby ležely přes sloupky.
Pořadí objektů vůči lidem, stromům a terénu zůstává běžné herní; nedávat zásoby
ani přítomnost na globální vrstvu nad mlhou. Zemní stín je samostatný.

**Mlha a soukromí stavů:** známá/prozkoumaná silueta cizího domu není oprávnění
ukazovat jeho živé zásoby nebo skryté obyvatele. Při zapnuté mlze dnešní HUD
skrývá inventář cizí budovy a fyzické cizí obyvatele; budoucí vrstvy mají
zachovat tuto politiku. Pro vlastní budovu lze číst vlastní stav, ale obrazové
vrstvy musí projít stejnou mlhou a zakrýváním jako dům. Nikdy neodvozovat právo
zobrazit skryté osoby jen z `_fog_entry_visible("building", ...)`: tento test
stačí už pro prozkoumaný půdorys. Změna informačních pravidel není součástí
grafického zadání. Přesný viditelný/schovaný stav uvést v briefu. Neznámé/skryté údaje nesmějí
být prezentovány jako potvrzená nula nebo nepřítomnost; použít neutrální stav
bez čísel a bez významu „nikdo uvnitř“.

V nedokončených domech tyto dokončené produkční vrstvy nevykreslovat; rozhoduje
`world.is_building_complete()`. Přítomnost, zásoby a činnost číst nezávisle.
Globální pauza zmrazí simulační animace, ale nesmaže zásoby ani přítomnost.
Při nočním tónování se materiál klád chová stejně jako materiál budovy;
případnou emisivní vrstvu navrhnout zvlášť a neprohlásit za implementovanou.

## 7. Technické hranice — ověřeno v projektu 2026-09-09

### Projekce a měřítko

- Zemní mřížka je osově zarovnaná **40 × 40 world px při 1×**.
- Souřadnice X rostou doprava, Y dolů; terénní výška posouvá bod vzhůru
  o **8 world px za úroveň**.
- Toto jsou souřadnice terénu/simulace, nikoli příkaz nakreslit čelní fasádu.
  **Budovu kreslit vyvýšeným šikmým pohledem zpředu zleva**: čelo
  dominantní, levý bok menší, horní plochy střechy i pracovního prostoru
  dostatečně viditelné při pohledu shora; žádná nízká oční perspektiva.
  Nepřeklopit pohled na pravý bok ani na symetrický 45° diamant.
- Podklad zůstává osově zarovnaný; výtvarné natočení nesmí otáčet mřížku,
  zvětšit obsazený půdorys ani přemístit dveře. Objem domu usadit nad skutečnou
  masku a práh; ověřit ve hře, nikoli ztotožnit PNG s obrysem zemních polí.
- Přesné číselné úhly originální ani naší kamery zde nejsou stanoveny.
  Neprezentovat obecné 30°/45° zadání jako ověřenou KaM kameru. Ověřit pohled
  obrazovým podkladem, člověkem a budoucím schváleným vlastním pilotem.
  Bez úběžníkového nebo dramatického perspektivního zkreslení.
- Běžný pracovník míří přibližně na **33 world px výšky**; některé role ovlivní
  šířkový limit. Použít skutečný sprite vedle dveří.
- Současné vektorové stěny 28 px a dveře 18 × 23 px jsou placeholder.
  Finální proporce kalibrovat pilotem, nepovýšit je na neměnný výtvarný standard.

### Půdorys, práh a přesahy

Autorita je `game/data/buildings.json` a společný footprint helper:
[technický popis](../building-footprints.md).
`#` a `E` jsou obsazená zem, `.` zůstává volná. Kotva budovy je levé dolní
pole ohraničujícího obdélníku, řádky masky běží ze severu na jih.
Venkovní vstup leží o jedno pole jižně od dveřního pole `E`.

Registrace grafiky se odvozuje od skutečného prahu:
`terrain.project_grid_position(Vector2(door_cell) + Vector2(0, 0.5))`.
Každý stav stejného domu drží identický práh a exportní měřítko.

Půdorys není rozměr PNG. Střecha a komín sahají nad podklad; transparentní okraje
se nesmějí přepočítat na jinou velikost budovy. Každý přesah označit v briefu.
Zemní zdi, ploty a neprůchozí rekvizity patří do obsazených polí. Okap smí mít
odůvodněný vizuální přesah, ale nesmí vytvářet dojem, že blokuje volnou cestu.
Prázdný roh nepravidelné masky musí zůstat herně i vizuálně použitelný.
Nevytvářet druhý zdánlivě funkční vchod, který simulace neumí použít.

**Pokyn uživatele, 2026-09-10:** další generované objekty musí rozměrově
odpovídat předem určenému půdorysu. Před generováním dodat masku, práh,
volný přístup a člověka jako měřítko; první koncept nad skutečnou mřížkou
změřit ještě před výrobou stavebních a stavových variant. Kontakty stěn,
patek a stojanů musí ležet v obsazené zemi. Střešní přesahy evidovat zvlášť.
Pokud návrh nepasuje, opravit jej před odvozením sady; nezvětšovat automaticky
herní půdorys kvůli kresbě. Rozšíření půdorysu současné dřevorubecké chaty
uživatel výslovně autorizoval jako konkrétní výjimku pro zachování hotových
obrázků a stavebních fází. Toto rozhodnutí nemění pravidlo pro další objekty
ani schválení výtvarného etalonu a nepřidává schvalovací krok.

### Světlo, vrstvy a stíny

PNG má neutrální, měkkou modelaci objemu a střídmé lokální kontaktní stíny.
Nesmí obsahovat dlouhý sluneční stín, barevný západ slunce, noční filtr,
okolní trávník ani neprůhledný obdélník/„průhlednou“ šachovnici.

Denní tónování i pohyblivý pozemní stín zajišťuje hra. Dnešní stín budovy je
zjednodušený podle půdorysu, nikoli přesný obrys komína a střechy.
Statická bitmapa se celá tónuje; plně fyzikální přepočet osvětlení jejích stěn
zatím není implementován. Nepředstírat, že tento manuál takový systém zavádí.

Zachovat řazení terénních a objektových řad, zakrývání terénem, stromy a lidmi,
viditelnost podle mlhy i skrývání obyvatel uvnitř. Bitmapová budova nesmí
obcházet dnešní výběr objektů, mlhu ani stavová pravidla.

Klikací tvar musí odpovídat nové viditelné siluetě. Vektorové budovy používají
své polygony; bitmapová chatrč od 2026-09-10 zachovává výběr obsazené země
a mimo ni testuje skutečnou alfu se shodným terénním zakrytím jako při kreslení.
Stejný princip ověřit u další bitmapové budovy. Celý transparentní obdélník
PNG není správná klikací oblast. Pozemní obsazená maska zůstává beze změny.

### Výstupní soubory — nový produkční předpis

- Bezeztrátové RGBA PNG, ověřená skutečná alfa, bez pozadí a nápisů.
- Výchozí master **4× herní měřítko** (160 zdrojových px na jedno 40px pole);
  skutečný výsledek generátoru změřit a kalibrovat. Výjimku zapsat.
- Uchovat zdrojový master; nikdy neodvozovat měřítko jen od šířky celé bitmapy.
- Zapsat skutečné rozměry, viditelné meze, práh v px, měřítko zdroj→world,
  případný výřez a povolené přesahy.
- Další stavy/animace mají společnou registraci; jejich výřezy nesmějí způsobit
  poskakování domu. Mipmapy a filtrování ověřit ve hře včetně alfa okrajů.
- Oddělení statického těla od proměnlivých zásob/přítomnosti se plánuje od
  konceptu. Konkrétní soubory, masky a animační/emisivní vrstvy jsou až výstup
  příslušné produkce; dnešní renderer tím nové schopnosti nezískává.
  Nové runtime vrstvy implementovat jen v rozsahu aktuálního úkolu.
- Doporučené budoucí umístění: `game/art/buildings/<building_id>/v1/`.
  Master a původ evidovat vedle briefu nebo odkazem na projektový zdroj.
  Bez výslovného pokynu nevytvářet přesun existujících assetů.

První herní integrace může začít dokončenou statickou budovou a stávajícím
lešením, ale musí mít připravený prázdný základ a plán stavových vrstev. To
není schválení dynamických stavů, pokud ještě nebyly dodány a ověřeny.
Při zemi se stále nejdříve srovnává terén; v této fázi nesmí vyrůst střecha.
V plné sadě plánovat fáze srovnání → stavba → dokončený dům. Schválení statického
pilotu není automatické schválení neexistujících animačních či stavebních stavů.

## 8. Jednotný postup pro každou budovu

Podrobné výrobní a implementační kroky, rozlišení fyzické kotvy a hloubky,
diagnostiku chyb a šablony vede [společný postup objektů](object-implementation-workflow.md).
Tento manuál zůstává autoritou pro výtvarný směr a stavové zásady budov.

1. **Brief:** zkopírovat [šablonu](building-brief-template.md), vyplnit ID,
   roli, masku, práh, pohled zleva, pracovní motiv, materiály a odlišení od
   příbuzných budov. Vyplnit zdroje stavů, kapacitu, prázdný skladovací prostor,
   vrstvy, kotvy a pravidla viditelnosti ještě před kresbou.
2. **Podklad:** připravit stejnou herní mřížku, výškový základ a referenčního
   člověka. Od schválení pilotu přidávat i jeho vlastní referenční obraz.
3. **Silueta:** zkontrolovat čitelnost, vstup a kompozici ještě bez mikrodetailů.
   První koncept usadit na skutečný podklad a změřit, že všechny zemní
   kontakty vejdou do určené masky při zachovaném měřítku a přístupu.
   Případnou opravu dokončit před odvozováním celé stavební/stavové sady.
4. **Artwork:** použít společný základ zadání plus konkrétní brief; při AI tvorbě
   používat příslušný obrazový postup a archivovat skutečný prompt/reference.
   Text zadání sám nezaručuje konzistentní kameru, alfu ani velikost.
5. **Dočasná integrace:** nový obraz nejprve zkoušet na jedné budově.
   Zachovat gameplay, vstup, výstavbu, výběr, mlhu a denní cyklus.
6. **Přejímka:** uložit skutečné herní záběry a výsledky checklistu.
   Nezaměňovat koncept, render a nasazený sprite.
7. **Schválení:** první pilot předložit uživateli. Teprve jeho výslovně schválený
   herní výsledek bude obrazovým etalonem celé sady.
8. **Rozšíření:** ověřit systém druhou odlišnou stavbou, například pekárnou.
   Potom postupovat po menších rodinách; neprodukovat všech 30 domů najednou.

U dalších domů není třeba znovu vymýšlet celý styl. Odchylky od schváleného
základu musí být pojmenované. Zásah do kamery, proporcí celé sady nebo zásadní
palety vyžaduje novou verzi manuálu a potvrzení směru; nikdy tichý drift.

## 9. Přejímací checklist

- [ ] Návrh má vlastní architektonickou identitu a doložený původ.
- [ ] Odpovídá verzi manuálu a schváleným vlastním referencím.
- [ ] Vyvýšený předolevý pohled: čelo + menší levý bok + čitelné horní plochy,
  nikoli čelní nárys nebo nízká oční perspektiva.
- [ ] Silueta a hlavní pracovní motiv jsou čitelné bez textu i v šedé škále.
- [ ] Funguje vedle terénu V1, stromu, 33px člověka a příbuzné budovy.
- [ ] Půdorys, dveřní práh, vnější vstup a volné rohy odpovídají hře.
- [ ] První koncept byl změřen nad určeným půdorysem před výrobou variant;
  zemní kontakty jsou uvnitř masky a střešní přesahy mají samostatný záznam.
- [ ] Rozměry, pivot, průhlednost, filtrace a přesahy jsou skutečně změřené.
- [ ] Ověřeny 0.75×, 1×, 2.4× a celkový přehled aktuální mapy.
- [ ] Ověřeny den, soumrak a noc bez dvojitého pozemního stínu.
- [ ] Ověřena rovina i vyvýšený srovnaný základ; žádné plavání nad terénem.
- [ ] Ověřeno překrytí osobou/stromem, klikání na siluetu a skrz prázdné okraje.
- [ ] Zásoby a přítomnost mají samostatné zdroje, vrstvy a společné měřené kotvy.
- [ ] Nulová zásoba nechává prázdný prostor; převzetí/odebrání sleduje skutečné předání.
- [ ] Přítomnost není zaměněna za přidělení pracovníka, práci, spánek nebo provozní pauzu.
- [ ] Mlha a interiéry nesmějí prozrazovat skryté osoby, aktivitu ani cizí inventář.
- [ ] Fáze srovnávání a stavby nelžou o stavu dokončení.
- [ ] Stejné měřítko a práh u všech dodaných stavů; pauza zastavuje animace.
- [ ] Uložení/načtení nevyžaduje změnu masky ani herní migraci kvůli obrázku.
- [ ] Příslušné herní testy prošly a existují skutečné herní screenshoty.
- [ ] Stav schválení je pravdivý; chybějící kontrola je uvedena, nikoli odškrtnuta.

Neaplikovatelný bod označit N/A s důvodem. U konceptu neskrývat, že herní
kontroly ještě nemohly proběhnout. Při implementaci ověřit aktuální příkazy v
[testovací dokumentaci](../../tests/README.md); tento dokument nehlásí spuštění testů.

### Matice budoucích stavových testů

| Osa kontroly | Povinné případy při implementaci |
|---|---|
| Zásoby | 0, 1, mezistavy, kapacita; dřevorubec jednotlivě všech 0–6 |
| Přítomnost | Nikdo uvnitř / někdo uvnitř, nezávisle na každém množství |
| Přidělení a provoz | Bez pracovníka; přidělený venku; uvnitř; provoz zakázán |
| Osobní režim | Návrat domů, pobyt uvnitř, odchod, spánek; žádná předčasná změna |
| Přesuny zboží | Kláda nesená k domu, skutečné odevzdání, rezervace odvozu, skutečné vyzvednutí |
| Soukromí | Vlastní/cizí dům; viditelná, jen prozkoumaná a neznámá oblast |
| Čas | Den/soumrak/noc, globální pauza, změna rychlosti a uložení/načtení |
| Registrace | Všechny vrstvy beze skoku; zakrytí sloupky/lidmi/stromy, průchod u dveří |
| Stavba a konfigurace | Srovnávání/stavba/dokončení; změněná kapacita bez skrytého ořezu |
| Velikost | Čitelnost zásob a přítomnosti při 1×, ověření 0.75×/2.4× a přehledu |

U konceptu je výsledek těchto runtime zkoušek **neprovedeno**, ne „prošlo“.
Obrázková ukázka 0/3/6 kusů nepokrývá ostatní stavy ani skutečné propojení s daty.

## 10. Verze a evidence

Každý brief vede: datum, verzi stylu, verzi assetu, nástroj, skutečné vstupy,
prompt/model nebo výrobní postup, práh/měřítko, QA snímky a schvalovatele.
Stavy: návrh → koncept → herní pilot → schváleno / k přepracování.
Aktuální první koncept je [dřevorubecká chata v3](briefs/lumber-hut-v3.md).
[Lesnická chata v1](briefs/forester-hut-v1.md) zůstává pozdějším návrhem.
Schválení musí odkazovat na konkrétní soubory/verzi, ne jen „vypadá dobře“.

Dnes žádný dům nemá stav schváleného obrazového etalonu. Po schválení pilotu
doplnit jeho cestu, datum a uzamčené měřítko/detail/paletu; nezpětně předstírat,
že verze 0.1 nebo 0.2 již byla vizuálně ověřena.

- **0.1, 2026-09-09:** první pravidla vlastní architektury a společného procesu;
  lesnická chata byla původně navrženým pilotem.
- **0.2, 2026-09-09:** uživatel zvolil první koncept dřevorubce, výslovně
  opravil pohled na mírně izometrický zpředu zleva a požádal o přípravu stavů
  zásob/přítomnosti od návrhu. Opravena příliš čelní interpretace původního
  zadání; žádné schválení obrazového etalonu ani implementace hry tím nevzniká.
- **Technické doplnění, 2026-09-10:** zachována výtvarná verze 0.2;
  zaznamenána následná implementace stavebního pilota a vytvořen samostatný
  postup v1.0 se šablonami pro další objekty. Aktualizován skutečný stav
  RGBA a výběru, bez schválení etalonu nebo rozšíření katalogu.
- **Výrobní upřesnění, 2026-09-10:** uživatel požaduje ověřit první koncept
  proti předem určenému půdorysu před výrobou variant. Povolené rozšíření
  půdorysu již vyrobené chaty je jednotlivá výjimka; výtvarná verze zůstává 0.2.

### Technické zdroje v tomto projektu

- `game/scripts/view/map_projection.gd`
- `game/scripts/simulation/building_footprints.gd`
- `game/scripts/view/building_footprint_renderer.gd`
- `game/scripts/view/unit_sprite_library.gd`
- `game/scripts/view/main_view.gd`, `game_hud.gd`
- `game/scripts/simulation/simulation_world.gd` — fyzické předání/vyzvednutí zásob
- `game/scripts/simulation/indoor_workers.gd`, `workplaces.gd` — přítomnost vs. přidělení
- `game/scripts/simulation/daily_schedule.gd`, `activity_control.gd` — spánek a pauza
- `game/data/buildings.json` — výrobky a kapacity
- `game/scripts/view/solar_cycle.gd`, `solar_shadows.gd`, `fog_renderer.gd`
- [Půdorysy](../building-footprints.md), [srovnávání](../foundation-preparation.md),
  [terén V1](../painted-terrain-game.md), [lesník a rybář](../forester-and-fisher-huts.md)

Technické hodnoty jsou snímek k uvedenému datu. Při budoucí změně engine-kontraktu
nejdříve porovnat skutečný kód; dokument se nesmí stát druhou neplatnou geometrií.
