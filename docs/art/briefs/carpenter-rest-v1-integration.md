# Implementace objektu: tesař, domácí odpočinek v1

Datum **2026-09-12** · role `carpenter` · druh: vrstva jednotky u pily.
Stav **produkční RGBA a tři pohledy ověřeny**, podle [implementační šablony](../object-integration-template.md).
[Výtvarný a stavový brief](carpenter-rest-v1.md) · [QA](../qa/carpenter-rest-v1/README.md).
Nezávislé dekódování PNG v Godotu prošlo 2026-09-12. Normální herní QA
včetně výsledného opření postavy patří do [integrace pily](sawmill-v1-integration.md).

## 1. Rozsah a autority

Uživatel zadal návrh tesaře pro odpočinek doma u pily a potvrdil rovnou
zapojení do hry včetně denních/nočních stavů. Jde o existující roli,
samostatnou malovanou pózu a pohledy; není to nová chodící jednotka.
Identitu určuje [brief](carpenter-rest-v1.md); geometrii domu a dveří
[brief pily](sawmill-v1.md). Simulace a `inside_building_id` zůstávají autoritou
skutečné přítomnosti. Pouhé přiřazení domácího pracovníka nestačí.

## 2. Geometrie a registrace

| Kontrakt | Hodnota / evidence | Stav |
|---|---|---|
| Stávající referenční atlas | `carpenter`, skutečný reader region `[684,676,163,306]`; [extrakce](../sources/carpenter-rest-v1/current-carpenter-extraction.json) | Změřeno 2026-09-12 |
| Stávající referenční velikost | 17.5784 × 33 world px; celá stará kresba včetně pily | Změřeno readerem |
| Nové body-only měřítko | Zdrojové vlasy y94, nosná podrážka končí posledním neprůhledným řádkem1373, fyzický okraj y1374; 1280→165→33 world px | Změřeno na vlastním RGBA |
| Půdorys, vstup a terén pily | Odkaz na [geometrii pily](../qa/sawmill-v1/geometry.json); žádná změna kolize | Autorita existuje |
| Opora | Přední levý sloupek vlevo od dveří; boty uvnitř obsazené země | Návrh, finální kontakt nezměřen |
| Nový canvas, alfa meze, práh | 256²; alfa>0 `[96,37,156,208]`, alfa>25 `[99,40,154,206]`, meze výlučné; 59 615 nulových / 1 320 částečných / 4 601 neprůhledných pixelů | Změřeno, nezávisle dekódováno Godotem |
| Zdrojová kotva, trim, měřítko | Zdroj `[551,1374]`→produkce `[133.02734375,205.1171875]`; celý1024×1536→132×198 položen v `[62,28]`, bez trimu; produkce→svět0.2 | Změřeno nezávisle pro tesaře |
| Hloubka / fyzický kontakt / stín | Oddělené; kresba používá převod domu, nedefinuje novou mapovou polohu | Neověřeno v obrazu |
| UI a klikání | Žádný druhý hit target ani indikátor skryté jednotky | Neověřeno |
| Střešní přesahy | N/A — charakter nemá střechu; usazení u domu ověřit s jeho geometrií | N/A |

První celou pózu registrovat u finálního domu a prohlédnout při 33 world px
před odvozením dalších hlav. Ověřit na rovině a hraně vyvýšeného základu.
Horní záda musejí působit podepřeně a boty stát na skutečné zemi; vizuální
sort posun nesmí být vydáván za výškovou projekci.

## 3. Stavy a vrstvy

Stavební fáze jsou N/A: tento asset je postava a kreslí se teprve u skutečně
dokončené pily. Její práce ani poslední konstrukční obraz se tím nemění.

| Vrstva | Zdroj stavu | Registrace / právo zobrazení | Dodáno |
|---|---|---|---|
| Tělo a střední hlava | Skutečný denní domácí odpočinek bez nákladu | Vlastní známá budova; podle foot anchor tohoto tesaře | Ano, PNG a JSON |
| Pohled vlevo/vpravo | Tentýž odpočinek a existující simulační čas | Měnit jen hlavu, zachovat trup a nohy | Ano, 2 PNG, pod límcem a v nohách0 změněných pixelů |
| Noční světlo/kouř/okno | Samostatné vrstvy pily | Nejsou součástí charakterového PNG | Patří do integrace pily |

Při cizí budově v aktivní mlze nesmí vykreslení číst skrytého obyvatele.
Při odchodu, práci, nákladu, spánku nebo rozestavění končí odpočinková vrstva.
Osobní neaktivita se liší od globální pauzy; globální pauza zmrazí pohledy.
Kreslení nesmí měnit práci, zásoby, čas, polohu ani snapshot.

## 4. Soubory a převod

Vlastní výchozí atlas a jeho technická extrakce jsou zachované v
`docs/art/sources/carpenter-rest-v1/`. [Záznam zdroje](../sources/carpenter-rest-v1/README.md)
odděluje zdrojovou vlastnost od připraveného produkčního spritu.
Nový imagegen master, skutečná zadání a hashe:
[provenance](../sources/carpenter-rest-v1/prompts.json).
Přesný technický export: [exporter](../sources/carpenter-rest-v1/export-resting-carpenter.cjs).
Vstupy jsou RGB s technickou magentou. U celého tesaře naměřené modální
pozadí `[252,4,251]`, prázdný levý pás dominance206–251, vlasový vzorek−77…−10;
práh198. U hlav jiné modální pozadí `[247,4,248]`, prázdné horní a levé plochy
minimálně217; práh205. Použito vyjmutí klíče a straight-alpha unmatte.
Žádná kontrolovaná produkční hlava nemá zbytek magenty dominance>45 při alfa>25.

Existující exporter dřevorubce používá Node + Sharp a je pouze příklad:
`docs/art/sources/lumber-hut-life-v1/export-resting-lumberjack.cjs`.
Jeho magenta práh, pozadí, trim, velikost, kontakt i maska hlavy jsou
specifické pro tehdejší obrázek. U tesaře je nutné nově změřit všechny.
Ověřit celý alfa kanál i otvor mezi nohama na světlém/tmavém/herním podkladu.
Varianta hlavy musí mít mimo vlastní změřenou masku přesně původní RGBA pixely.

## 5. Napojení a kompatibilita

Běžná cesta je menu → `game_session.tscn` → `main.tscn` → skutečná pila
a její obyvatel. Reader života pily a přesné runtime cesty: **doplnit po
zapojení**. Pouhé přejmenování souborů dřevorubce není integrace tesaře.
Assety načíst do sdílené cache, žádné dekódování obrázku při každém snímku.
Reset po načtení musí respektovat aktuální simulační čas a pobyt.
Samostatný distribuční export není součástí nynějšího požadavku.

## 6. Předání

Přesné ověřené PNG/JSON a runtime otisky, skutečný testovací průchod a
nativní snímky doplnit do [QA](../qa/carpenter-rest-v1/README.md).
Technický výsledek: **PNG a JSON prošly nezávislým Godot dekódováním; 3/3 pózy,
skutečná alfa, pozitivní trup a podrážka, tělo bez změn, vlastní33px měřítko**.
Vizuální výsledek nové pózy: **prohlédnut master, tři podklady a zvětšení hlav,
skutečné natočení je čitelné, opření v herní pile ještě v jejím QA**.
Uživatelské přijetí konkrétní pózy / etalonu: **neuděleno**.
