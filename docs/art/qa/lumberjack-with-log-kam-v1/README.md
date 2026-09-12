# Kontrola a přejímka: dřevorubec s kládou — KaM v1

Datum založení: **2026-09-10** · stav: **technické balení 64 snímků a logika samostatného náhledu ověřeny; všechny směrové archy staticky prohlédnuty; běh v prohlížeči a herní kontroly neověřeny**.
Založeno podle [QA šablony v1.0](../../object-qa-template.md), [společného postupu](../../object-implementation-workflow.md) a [integračního záznamu](../../briefs/lumberjack-with-log-kam-v1-integration.md).
Aktuální zadání zahrnuje pouze artwork a samostatný preview; nezahrnuje integraci do hry.

## 1. Co přesně se ověřuje

| Údaj | Hodnota |
|---|---|
| Objekt, ID, druh | Dřevorubec; `lumberjack-with-log-kam-v1`; jednotka, role `lumberjack` |
| Rozsah změny | Nová osmisměrná animace nesení jedné klády a samostatný náhled |
| Datum a ověřující | 2026-09-10, Codex; příprava a ověření technického balení, prohlídka diagnostických čepic; hlavní agent prohlédl všech osm finálních archů a dokončil technickou kontrolu náhledu |
| Brief a návaznost | [Vzhled postavy](../../briefs/lumberjack-v1.md), [poslední chůze](../../briefs/lumberjack-walk-without-log-kam-v2.md), [aktuální rozsah](../../briefs/lumberjack-with-log-kam-v1-integration.md) |
| Běžná herní scéna a mapa | Neověřeno — herní běh pro tuto dodávku nebyl proveden |
| Ověřený kód a importovaná verze | Neověřeno — hra nebyla měněna ani nově importována |
| Prostředí | Příprava PNG lokálně na macOS pomocí Python/Pillow; herní renderer/GPU, okno a zoom neověřeny |
| Původ podkladů | Lokální vlastněná GOG data KaM jako externí pohybová reference; vlastní registrovaná chůze bez klády jako tělo/vzhled |
| Přesné vstupy | `original_game_data/kam-reference-export/lumberjack-full-set/carry-guides-8x/DIR.png` a `docs/art/animations/lumberjack-with-log-kam-v1/walk-targets/DIR.png` |
| Finální výstupy a SHA256 | [Manifest](../../animations/lumberjack-with-log-kam-v1/manifest.json), [registrace](../../animations/lumberjack-with-log-kam-v1/registration.json), [kontrola balení](../../animations/lumberjack-with-log-kam-v1/pack-validation.json): 64 PNG, 8 archů, 1 atlas, 16 GIFů |

| Měřený kontrakt vstupů | Hodnota a omezení |
|---|---|
| Počet směrů a fází | Původní manifest: N, NE, E, SE, S, SW, W, NW; 8 fází každý, 64 celkem |
| Canvas / atlas | Připravená buňka 448×544 px, arch 4×2 = 1792×1088 px |
| Obrazový pivot | [216,400] px; původ jednotky, nikoli jednotlivé pohybující se chodidlo |
| Převod KaM | Původní 52×54, kotva [26,46], 8× nearest-neighbor + [8,32] |
| Převod vlastní chůze | Zdroj 384×512, kotva [184,368], bezeztrátové vložení +[32,32] |
| Přesah nákladu | Původní úplný obal po převodu [8,32,424,464]; meze vpravo/dole výlučné |
| Měřítko do světa, zem, řazení | Neověřeno; nový herní převod není zaveden |
| Alfa nové kresby | Změřeno: všech 64 finálních PNG je RGB bez alfa kanálu, bílé/téměř bílé pozadí |

Údaje o připravených vstupech ani technickém balení nejsou vizuálním přijetím nové kresby nebo herním QA. Měřítko a registraci určovat z těla; kláda může zakrýt čepici nebo přesahovat nad ni. Neodvozovat polohu z celého nákladového obrysu a nezamykat jednotlivou botu.

## 2. Ověření běžnou herní cestou

**Reprodukce:** neověřeno — pro tuto verzi nebyla spuštěna běžná herní cesta.
**Skutečně vykonaná simulace:** neověřeno — pohyb, převzetí, nesení ani předání klády nebyly v této dodávce ověřeny ve hře.
**Uměle nastavené QA stavy:** zatím žádné. Připravené kontaktní archy jsou obrazové vstupy, nikoli simulační důkaz. Hráčovy uložené hry se neměnily.

