# Den a noc: implementovaný režim a další návrhy

**Stav aktualizován 2026-09-09: herní hodiny, noční režim civilních pracovníků,
dvoulůžková Workers' Cottage a zjednodušené denní osvětlení jsou implementované.
Celý den trvá 10 minut při 1×. Civilisté pracují od 05:00 do 20:00 a v noci odcházejí spát. Pohyb slunce
mění zabarvení mapy a směr i délku stínů. Volitelné noční směny zatím
implementované nejsou.**

Tento dokument vznikl jako analýza a byl aktualizován podle následného
výběru uživatele. Oddíly 1–6 popisují současnou implementaci. Oddíl 7 výslovně
odděluje původní, nepřijaté návrhy od zbývajících možností. Původní úvahy
o delším dni, domech se čtyřmi lůžky, večerním dokončování dodávek a volitelném
zapnutí rozvrhu již nepopisují chování hry.

## 1. Hodiny a rozsah rozvrhu

Hodiny vycházejí z uloženého `world.tick`; jeden krok simulace odpovídá
0,1 sekundy a celý kalendářní den má 6 000 ticků. To znamená **10 minut při
1×, 20 minut při výchozí 0,5× a 5 minut při 2×**. Pauza zastavuje hodiny
i simulaci. Nová hra začíná v 05:00, číslo dne se mění o půlnoci.

| Herní čas | Fáze hodin v HUD | Civilní pracovníci |
|---|---|---|
| 05:00–06:00 | Dawn | Již mohou pracovat; podle potřeby vycházejí z budov a jedí. |
| 06:00–18:00 | Day | Pracují podle běžných pravidel. |
| 18:00–20:00 | Dusk | Stále běžně pracují; není zvláštní fáze dokončování. |
| 20:00–05:00 | Night | Nepracují, míří do místa spánku a odpočívají. Jídlo může spánek přerušit. |

Rozvrh platí pro civilní jednotky z katalogu. **Vojáci z katalogu `soldiers`
a jednotky typu `recruit`, včetně strážní služby využívající rekruty,
zůstávají aktivní.** Nejsou zavedené další noční profese ani konfigurace
samostatných směn pro jednotlivá pracoviště.

Povolení práce se mění přesně ve 20:00 a v 05:00. Cesta domů a ven z budovy
nadále trvá herní čas: přechod rozvrhu jednotku neteleportuje. V 05:00 se
práce znovu povolí; odchod mohou zdržet obsazené dveře nebo probíhající jídlo.

## 2. Kde jednotky spí

Původní etapa používala jen pracoviště a sklady. Nyní je doplněna vlastní
obytná budova **Workers' Cottage** se dvěma lůžky pro nosiče a stavitele.

| Jednotka | Místo spánku |
|---|---|
| Specialista s přiděleným pracovištěm | Jeho vlastní dokončené pracoviště. Dřevorubec spí ve své chatě, lesník v lesnické a rybář v rybářské chatě. Stejné pravidlo platí pro ostatní civilní specialisty. |
| Nosič a dělník/stavitel | Přednostně dosažitelná dokončená a zapnutá Workers' Cottage s volným lůžkem; jinak dokončený sklad jako nouzové ubytování. |
| Civilní specialista bez přiděleného pracoviště | Dočasně sklad; po získání pracoviště se místo spánku přesměruje na něj. |
| Voják nebo rekrut | Civilní rozvrh se na něj nevztahuje. |

Každá Workers' Cottage ubytuje nejvýše **dvě** kompatibilní jednotky. Obsazenost
se odvozuje z jejich `sleep_home_id`, takže smrt nebo přesměrování jednotky
lůžko uvolní. Sklad zůstává **nouzovým společným ubytováním bez limitu**. Přiřazený
sklad zůstává uložený i přes den; nevybírá se bezdůvodně každou noc znovu.
Chybějící nebo nedosažitelné ubytování nezpůsobí obnovení práce během noci:
jednotka čeká a zkouší situaci znovu, HUD ukazuje důvod. Samostatný postih za
nedostatek bydlení ani domácí spotřeba zatím neexistují.

Tři identifikátory mají odlišný význam:

- `home_id` je dosavadní výhradní pracoviště a spánek ho neuvolňuje;
- `sleep_home_id` je trvalé přiřazení místa spánku;
- `inside_building_id` označuje skutečný pobyt uvnitř, nula znamená jednotku venku.

