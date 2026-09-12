# Dřevorubec PixelLab v2 · nativní QA skutečného jižního pilotu

2026-09-10 · podle [QA šablony](../../object-qa-template.md).
**Dílčí dodávka: `walk_axe/S`, 1 z 24 kombinací klipu a směru.**
Tento záznam neoznačuje kompletní sadu ani běžnou herní integraci za hotovou.

## 1. Přesný předmět a podklady

| Údaj | Ověřená verze |
|---|---|
| Objekt | Jednotka `lumberjack`; chůze se sekerou na jih |
| Zadání / integrace | [Produkční v2](../../briefs/lumberjack-pixellab-production-v2-integration.md), [samostatný Godot reader](../../briefs/lumberjack-pixellab-v2-godot-reader.md) |
| Výběr | Výslovné zadání root agenta 2026-09-10: raw 1–24; vstupní raw 00 uchovat jako referenci |
| Autorita výběru | [selection.json](../../animations/lumberjack-pixellab-production-v2/pilot-walk-S/selection.json), [scope.json](../../animations/lumberjack-pixellab-production-v2/pilot-walk-S/scope.json) |
| Původ | Skutečný PixelLab job [walk_axe/S](../../animations/lumberjack-pixellab-production-v2/jobs/walk_axe/S/images.json); žádné nové generování při balení |
| Balík | [pilot-walk-S/package/manifest.json](../../animations/lumberjack-pixellab-production-v2/pilot-walk-S/package/manifest.json); oddělený od budoucí kompletní sady |
| Runtime kopie | [game/art/units/lumberjack-pixellab-v2/manifest.json](../../../../game/art/units/lumberjack-pixellab-v2/manifest.json), shodné PNG bajty s vybranými raw snímky |
| Přesné otisky | [pilot-integrity.json](pilot-integrity.json), [nativní manifest](native-capture-manifest.json), [kontrola packeru](../../animations/lumberjack-pixellab-production-v2/pilot-walk-S/pack-validation.json) |
| Prostředí | Godot 4.7.2, macOS, Apple M4, OpenGL Compatibility, okno 1240 × 880 |
| Čtenář / scéna | Nové `lumberjack_animation_library.gd` a `preview_pixellab_lumberjack.tscn`; hlavní hra se nespouští |
| Importovaná instance | Nový editorový import a nový nativní proces; manifest hash je v evidenci zachycených snímků |

| Kontrakt | Hodnota a stav |
|---|---|
| Počty | Změřeno 25 raw; vybráno 24; runtime index 0 odpovídá raw 1, index 23 raw 24 |
| Zdrojové plátno / atlas | Změřeno 256 × 256 / 6144 × 256 px; žádný ořez ani posun jednotlivých snímků |
| Tělesné měřítko | Zadaných 163 source px → 33 world px; `33/163 = 0,202454` world px/source px |
| Kotva | Zadaných `(128,205)` source px; **předběžná**, kontakt vůči skutečnému terénu neověřen |
| Alfa | Všech 24 fází má viditelný obsah a skutečnou průhlednost 0/255; nula viditelných pixelů na hranici plátna |
| Viditelné meze | Alfa ≥1, pravá/dolní hranice výlučná: levá 83–84, horní 46–52, pravá 170–172, dolní 199–215 source px |
| Tempo | 12 fps, 24 snímků = dvousekundová smyčka; tempo není navázáno na simulační pohyb |
| Klid | `rest_frame=0` znamená první vybraný generovaný snímek raw 1; původní vstup raw 00 se v runtime nepoužívá |
| Řazení / kolize / stín | Nezapojené v samostatné ukázce; čtenář pouze vrací obrazový obdélník vůči dodaným chodidlům |

## 2. Běžná herní cesta

**Neověřeno.** Byla spuštěna samostatná scéna prohlížeče assetů, nikoli
menu → mapa → pracovník. Simulace nepřemisťovala postavu, nekácela strom,
nenesla kládu ani neukládala hru. Fixní střed každé karty je pomocná
kontaktní kotva ukázky. Hráčova uložená data se neměnila.

Packer výslovný rozdíl **25 raw / 24 vybraných** podporuje a doběhl bez
varování. Původní snímky nebyly měněny; všechny kopie a atlasová políčka
jsou ověřené proti originálu. `pilot-walk-S/jobs` je lokální symlink na
`../jobs`, aby zdrojové odkazy packeru stále vedly k původním datům.

## 3. Společné kontroly