## 3. Společné kontroly ve hře

| Kontrola | Scénář | Výsledek a důkaz |
|---|---|---|
| Čitelnost a měřítko | Běžný zoom, oddálení, detail, okolní osada | Neověřeno |
| Alfa a filtrace | Světlý, tmavý a herní podklad, vnitřní otvory a okraje | Neověřeno |
| Kontakt se zemí | Rovina, vyvýšená rovina a povolené svahy | Neověřeno |
| Řazení a terén | Před/za objekty, vyvýšený terén, přesahy klády | Neověřeno |
| Kotvy a vrstvy | Všech 8 směrů, fází, přechody klipů, stabilita nákladu | Neověřeno |
| Klikání a výběr | Obrys, průhledné okolí, náklad a překryté objekty | Neověřeno |
| Mlha a soukromí | Vlastní/cizí jednotka, viditelné/prozkoumané/neznámé místo, interiér | Neověřeno |
| Světlo a stíny | Den/soumrak/noc, tónování a absence dvojitého stínu | Neověřeno |
| Čas a skutečný stav | Pauza, rychlosti, zastavení, převzetí a odevzdání | Neověřeno |
| Uložení a pravidla | Uložit/načíst během nesení, pokračovat bez změny nákladu či pohybu | Neověřeno |
| Běžná scéna a výkon | Více jednotek, kamera, zoom, chybějící data a paměť | Neověřeno |

## 4. Použitelné větve podle objektu

| Větev | Pokrytí | Výsledek |
|---|---|---|
| Jednotka | 8 směrů × 8 fází, náklad a jeho nosná ruka, stejná identita a tělesné měřítko, opačné poloviny kroku, přechod 07→00 | Statická kontrola všech osmi archů provedena; logika 64 fází náhledu ověřena. Přehrání v prohlížeči a herní pohyb neověřeny |
| Jednotka — hra | Přechod bez klády/s kládou, rychlost a interpolace, došlapy, interiér, skutečné předání | Neověřeno |
| Budova — stavba/provoz | Není budova | N/A — tento objekt je jednotka |
| Strom | Není strom | N/A — náklad je součást klipu jednotky |
| Statická rekvizita | Není samostatná statická rekvizita | N/A — kláda je nesený náklad |

## 5. Důkazy a přesný rozsah testů

| Běh/kontrola | Skutečný rozsah | Výsledek |
|---|---|---|
| Technická příprava vstupů 2026-09-10 | Změřeno 16 archů 1792×1088; porovnáno 64 vlastních vložených výřezů a SHA256 všech 128 vstupních PNG před/po přípravě | Podklady připraveny beze změny zdrojů; **není QA výsledné animace** |
| Technická kontrola finálních PNG/GIF/manifestu | Všech 64 PNG a 8 archů, 64 buněk atlasu, 16 GIFů, zdrojové i výsledné SHA256 a reprodukce registrace | **Prošlo**, [pack-validation.json](../../animations/lumberjack-with-log-kam-v1/pack-validation.json) |
| Statická diagnostika registrace | 8 archů čepic = 64 komponent; N/NE/NW upravený HSV podle barvy. Jednotlivé S/02 a S/06 pro kontrolu střídání stehen | Prohlédnuto; čepice správně vybrané, S střídá anatomickou pravou/levou nohu. Neprokazuje celý pohyb ve hře |
| Statická výtvarná kontrola hlavním agentem | Všech osm finálních směrových archů N/NE/E/SE/S/SW/W/NW; kláda, nosná paže, vzhled a nohy | Prohlédnuto. Kláda a její podpora staticky zkontrolovány; doplňující nezávislá kontrola S/SW/SE potvrdila opačné podpěrné nohy v 02/06. Následná připomínka uživatele odhalila chybnou návaznost SE6→7→8; dřívější dílčí kontrola ji nezachytila, viz aktuální revize |
| Technická kontrola samostatného HTML náhledu | Velikost dle preview-validation.json, 16 obrázků dekódováno; 64 shodných dvojic fází, správné archy/výřezy, návrat 07→00, 2/5/10 fps a pauza při změně směru/skrytí | **Prošlo v Node VM s explicitními náhradami DOM/Image/timer**, [preview-validation.json](../../animations/lumberjack-with-log-kam-v1/preview-validation.json); nejde o test skutečného prohlížeče |
| Přehrání HTML ve skutečném prohlížeči | Vizuální plynulost, vyhlazování, interakce v konkrétním runtime | Neověřeno; `browserRuntimeVerified: false` |
| Zaměřené testy / regrese | [Testovací dokumentace](../../../../tests/README.md); relevantní případy teprve určit při případné integraci | Neověřeno — testy hry nebyly pro tuto dodávku spuštěny |
| Nativní grafické kontroly a běžná hra | Produkční cesta rendereru a skutečné herní pixely | Neověřeno |