Pobyt uvnitř využívá `IndoorWorkers`. Jednotka dojde ke skutečnému vchodu,
dokončí viditelný krok, uvolní venkovní pole a přestane se kreslit na mapě.
Zůstává součástí populace a zachovává identitu, zaměstnání, sytost i náklad.
Při odchodu si musí bezpečně zabrat volné pole; obsazený vchod ji zatím
ponechá uvnitř. Spánek používá samostatný stav `sleeping`, nikoli prodloužení
krátkého čítače návštěvy `indoor_wait_ticks`.

## 3. Zastavení práce ve 20:00

Současná verze používá **pevné přerušení práce**, bez večerního prodlužování
směny kvůli dokončení úkolu nebo doručení. Již zahájený viditelný krok chůze
může doběhnout, aby změna cíle nezpůsobila skok ani porušení rezervací pohybu.

| Stav jednotky při přechodu na noc | Implementované chování |
|---|---|
| Čeká na práci nebo jde ke zdroji | Uvolní pracovní úkol a zamíří do místa spánku. |
| Právě kácí, těží, sklízí nebo sází | Přeruší nedokončený úkon. Nevznikne výnos za nehotovou práci; krátký úkon se později zahajuje znovu. |
| Nese surovinu | Ponechá si náklad a jde s ním spát. Ráno se doručení znovu naplánuje. |
| Obsluhuje započatou výrobní dávku | Budova uchová postup i již zaplacené vstupy a přes noc výrobu pozastaví. |
| Staví | Stavba uchová dodané materiály a dosažený postup; další stavební práce počká na ráno. |
| Jde jíst nebo jí | Jídlo může pokračovat. Pokud je po jídle ještě noc, jednotka se vrací do místa spánku. |
| Nosič zásobuje vojáka | Noční režim přeruší misi nosiče. Již převzaté jídlo zůstane nákladem a požadavek vojáka se neztratí. |

Pracovní rezervace se uvolňují přes odpovídající operace simulace. Náklad
není zahozen ani automaticky převeden do zásob budovy, kde jednotka spí.
Cesta do skladu kvůli spánku proto nepředstavuje dodávku: její
`destination_id` je nula. Náklad nesmí vytvářet falešně příchozí zásobu
ani během noční cesty na jídlo.

V 05:00 se obnoví běžné rozhodování jednotek. Specialista si zachoval své
pracoviště, výrobní a stavební postup zůstaly v budově a nosič ověří aktuální
cíl dodávky. Samotné probuzení nespotřebuje znovu zaplacené výrobní vstupy.

## 4. Jídlo, služby a pasivní procesy

**Spánek nenahrazuje jídlo.** Při zapnuté ekonomice sytost dál klesá podle
aktuální konfigurace systému jídla. Tento dokument neurčuje vlastní noční
rychlost úbytku; původní výpočet ze staršího nastavení hladu již neplatí.
Aktuální vyvážení a jeho zdroj jsou v [economy.json](../game/data/economy.json)
a v [ClassicEconomy](../game/scripts/simulation/classic_economy.gd).

Hladový civilista může i v noci vyhledat zásobený hostinec, opustit místo
spánku a po jídle se vrátit. To funguje také s odloženým nákladem. Náklad
zůstává evidovaný u jednotky a neslouží jako bezplatná porce. Rozvrh nepřidává
samostatnou únavu ani nová pravidla hladovění.

Škola a služby, které nevyžadují civilní pracovní úlohu, **zůstávají aktivní
i v noci**. Školení, obchod a nábor tedy nedostaly nové otevírací hodiny.
Hostinec zůstává přístupný. Nově vyškolený civilista se řídí právě platným
rozvrhem a může využít provizorní ubytování ve skladu.

Růst polí a stromů a pasivní změny stezek pokračují. Výroba, která vyžaduje
civilního pracovníka, je v noci pozastavená. Nepřibylo automatické zrychlení
denní výroby pro kompenzaci noční přestávky. Pro další ladění je potřeba
sledovat více celých cyklů, zásoby hostinců a dopravu u společných skladů.

## 5. Technické napojení a uložení

