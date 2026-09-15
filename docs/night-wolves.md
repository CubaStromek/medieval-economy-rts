# Noční vlci — první hrozba

> **Odstraněno 14. 9. 2026** spolu s cyklem dne a noci. Dokument níže je historický.

Stav k **2026-09-12**. Vlci jsou první nepřátelský prvek ve hře. Nejsou to
nepřátelské jednotky ani začátek bojového systému: hra dál nemá boj, HP ani
taktické povely a tento dokument na tom nic nemění.

## 1. Co vlci dělají

Vlčí noc je **nájezd, ne obležení**:

1. **Večer**, ještě než civilisté ulehnou, se vlk objeví na okraji mapy mimo
   aktuální dohled osady. Náskok je podstatný: měření ekonomické ukázky ukázalo,
   že v soumraku je venku 12 z 36 obyvatel, ale za 12 sekund jsou všichni pod
   střechou. Vlk vyrážející až ve 20:00 by našel prázdnou vesnici každou noc.
2. Projde vesnicí — obejde `wolf_sweep_stops` vchodů budov v pořadí podle id,
   počínaje tím nejbližším místu příchodu.
3. Když cestou uvidí kořist do `wolf_hunt_radius`, přeruší obchůzku a vyrazí po
   ní. Kontakt znamená **smrt jednotky** — vědomé rozhodnutí vlastníka z 12. 9.,
   ne výchozí návrh.
4. Když obchůzku dokončí bez úlovku, nebo vyprší `wolf_visit_ticks`, otočí se
   k okraji mapy a **despawne se**. Nečeká do rána. Kořist obchůzku přeruší,
   takže vlk neodejde od někoho, koho zrovna vidí.
5. Rozbřesk ukončí lov i tak, i kdyby obchůzka ještě běžela.

### Naměřeno na ekonomické ukázce (34 × 30, 36 obyvatel, 12. 9.)

| Veličina | Hodnota |
|---|---|
| Venku v soumraku | 12 z 36 obyvatel |
| Venku o 12 s později | 0 |
| Délka nájezdu | ~11 s při 1× (1 vlk, 4 zastávky blízko sebe) |
| **Ztráty za jeden nájezd** | **2 obyvatelé** |

Dvě úmrtí za jednu noc při jednom vlkovi je **tvrdé** a smečka časem roste na
tři. Pokud je to moc, nejúčinnější páky jsou `wolf_arrival_lead_ticks` (menší
náskok = vlk dorazí, až budou lidé pod střechou), `wolf_sweep_stops` a
`wolf_hunt_radius`. Čísla jsou první odhad, ne vyvážený návrh.

Kdo je v bezpečí:

| Stav | Proč |
|---|---|
| Uvnitř budovy | Jednotka uvnitř nemá fyzickou přítomnost, vlk na ni nedosáhne |
| Voják nebo rekrut | Ozbrojený; vlci ho neloví a vyhýbají se zemi kolem něj |
| V dosahu zásobené věže | Věž vlka odežene dřív, než dojde ke kontaktu |

## 2. Protihra

Všechna obrana staví na systémech, které už ve hře byly:

1. **Domky dělníků.** Kdo nemá lůžko, stojí podle `daily_schedule.gd` celou noc
   venku a HUD to hlásí jako „Není volné místo ke spaní". Přesně tihle lidé jsou
   oběti. Ubytování celé osady hrozbu vypne.
2. **Strážní věž.** Odežene vlka v okruhu `wolf_repel_radius`, ale jen když je
   dokončená, není pozastavená, hlídá ji rekrut a má kámen. Každé odehnání
   spotřebuje **1 kámen**, takže nosiči mají poprvé důvod vozit do věže munici.
3. **Vojáci.** Vlci se vyhýbají zemi do `wolf_soldier_radius` kolem vojáka nebo
   rekruta. Voják vlka nezabije — boj neexistuje —, jen ho odradí.
4. **Kamenné cesty.** Vlk má pevnou rychlost na každém povrchu, civilista po
   kamenné cestě chodí 3× rychleji. Silniční síť je tedy v noci únikovou trasou.
   Vlk se cestám **nevyhýbá**: první verze je brala jako překážku, jenže na
   propojené osadě to vytlačilo každou trasu okolo vesnice, takže ji vlk
   obcházel po okraji místo aby jí prošel.

## 3. Ladění

Vše je v `game/data/economy.json`; výchozí hodnoty drží i
`night_wolves.gd → DEFAULTS`, aby starší katalog nerozbil běh.