Finální manifest a ověřené otisky jsou odkázány výše. Každý z 16 GIFů má skutečně 8 snímků; při 5 fps je délka 1600 ms (8×200 ms), při 10 fps 800 ms (8×100 ms). Zpětně dekódované pixely souhlasí s PNG převedenými společnou paletou příslušného směru. Všech 64 buněk atlasu a směrových archů souhlasí pixelově s finálními PNG. Při opakování uloženého měřítka, posunu a explicitních finálních náhrad vzniknou stejné pixely; diagnostický obrys minRGB <230 není nikde oříznut. Herní důkazy nejsou dodané. Tempo samostatného náhledu se musí uvést jako ilustrační; nesmí být označeno za změřené sladění s herním pohybem. Nezávislé očekávané pixely, pozitivní kontrola herního renderu a tolerance: **neověřeno**.

## 6. Výsledek této verze

Aktualizace 2026-09-10: uživatel po první opravě fáze 7 upozornil také na
prohození identity nohou mezi fázemi 6–7–8. První oprava proto byla nahrazena
společným překreslením fází 7 a 8 od kyčlí; samotné přidání viditelné boty
návaznost nevyřešilo. Aktuální revize a rozsah kontroly jsou níže.

| Rozhodnutí | Stav |
|---|---|
| Technická integrace | Neověřeno; není součástí nynějšího zadání |
| Provedená vizuální kontrola | Všech 8 diagnostických archů čepic a 8 finálních archů, doplňující kontrola opačných nohou S/SW/SE. Statické nálezy nejsou výsledkem přehrání nebo herní integrace |
| Vizuální přijetí uživatelem | Neuděleno pro tento nový klip |
| Otevřené oblasti | Chybějící skutečná alfa, běh a vizuální přehrání náhledu v prohlížeči, fyzická věrnost došlapů a všechny herní kontroly. Technické kotvy, počty a časování ilustračních GIFů jsou ověřeny; statické prohlédnutí neznamená přesné trasování KaM ani schválení uživatelem |
| Použití jako společný etalon | Ne — tato verze zatím není schválená |

### Technické předání — 2026-09-10

- Balicí postup: `docs/art/animations/lumberjack-with-log-kam-v1/pack.py`; normalizace celého zdroje na 1792×1088 Lanczos → osm buněk 448×544 → jedno společné tělesné měřítko směru → celočíselné posuny podle čepice. `raw/` znamená výřezy normalizovaného archu; původní `sources/` se nemění.
- Kotva všech finálních snímků: **[216,400]**. Barevná maska slouží jen měření; nezměnila raster. Není zamčená bota ani vystředěný obal klády.
- Všech 64 finálních PNG a 8 archů je RGB bez skutečné alfy; atlas **3584×4352** má řádky N/NE/E/SE/S/SW/W/NW a sloupce 00–07.
- Atlas SHA256: `ed53c607dda42df21f4845a1bd6cea792113559020453397c5d9b05e400e78fb`. Další otisky jsou v manifestu a technické validaci.
- [Aktuální porovnání třetí/sedmé fáze](../../../../original_game_data/kam-reference-export/lumberjack-full-set/carry-guides-8x/feet-phase-3-7-comparison.png) se obnovuje při balení a obsahuje původní KaM, vstupní vlastní chůzi a výsledek; číslování 3/7 odpovídá souborům 02/06, legendy jsou mimo postavy. Jde o externí referenční obraz uložený mimo distribuované vlastní assety. Při hodnocení nohou je nutné sledovat návaznost stehna k pánvi, nikoli samotnou globální souřadnici boty.
- Kontrola nevstupovala do hry, neověřovala browser smoothing a nevydává výsledek za produkční nebo uživatelsky schválený.