| Kontrola | Výsledek a důkaz |
|---|---|
| Čitelnost a měřítko | **Prošlo v samostatném náhledu.** Při 1× je postava čitelná jako člověk; sekera je už velmi drobný detail. Při 3× jsou čitelné oddělené nohy, ruce a pravostranná sekera. [1× na zelené](walk_axe-green-1x.png), [3× detail](walk_axe-dark-3x-phase-25.png). Čitelnost proti skutečné osadě není ověřena. |
| Alfa a filtrace | **Prošlo v dodaném rozsahu.** PNG, atlas i dekódované APNG zachovaly původní RGBA. Native dark/green nemají obdélníkové pozadí. Preview používá nearest filtr. Světlý herní podklad neověřen. |
| Kontakt se zemí | **Neověřeno ve hře.** Pevná kotva je správně aplikovaná, spodní meze chodidel se v kroku mění; samotný křížek nedokládá kontakt s rovinou nebo svahem. |
| Kotva a základní stabilita | **Prošlo technicky.** Žádný individuální trim, bob, zrcadlení či root posun. V kontaktovém archu drží trup stejný směr a přibližnou šířku. Rozsah horizontálních mezí činí pouze 1–2 source px. Změny horní a spodní meze se nesmějí používat jako automatická korekce kotvy. |
| Návaznost smyčky | **Částečně ověřeno.** Správné přetočení runtime 23→0. Průměrná celoplátnová RGBA změna raw24→raw1 je 3,79883 proti mediánu ostatních sousedních změn 4,24739; přechod není číselný extrém. To není úplný posudek přirozenosti chůze. |
| Čas a ovládání | **Prošlo v prohlížeči.** Pauza zachová přesný čas, ruční krok přejde na další fázi, klid respektuje index 0 a dvojnásobné tempo posune čas 2×. [Log](playback-controls.log). |
| Řazení a terén | **Neověřeno:** samostatný prohlížeč nemá terénní vrstvy. |
| Výběr / klikání | **Neověřeno:** prohlížeč nemá výběr herních pracovníků. |
| Mlha / soukromí / interiér | **Neověřeno:** žádná herní větev není zapojená. |
| Světlo / stíny | **Neověřeno:** neutrální ukázka bez hry a slunečních stínů. |
| Uložení / pravidla | **Neověřeno:** žádná změna simulace nebo save. |
| Běžná scéna / výkon | **Neověřeno:** byl importován jeden atlas a zobrazen jeden dostupný směr. |

Při prvním nativním běhu se projevil projektový viewport stretch. Prohlížeč
jej nyní vypíná **pouze ve svém okně**, aby při 1× jeden world px odpovídal
jednomu pixelu uloženého snímku. Výsledné soubory v tomto záznamu jsou
z nového běhu po této opravě; nastavení hlavní hry se nezměnilo.

## 4. Větve objektu

- **Jednotka:** dodán pouze jižní `walk_axe`; ostatních 23 kombinací je
  v prohlížeči a manifestu výslovně označeno jako chybějících. Přechody na
  práci, náklad, ostatní směry a interiér nejsou ověřené.
- **Budova / konstrukce / provozní vrstvy / strom / statická rekvizita:**
  N/A — tento pilot je animace pohyblivé jednotky.

## 5. Důkazy a reprodukce

| Kontrola | Skutečné pokrytí | Výsledek |
|---|---|---|
| Packer | Raw 0–24 přečtené; výslovně vybrané 1–24; kopie PNG, každý atlasový region a dekódovaný APNG | Prošlo, žádná varování, zdroje nezměněny |
| Headless reader | 24 z 24 vybraných políček, alfa, hash, registrace, časový výběr, přetočení, klid | Prošlo; [log](headless-validation.log) |
| Ovládání času | Pauza, jeden krok, klid, tempo 2× při skutečném načteném pilotu | 4/4 prošlo; [log](playback-controls.log) |
| Native captures | Pět PNG v Godotu, čtyři fáze při 3× a jedna při 1× | Prošlo; všechny výsledné PNG prohlédnuty, [log](native.log) |
| Kontaktový arch | Všech 25 raw fází včetně oddělené reference 00 | [Prohlédnutý zdrojový arch](../../animations/lumberjack-pixellab-production-v2/jobs/walk_axe/S/qa/contact.png) |
| Běžná hra / kompletní regrese | Nespouštěno; hlavní herní kód se neměnil | Neověřeno |

Nezávislá pozitivní kontrola: skutečné nenulové RGBA pixely vybraných
originálů byly porovnány s PNG kopiemi a atlasovými regiony; všechny sedí.
Ve výsledném nativním snímku je konkrétní postava v kartě S, ne prázdný
panel. Screenshoty mají skutečné indexy `[0,6,12,18]` = raw `[1,7,13,19]`;
nepředstavují nativní snímek každé fáze. [Manifest zachycení](native-capture-manifest.json)
uvádí rozměry, GPU, hashe a `simulated_gameplay=false`.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game res://tools/preview_pixellab_lumberjack.tscn -- --validate-only
/Applications/Godot.app/Contents/MacOS/Godot --path game res://tools/preview_pixellab_lumberjack.tscn
```

Bezeztrátové přehrání originálů: [HTML pilot](../../animations/lumberjack-pixellab-production-v2/pilot-walk-S/preview/index.html)
a [24fázové APNG](../../animations/lumberjack-pixellab-production-v2/pilot-walk-S/preview/walk_axe/S.apng.png).
Přehrání webového náhledu není běžná hra.

## 6. Výsledek této verze

| Rozhodnutí | Stav |
|---|---|
| Technická dodávka pilotu | **Prošla:** importovatelný RGBA atlas a 24 fází v samostatném Godot readeru |
| Technická integrace do hry | **Neúplná / nezapojená**, záměrně mimo tento pilot |
| Vizuální kontrola | Prohlédnuty všechny raw fáze v archu a pět nativních snímků; základní tělo a nástroj drží, při 33 px je sekera malá |
| Přijetí uživatelem | **Neuděleno** pro tuto přesnou dodávku |
| Neověřené oblasti | Zbývajících 23 kombinací, úplná přirozenost pohybu, kontakt s terénem, práce u stromu, skutečný náklad a běžná herní cesta |
| Společný výtvarný etalon | **Ne**, tento dílčí technický pilot nezakládá schválení sady |
