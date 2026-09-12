# Dřevorubec v1 — osm směrů, sekera a kláda

Datum: **2026-09-09** · herní role: `lumberjack`.
**16 směrových konceptových póz v kroku. Nejde o hotový animační cyklus ani grafiku nasazenou do hry.**

Nová vlastní postava navazuje na [dřevorubeckou chatu v3](lumber-hut-v3.md)
a [výtvarný manuál v0.2](../building-style-guide.md). Používá její malované
matné materiály a přírodní barvy, ne podobu původní jednotky KaM.
Schválení nové jednotky uživatelem: **zatím ne**.

## Aktuální nosná póza — 2026-09-09

Uživatel odmítl zadní příčné nesení i opravený náhled N: kláda stále působila
jako průchod tělem a pravá paže byla nepřirozeně vytočená. Předchozí cílené
závěry kontroly N proto nejsou potvrzením správné nosné pózy.

Nový jediný návrh vychází z čisté postavy se sekerou: **kláda podélně na pravém
rameni**, volná šíje a střed zad, pravá paže přidržuje přední část nákladu.
Uživatel z dvojice nových návrhů vybral přirozenější první verzi s lehkým
**dotykem klády a okraje čepice**. Následné vynucení mezery a narovnání klády
odmítl jako méně přirozené. Dotyk v této podobě není důvod k další úpravě;
je třeba odlišovat jej od průniku hlavou či tělem.

Pohled N v přehledu nyní používá tento zvolený základ. Ostatních sedm směrů
s kládou je zatím starší pracovní řešení; **nosná póza celé sady tedy není
sjednocená**. Žádné další směry se bez navazujícího požadavku nepřekreslovaly.
Volba jednoho konceptu není schválením animace ani nasazením do hry.

## Přehled všech variant

Každý obrázek je samostatný PNG. Směry odpovídají obrazovce na rovném terénu.

| Směr | Chůze se sekerou | Chůze s jednou kládou |
|---|---|---|
| N · sever ↑ | ![Sekera N](../concepts/lumberjack-v1/axe-n.png) | ![Kláda N](../concepts/lumberjack-v1/log-n-shoulder-v1.png) |
| NE · severovýchod ↗ | ![Sekera NE](../concepts/lumberjack-v1/axe-ne.png) | ![Kláda NE](../concepts/lumberjack-v1/log-ne-v2.png) |
| E · východ → | ![Sekera E](../concepts/lumberjack-v1/axe-e.png) | ![Kláda E](../concepts/lumberjack-v1/log-e.png) |
| SE · jihovýchod ↘ | ![Sekera SE](../concepts/lumberjack-v1/axe-se.png) | ![Kláda SE](../concepts/lumberjack-v1/log-se.png) |
| S · jih ↓ | ![Sekera S](../concepts/lumberjack-v1/axe-s.png) | ![Kláda S](../concepts/lumberjack-v1/log-s.png) |
| SW · jihozápad ↙ | ![Sekera SW](../concepts/lumberjack-v1/axe-sw.png) | ![Kláda SW](../concepts/lumberjack-v1/log-sw.png) |
| W · západ ← | ![Sekera W](../concepts/lumberjack-v1/axe-w.png) | ![Kláda W](../concepts/lumberjack-v1/log-w.png) |
| NW · severozápad ↖ | ![Sekera NW](../concepts/lumberjack-v1/axe-nw.png) | ![Kláda NW](../concepts/lumberjack-v1/log-nw-v2.png) |

## Historie předchozí opravy nošení klády — 2026-09-09

Následující popis zachycuje předchozí iteraci. Pro N je překonán novou
podélnou nosnou pózou uvedenou výše; nejde o současné schválení příčného nesení.

Uživatel správně upozornil, že původní NE vedlo kládu před krkem pod bradou.
Předchozí vizuální kontrola tuto chybu přehlédla; její obecné tvrzení o absenci
kritických vad se tímto opravuje. Cílený audit našel stejný problém v N a
nejednoznačnou zadní oporu v NW. E, SE, S, SW a W tuto konkrétní opravu nepotřebovaly.