### Změřené soubory a otisky — 2026-09-10

Otisky v této tabulce jsou obnovené po společné opravě SE/06 a SE/07.

Tabulka identifikuje předanou verzi. [Manifest](../../animations/lumberjack-with-log-kam-v1/manifest.json) navíc obsahuje individuální SHA256 všech 64 finálních PNG, 64 normalizovaných výřezů, osmi generačních zdrojů a 16 GIFů; není tím přepsán jejich skutečný původ. HTML obsahuje původní externí referenční guides a zmenšené WebP vlastní kresby 1120×680 při kvalitě86. Náhledové zmenšení nemění plnohodnotné PNG; společná oprava SE/06 a SE/07 je zaznamenaná níže.

| Soubor / sada | Velikost B | SHA256 |
|---|---:|---|
| [manifest.json](../../animations/lumberjack-with-log-kam-v1/manifest.json) | 128946 | `2a7dd55b72fac347cd82e2358ef8855bae6a33aff22513c11f95306f87f0797b` |
| [registration.json](../../animations/lumberjack-with-log-kam-v1/registration.json) | 84553 | `ac602c2ad787bb95c17a1f72a21151d55f9e181924e3005f7e3c4f86c4914173` |
| [pack-validation.json](../../animations/lumberjack-with-log-kam-v1/pack-validation.json) | 25294 | `58f006addbc3e13f80d2edd34721174bbca50b95eecc793914dc259f89efffd6` |
| [preview-validation.json](../../animations/lumberjack-with-log-kam-v1/preview-validation.json) | 1264 | `4b11c7afe32ec0edd1086162f992b84815defaf260d737557744f2e79ca2bf89` |
| [sprite-atlas.png](../../animations/lumberjack-with-log-kam-v1/sprite-atlas.png) | 11748089 | `ed53c607dda42df21f4845a1bd6cea792113559020453397c5d9b05e400e78fb` |
| [directions-overview.png](../../animations/lumberjack-with-log-kam-v1/directions-overview.png) | 480335 | `888f6a089910c362c0dc2b02b88565d965ce3f27f13ac0c2f0ba76e6a1c84618` |
| [sheets/N.png](../../animations/lumberjack-with-log-kam-v1/sheets/N.png) | 1329993 | `b37c6b359b27ff82a6e1ae420c4a9cb3b1a87a34db028534f6a5c3b8cabbca7d` |
| [sheets/NE.png](../../animations/lumberjack-with-log-kam-v1/sheets/NE.png) | 1457410 | `4c27b06fc28cd59c0c133eba412f541db03809eddc68a13e3f00c3a7034fe1ea` |
| [sheets/E.png](../../animations/lumberjack-with-log-kam-v1/sheets/E.png) | 1728762 | `24484f956d1c0cbd46a57c8f24e7ba2cdd78bca1218e8300ea04b53875a723b1` |
| [sheets/SE.png](../../animations/lumberjack-with-log-kam-v1/sheets/SE.png) | 1782733 | `da182da1265eb14a16ca72de52fc8f0d0a818de5fae75e1c2b46d4966e112f73` |
| [sheets/S.png](../../animations/lumberjack-with-log-kam-v1/sheets/S.png) | 1306554 | `9078c5ba577cf444e36f7e082248edcbac55ed82f096af10ce4a46c89399e9b5` |
| [sheets/SW.png](../../animations/lumberjack-with-log-kam-v1/sheets/SW.png) | 1313971 | `aeab810ac9e4d92a1fd38d5d434b431fc33d2f4107a1bfdc73501b7170331994` |
| [sheets/W.png](../../animations/lumberjack-with-log-kam-v1/sheets/W.png) | 1425318 | `749ae04db152c54b4c51427012f3d7b76a29f191f384e00af6435bbd92268cf5` |
| [sheets/NW.png](../../animations/lumberjack-with-log-kam-v1/sheets/NW.png) | 1404414 | `d3e10647fe7a72298ad0354a96e03c72b6eb969db7221c2769ec94b65429f5eb` |
| [Samostatný HTML náhled](/Users/openclaw/.codex/visualizations/2026/09/09/01a087a4-bf3d-7f70-b463-afa4f5165f3c/lumberjack-carry-eight-directions.html) | 833824 | `1bed695cf30de83dc8edff44119d18fcf71880ac3d6e44f3060ca470c425de8d` |