| Soubor | Současná úloha |
|---|---|
| [day_cycle.gd](../game/scripts/simulation/day_cycle.gd) | Den, hodina a fáze z uloženého ticku; rozlišení noci 20:00–05:00. |
| [daily_schedule.gd](../game/scripts/simulation/daily_schedule.gd) | Rozsah civilního rozvrhu, zastavení práce, výběr místa spánku, cesta, spánek a návrat po jídle. |
| [residences.gd](../game/scripts/simulation/residences.gd) | Kompatibilita obyvatel, kapacita dvou lůžek a odvozená obsazenost Workers' Cottage. |
| [simulation_world.gd](../game/scripts/simulation/simulation_world.gd) | Zapojení rozvrhu před výrobou i do rozhodování a pohybu jednotek; veřejné dotazy na stav rozvrhu. |
| [workplaces.gd](../game/scripts/simulation/workplaces.gd) | Zachování pracoviště a sladění místa spánku při novém přidělení zaměstnání. |
| [indoor_workers.gd](../game/scripts/simulation/indoor_workers.gd) | Skutečný vstup a bezpečný výstup bez venkovní rezervace spící jednotky. |
| [classic_economy.gd](../game/scripts/simulation/classic_economy.gd), [inn_feeding.gd](../game/scripts/simulation/inn_feeding.gd) | Respektování pracovní doby a umožnění jídla během noci se zachováním nákladu. |
| [world_snapshot.gd](../game/scripts/simulation/world_snapshot.gd) | Od save v15 trvalé `sleep_home_id`; v20 navíc ověřuje typ a kapacitu obytných budov. |
| [game_hud.gd](../game/scripts/view/game_hud.gd) | Hodiny, rozvrh v detailu jednotky a počet skutečně spících v budově i osadě. |
| [solar_cycle.gd](../game/scripts/view/solar_cycle.gd) | Poloha slunce a měsíce, barvy oblohy a mapy, směr a intenzita stínů z herního času. |
| [main_view.gd](../game/scripts/view/main_view.gd), [solar_shadows.gd](../game/scripts/view/solar_shadows.gd) | Zabarvení světa a promítnuté stíny budov, stromů a venkovních jednotek. |
| [sky_clock.gd](../game/scripts/view/sky_clock.gd) | Malý ukazatel oblohy se sluncem a měsícem v HUD. |

Rozvrh se vyhodnocuje před aktualizací výroby, aby na hranici 20:00 nezačala
nová dávka ani nepokračovala další civilní pracovní činnost. Pohyb dále
využívá současnou mřížku a rezervace. Venkovní jednotka vlastní své pole;
jednotka uvnitř nemá venkovní rezervaci.

**Aktuální formát uložení je v20.** Od v15 vedle času, zaměstnání, nákladu,
pobytu uvnitř a údajů o jídle ukládá `sleep_home_id`. Při načtení v noci se jednotka
ve svém uloženém místě spánku obnoví jako spící; rozjedená porce se obnoví
podle systému jídla. Načtení v noci samo neprovede dodávku ani nepřesune
jednotku. Cesty a další rozhodnutí se obnovují v následujících tickách.

**Starší savy přebírají rozvrh automaticky podle svého zachovaného času.**
Není zde přepínač pro dodatečné zapnutí funkce ani reset hodin. Starším
jednotkám bez `sleep_home_id` se ubytování doplní běžným rozhodováním. Workers'
Cottage nepřidává nové uložené pole; v20 ověřuje kompatibilitu typu obyvatele a
nejvýše dvě přiřazení na chatu.
Načtení nevytváří nové budovy a neztrácí nesené zásoby. Uložená přiřazení se
ověřují proti existujícím dokončeným budovám, profesi a vlastnictví pracoviště;
vadný save se odmítne bez poškození běžící hry.

Cesty a kompletní rozpracované krátké úkony nejsou přesným záznamem celé
simulace. Garantovaným záměrem této etapy je zachovat čas, místo spánku,
zaměstnání, náklad a uložený postup budov, nikoli bitově stejný průběh všech
pohybů po každém načtení.

## 6. Informace pro hráče a ověření

Spodní lišta ukazuje den, čas a fázi. Její tooltip vysvětluje desetiminutový
cyklus, práci 05:00–20:00, noční odpočinek a dočasné spaní ve skladu.
Souhrn populace přidává počet spících a zachovává všechny obyvatele v celkovém
počtu. V úzkém okně zůstávají úplné údaje dostupné v tooltipu.

Detail jednotky rozlišuje například `Sleeping until 05:00`, `Going to sleep`,
`No sleeping place available`, `Cannot reach sleeping place` a noční cestu
na jídlo. Údaje o sytosti a nákladu zůstávají dostupné. Detail budovy má
vedle skutečného počtu přítomných `Inside` také samostatný počet `Sleeping`;
člověk stojící venku u dveří se do něj nepočítá.