- Nové soubory **log-ne-v2.png, log-n-v2.png a log-nw-v2.png** nahrazují pouze
  příslušné obrázky v přehledu výše. Původní PNG zůstaly zachovány.
- Kláda leží **za šíjí přes zadní část ramen / horní záda**, nikdy pod bradou.
  V zadním pohledu musí překrývat horní tuniku a základ zadního límce/šíje;
  nesmí být schovaná na vzdálené přední straně krku. Pravá ruka podpírá náklad.
- V NW byl upraven i směr osy klády, aby příčně sledovala zadní ramena.
  První pokus nebyl přesvědčivý, druhý ponechal zbytek původního dřeva nad čepicí;
  oba jsou archivované. Vybraná verze tento zbytek nemá a nese jedinou kládu.
- Hlavní agent a nezávislá cílená kontrola prošli vybrané NE/N/NW: zadní opora,
  volná brada, jedna kláda, pravá nosná ruka, sekera vlevo. Nejde o nové
  bezvýhradné schválení celé sady, rigidního otáčení ani animace.

Osm variant se samotnou sekerou a zbývajících pět variant s kládou se nezměnilo.
Schválení opravy uživatelem zůstává otevřené. Číslo v2 označuje revizi těchto
obrázků, nikoli nový výtvarný styl jednotky nebo nasazení do hry.

## Vlastní vzhled a dva stavy

Statný dospělý řemeslník s krátkým hnědým vousem, rezavě okrovou čepicí,
tlumeně zelenou tunikou, krémovými vyhrnutými rukávy, hnědou koženou přední
zástěrou a hnědými botami. Velké barevné plochy a čitelné profesní vybavení
mají přednost před mikrodetaily. Zástěra je pouze vpředu; záda mají zelenou
tuniku s opaskem. Kamera zůstává vyvýšená, při směrech se otáčí postava.

- **Sekera:** jediná praktická jednobřitá dřevorubecká sekera v anatomické pravé
  ruce, levá ruka volná. Není to bojová póza ani sekání stromu.
- **Kláda — nový základ N:** právě jeden kulatý kmen podélně na pravém rameni,
  pravá paže přidržuje přední část; hlava, šíje a střed zad zůstávají volné.
  Lehký dotyk s okrajem čepice uživatel preferoval. Ostatní směry tuto změnu
  zatím nepřebírají;
  sekera je na anatomickém levém boku v závěsu. U směru E je přirozeně
  částečně zakrytá tělem a levou paží.
- Barvy kůry a čerstvého řezu navazují na klády ve stojanu chaty.
- První zadání chtělo kládu podélně. Generátor navrhl nesení přes horní část
  zad/ramena; po vizuální kontrole jsme tuto použitelnou podobu zvolili jako
  další pracovní referenci. **Sklon a orientace klády ale nejsou mezi všemi
  směry přesně synchronizované.** Jde o koncepty, nikoli rigidní 3D obrat.
- E/W mají trup mírně tříčtvrteční, ne matematicky čistý profil. Směry kroku
  jsou přesto rozlišitelné od SE/SW i NE/NW; pro produkci kameru překalibrovat.

## Co bylo skutečně dodáno a ověřeno

- **16 samostatných obrázků**, každý **1254 × 1254 px**, RGB PNG bez alfy.
  Světlé pozadí není průhlednost. Rozměry, PNG typ, nepřítomnost `tRNS`
  a SHA256 byly změřeny; obrázky jsou zkopírované beze změny.
- Hlavní agent a nezávislá vizuální kontrola prošli všech osm směrů a oba
  stavy: identita, oblečení, nadhled, směr, počet nástrojů/nákladu a strany rukou.