### Revize návaznosti SE, fáze 6 → 7 → 8 → 1 — 2026-09-10

- Předchozí izolovaná oprava sedmého snímku je překonaná. Její prompt nesprávně označil bližší nohu jako levou a vzdálenější jako pravou. Dřívější kladný závěr o návaznosti se stahuje; původní pixely jsou zachované v `rejected/SE-before-leg-continuity/`.
- Správné anatomické vodítko: bližší **pravá kyčel** leží pod zdviženou pravou paží na levé straně obrázku. V 6 pravá noha zůstává vzadu a levá nese váhu. V 7 se pravé stehno a koleno posunují před vzdálenější levé stehno, pravé lýtko zůstává pokrčené s menší botou vzadu. V 8 se tato pravá noha natahuje dopředu a levá přechází dozadu. V následující 1 zůstává pravá vpředu. Toto je staticky sledovaná identita končetin, nikoli měření sil nebo přesného okamžiku přenosu váhy.
- Dvě nová volání vestavěného generátoru: [překreslení obou fází od kyčlí](../../animations/lumberjack-with-log-kam-v1/prompts/SE-phases-07-08-leg-continuity.txt) a [oprava proporcí](../../animations/lumberjack-with-log-kam-v1/prompts/SE-phases-07-08-proportions.txt). První dvojice zachovala návaznost, ale prodloužila dolní polovinu asi o 30 px; vybraný druhý výstup ji zkrátil. Počet celé dodávky je 13 volání, přesný model nástroj neuvádí.
- Vybraný [zdroj](../../animations/lumberjack-with-log-kam-v1/sources/SE-phases-07-08-proportions.png) má 1610×977 RGB. Celý pár je normalizovaný Lanczos na 896×544 a rozdělený na dvě buňky. Následují pouze celočíselné posuny **[−9,0] / [+3,+1]** vůči základní čepicové registraci; žádné selektivní deformování končetin nebo programové překreslení. Přesná měření: [SE-leg-continuity-registration.json](../../animations/lumberjack-with-log-kam-v1/SE-leg-continuity-registration.json).
- Hlavní a nezávislý výtvarný agent prohlédli novou dvojici a sousední fáze; [kontaktní sekvence 6–7–8–1](../../animations/lumberjack-with-log-kam-v1/diagnostics/SE-phases-06-07-08-01-continuity.png) ukazuje vybrané pixely po registraci. Identita končetin zůstává čitelná; pravé koleno v 7 je výrazněji zakulacené a pokrčené než v drobné KaM předloze, jde o přibližnou interpretaci. Oproti předchozí kresbě je vzdálenost pas–podrážka nové 7 přibližně +1,6 %, nové 8 −0,3 %. Čepice má vyšší barevný obal a výtvarná shoda horní poloviny není pixelově přesná. Čepicové horní řádky jsou oba 91 px; středy vůči základu −0,40 / −0,14 px. Nejnižší pixel boty je 422 / 428 px, dříve 415 / 423 px; nezamykali jsme jednotlivou botu ani neměnili délky končetin kódem.
- Finální náhrady jsou `final-frame-overrides/SE/06.png` a `07.png`; technické balení je aplikuje před sestavením archu, GIFů a atlasu. Ověřeno: oba snímky bytově souhlasí s náhradami; ostatních 62 finálních PNG, 64 raw výřezů, osm původních směrových zdrojů a registration.json jsou beze změny. Všech 64 buněk archů a atlasu i 16 GIFů souhlasí s výslednými PNG. Aktuální kontrola proti uloženému výchozímu stavu je v [pack-validation.json](../../animations/lumberjack-with-log-kam-v1/pack-validation.json).
- Náhled začíná na SE / fáze 6, pozastavený, s tempem 2 snímky/s; má také 5/10 snímků/s a ruční krokování. [preview-validation.json](../../animations/lumberjack-with-log-kam-v1/preview-validation.json) uvádí přesnou velikost, otisk, dekódování a provedenou kontrolu ovládání. Běh ve skutečném prohlížeči a herní došlapy zůstávají neověřené; tato revize není uživatelským výtvarným přijetím.