**Zjednodušené osvětlení od 2026-09-06 plynule mění vzhled mapy podle času.**
Slunce vychází v 05:00 na levé straně ukazatele a zapadá ve 20:00 vpravo;
vrcholu patnáctihodinového oblouku dosáhne ve 12:30. Svítání probíhá mezi
04:00 a 07:00 a soumrak mezi 18:00 a 21:00. Přechod pracovního rozvrhu ve
20:00 proto nezpůsobuje skok do tmy. Ranní a večerní světlo je teplé,
polední téměř neutrální a noc zachovává čitelný modrý základ.

Vpravo nahoře je ukazatel oblohy o velikosti 184 × 86 pixelů s obloukem
slunce, v noci měsíce. Jde o grafické znázornění stejných herních hodin,
nikoli samostatný čas nebo astronomickou simulaci. Barva světa se aplikuje
na kořen mapy; HUD má vlastní `CanvasLayer` a zůstává nezabarvený.

Budovy, stromy a venkovní jednotky vrhají stíny opačně ke slunci: ráno
doprava, večer doleva, uprostřed dne kratší. Stíny jsou ořezané podle řádků
mřížky a promítnuté na výškový terén; nejde o úplný výpočet vzájemného
zakrývání objektů paprsky. U horizontu plynule vyhasínají. Svítící okna
a místní světla budov zůstávají možností dalšího rozšíření.

Vizuální čas vychází výhradně z uloženého ticku a zlomku mezi snímky.
Pauza zastaví i pohyb světla; změna rychlosti a načtení hry se projeví
automaticky. Osvětlení nemění ekonomiku, civilní rozvrh ani formát uložení.

Ověření zahrnuje hranice pracovní doby, návraty různých profesí, zachování
nákladu a postupu, obsazené dveře, noční jídlo, výjimku pro armádu,
uložení/načtení a zobrazení v reálném HUD. Osvětlení má navíc pokrytí
hranic času, plynulosti, stínů, interpolace a opakování při velkých tickách.
Přehled sad a aktuální výsledky
jsou vedené v [testech](../tests/README.md). Při dalších úpravách je potřeba
zachovat regresní pokrytí pohybu, pracovišť, výroby, hladu a inventáře.

## 7. Původní návrhy a možnosti další etapy

Následující body jsou záznam dřívějších návrhů, **nikoli současné nastavení
ani schválená další implementace**:

| Původní návrh | Současná volba uživatele / stav |
|---|---|
| Delší denní cyklus | Nahrazen přesně 10 minutami při 1×. |
| Práce 06–18 a dokončování 18–20 | Nahrazeno prací 05–20 a pevným přerušením ve 20:00. |
| Dokončení kácení a přednostní večerní doručení | Krátká nedokončená práce se přeruší, náklad zůstane jednotce do rána. |
| Nové obytné domy, například pro čtyři obyvatele, a `residence_id` | Nahrazeno dvoulůžkovou Workers' Cottage pro nosiče a stavitele; používá existující `sleep_home_id`, sklad zůstává nouzový. |
| Pozastavení školy, obchodu a náboru mimo denní hodiny | Nezavedeno; služby pokračují. |
| Volitelné zapnutí rozvrhu při načtení staré hry | Nezavedeno; starší savy používají rozvrh automaticky podle uloženého času. |
| Plynulé denní a noční zabarvení mapy | Implementováno 2026-09-06 spolu s ukazatelem oblohy a směrovými stíny. |

Konkrétní **noční profese a pracoviště zůstávají k upřesnění s uživatelem**.
Při jejich návrhu má smysl rozlišit profesi a konkrétní budovu: například
`baker` pracuje v mlýně i pekárně, takže povolení noční pekárny nemusí znamenat
noční provoz všech mlýnů. Budoucí noční pracovník také potřebuje určený čas
odpočinku a možnost jídla.

U případné noční výroby je nutné společně určit zásobování: zda vystačí
s denními zásobami, nebo dostane noční nosiče, a zda kapacity vydrží celou
směnu. Současné pravidlo jednoho specialisty na pracoviště neobsahuje
střídání dvou zaměstnanců na témže místě.

Další možné rozšíření tvoří skutečné obytné domy s kapacitou, samostatné
otevírací hodiny služeb a místní noční světla. Vizuální úpravy musí dále
zachovat čitelnost HUD, cest a výšek terénu a nemají každým snímkem
přestavovat statickou geometrii. Žádný z těchto bodů není podmínkou již
implementovaného civilního nočního odpočinku.