| Klíč | Výchozí | Význam |
|---|---|---|
| `wolf_first_night_day` | 2 | první noc s vlky; den 1 je klidný, ať hráč stihne postavit osadu |
| `wolf_arrival_lead_ticks` | 250 | o kolik dřív než ve 20:00 vlk dorazí (250 = 1 herní hodina) |
| `wolf_pack_min` / `wolf_pack_max` | 1 / 3 | velikost smečky |
| `wolf_pack_growth_days` | 4 | po kolika dnech smečka povyroste o jednoho |
| `wolf_move_ticks` | 5 | ticků na krok, nezávisle na povrchu |
| `wolf_hunt_radius` | 14 | jak daleko si vlk všimne kořisti |
| `wolf_repel_radius` | 6 | dosah strážní věže |
| `wolf_soldier_radius` | 3 | okruh kolem vojáka, kam vlk nevstoupí |
| `wolf_spawn_building_clearance` | 8 | minimální odstup spawnu od budovy |
| `wolf_leave_grace_ticks` | 300 | jak dlouho po rozbřesku smí ještě odcházet |
| `wolf_visit_ticks` | 900 | strop délky jedné návštěvy, pak vlk odchází |
| `wolf_sweep_stops` | 4 | kolik vchodů obejde, než to vzdá |

**Klidné scénáře.** Vlci se spouští jen když `world.economy_enabled`. Terénní
studie, grafický sandbox i testovací fixtury tak zůstávají bez hrozby. Týká se
to i mapy Mountainous Region, která dnes startuje s vypnutou ekonomikou.

Scénář se zapnutou ekonomikou vypne hrozbu nastavením `wolf_pack_min`
i `wolf_pack_max` na `0`; katalog se načítá pro každý svět zvlášť, takže to
neovlivní ostatní hry. Přesně to dělá měření výživy v `hunger_cycle_tests.gd`:
běží tři dny a nájezd by mu legitimně sebral člověka cestou do hostince.

## 4. Proč je to postavené takhle

**Vlastní kolekce, ne workers.** Vlci žijí v `world.wolves`. Kdyby to byli
workers, musela by je vyloučit každá smyčka přes `world.workers` — počet
obyvatel, task board, výživa, ubytování, myšlenky, pozastavení práce i HUD.
Oddělená kolekce znamená, že o nich stávající kód vůbec nemusí vědět.

**Žádná náhoda.** Simulace neobsahuje jediný `randi`/`randf` a
`docs/godot-architecture.md` slibuje determinismus vhodný pro replay. Velikost
smečky i místo příchodu proto počítá **čistá hashovací funkce** z indexu noci,
pořadí vlka a rozměru mapy. Stejná mapa a stejná noc dají vždy stejnou smečku;
`night_wolves_tests.gd` to ověřuje porovnáním `to_data()` dvou světů.

**Index noci, ne kalendářní den.** Noc přechází přes půlnoc, takže se uprostřed
ní mění kalendářní den. Klíčem smečky je proto `night_index()`, jinak by táž noc
dostala druhou smečku o půlnoci.

**Sdílené odstranění jednotky.** `world.remove_worker()` je jediná cesta, kterou
jednotka opouští svět. Hlad i vlk jí uvolní stejný úkol, rezervaci sázení
i obsazené pole; dřív to měl hlad naklikané přímo v `classic_economy.gd`.

**Mlha.** Vlk má `owner_id = 0`, takže není lokální entita a kreslí se pouze na
poli, které osada **právě vidí** — nikdy z paměti prozkoumané mapy.

**Co se neukládá.** Save v22 nese pozici, rozpracovaný krok a příznak odchodu.
Trasa se záměrně neukládá: je to přepočitatelný stav a načtený vlk si ji naplánuje
hned v dalším ticku. Save v21 se načte bez vlků, což je neškodné — jsou přechodní
a další soumrak si smečku vytvoří sám.

## 5. Grafika

Vlk je zatím **placeholder kreslený kódem** v `main_view.gd → _draw_wolf()`:
silueta těla, nohou, ocasu a hlavy se svítícím okem. Skutečná směrová grafika
je placený a briefovaný krok podle `AGENTS.md` — nejdřív půdorys, vstup
a měřítko člověka, teprve pak generování — a tato herní mechanika ji sama
o sobě neschvaluje.

## 6. Co zbývá

- Vlci zatím nesahají na hospodářská zvířata ani na zásoby jídla.
- Obchůzka jde po id budov, ne nejkratší okružní trasou. Na roztažené osadě
  proto může mezi dvěma zastávkami urazit zbytečně dlouhý kus.
- Za noc přijde jedna smečka. Nejsou žádné další vlny.
- Věž vlka odežene, nezabije ho; neexistuje žádná trvalá redukce populace vlků.
- Vyváženost je první odhad; naměřené ztráty výše ukazují, že je spíš tvrdá.
- Chybí zvuk a jakékoli varování na mapě kromě záznamu událostí.