- Původní W/SW se sekerou měly chybně přehozenou ruku; opraveno.
  Původní E/NE s kládou měly sekeru na chybném boku; opraveno.
  Čtyři původní obrázky jsou jen archivované vstupy oprav, **ne další finální varianty**.
- Původní obecný závěr kontroly byl po uživatelově připomínce odvolán.
  Oprava NE/N/NW a rozsah nové cílené kontroly jsou popsány výše.
- **Neověřeno / nedodáno:** průhledné produkční vrstvy, přesné kotvy chodidel,
  jednotné tělesné měřítko a rozměry vybavení, pevná fáze kroku, plynulá animace,
  registrace při otáčení, čitelnost a proporce přímo ve hře.
- Hra, mapy, simulace, uložené pozice ani stávající atlasy nebyly změněny.

## Ověřený technický kontrakt pro následnou produkci

Současný pohyb má osm sousedů v pořadí N, NE, E, SE, S, SW, W, NW
([zdroj](../../../game/scripts/simulation/grid_map_sim.gd)). Jde o pořadí
pole pohybových vektorů, **ne existující API pro směrové sprity**.
Na rovině X roste doprava a Y dolů, mřížka má 40 × 40 px. Výška posunuje
obrazový bod o −8 px/úroveň; neotáčí směry pohybu
([projekce](../../../game/scripts/view/map_projection.gd)).

Dnešní [knihovna jednotek](../../../game/scripts/view/unit_sprite_library.gd)
má jediný obrázek každé profese, zrcadlení podle X a mírné pohupování při chůzi.
Nemá osmisměrné snímky ani plný cyklus. Tělo běžného člověka míří na výšku
33 world px; aktuální načítání omezuje celý alfa-obrys i šířkou 31 px.
**Nový export nesmí použít automatické přizpůsobení celého obrysu**:
kláda by člověka zmenšovala a měnila jeho polohu. Je třeba oddělit tělesné
měřítko od přesahů sekery/klády a určit společnou explicitní kotvu nohou.

Budoucí volba nákladu čte `worker["carrying"] == "log"`, ne sklad chaty
ani rezervace. Jeden takový stav představuje jednu fyzickou kládu; ta se
přesune do inventáře až při skutečném odevzdání. Zachovat skrývání jednotky
uvnitř, mlhu, řazení, stín a tónování. Aktuální
[renderer](../../../game/scripts/view/main_view.gd) navíc kreslí drobný symbol
neseného zboží; při použití pose s už nakreslenou kládou nesmí přidat druhou.

Při výrobě animace teprve zvolit počet fází a časování; například šest fází
pro obě zátěže a osm směrů by znamenalo 96 snímků. **Tato šestifázová varianta
není nynější požadavek, dodávka ani již implementovaný standard.**
Směrové a animační vykreslování musí zůstat pouze prezentací a respektovat pauzu.

Budoucí QA: všechny směry a zátěže; změna směru/stop; skutečné převzetí a
odevzdání; dveře a interiéry; rovina/svah; den/noc; mlha; výběr a překrývání;
0.75×/1×/2.4×; pauza a uložení/načtení. Tyto herní zkoušky nyní **neproběhly**.

## Původ a soubory

Použit skill **imagegen** a výchozí **vestavěný obrazový nástroj**, nikoli CLI
nebo placený API fallback. Model nástroj výslovně neidentifikoval.
Použitým výtvarným podkladem je naše chata se šesti kládami; další varianty
vycházejí z vlastních jednotkových masterů, nikoli z originálního sprite KaM.

[Přesná zadání, všechny vstupy, opravné kroky, finální cesty a SHA256](lumberjack-v1-prompts.json).

Finální obrazy: `docs/art/concepts/lumberjack-v1/`.
Archiv šesti nevybraných vstupů/pokusů: `docs/art/sources/lumberjack-v1/`.
Překonané zadní pohledy včetně N v2 zůstávají zachované jako historie;
přehled výše používá aktuálních 16 vybraných obrázků.
Schválený herní etalon: **ne**.
