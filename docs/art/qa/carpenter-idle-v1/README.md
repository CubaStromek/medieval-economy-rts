# Truhlář — kontrola klidové animace

Datum **2026-09-13**, objekt `carpenter`, pila v2. [Integrační záznam](../../briefs/carpenter-idle-v1-integration.md)
navazuje na vlastní [odpočinkový podklad](../../briefs/carpenter-rest-v1.md)
a [usazení a stíny](../carpenter-sawmill-spatial-v1/README.md).
Rozsah: jemný dech a pohyb ramen existující postavy; původní PNG zachovány.
Záznam používá [objektovou QA šablonu](../../object-qa-template.md).

## Geometrie a ověřená verze

Nativní Godot 4.7.2, macOS / Apple M4, Compatibility/OpenGL, viewport
1152 × 720, skutečný zoom 2.4. Nová instance spustila současný Main z menu.
[Report](natural/report.json) uvádí stav každého snímku i otisky runtime,
manifestů a obrázků; [finální ověření](verification.json) potvrdilo shodu
s aktuálními soubory. Jde o necommitnutou pracovní verzi identifikovanou SHA-256.

Zdroj 256², výška postavy 165 source px → 33 world px. Původní měřený
kontakt `[133.02734375, 205.1171875]` zůstává pevný. Ve skutečném záznamu
má světovou polohu `[446.735504, 206.924500]`, na obrazovce
`[625.061646, 505.624176]`. Horní část těla do source y108 se posune nejvýše
o `[+0.6, −1.5]` source px; přes zástěru do y142 se pohyb utlumí na nulu.
Cyklus trvá 4.8 s. Autoritativní nastavení je v manifestu odkazovaném briefem.

Půdorys, obrazový pivot, řazení domu i samostatné kontaktní stíny se zachovávají.
Nový koncept, měření stavebních variant a kolize jsou N/A: nevznikla nová kresba
ani stavební fáze. Všechny dříve doložené art PNG mají shodné otisky.

## Skutečná hra

Menu → Relief → truhlář 20 / dům 4 → příchod domů v ticku 1 → 12 s odpočinku
při rychlosti 1× → skutečná pauza → pokračování → dodávka klády nosičem → práce
v ticku 236. Bez ručního posouvání ticků a přepisování pracovníka či zásob.
Hráčovy uložené hry se neotevíraly. [Nativní log](natural/native.log): **0 selhání**.

181 pozorování zachytilo všechny tři pohledy hlavy, 180 různých posunů horního
těla a neměnnou polohu kontaktu i obrazové registrace. Během celého úseku
byl obyvatel skutečně doma, bez klády a rozpracované dávky; neexistovala druhá
venkovní kopie. Globální pauza po 727 ms zachovala stav i RGBA výřezu přesně.
Po začátku práce je domácí idle skrytý a zobrazí se pracovní figura.

## Vizuální a funkční kontroly

| Kontrola | Výsledek a důkaz |
|---|---|
| Čitelnost a postoj | Prošlo: [skutečná scéna](natural/day-rest.png), [šest výřezů](idle-samples.png). Jemný posun ramen při opřeném postoji; hlava a krk zůstávají spojené |
| Alfa a návaznost pásů | Prošlo: stejné zdrojové alfy, navazující geometrie a barvy podle UV. Ve prohlédnutých výřezech nevznikla mezera v zástěře ani oddělená hlava |
| Nohy, podklad a stíny | Prošlo: všechny skutečné snímky mají stejný kontakt; samostatný nativní pixelový test mění ramena a nechává celou dolní oblast od y142 i stíny byte-identické |
| Řazení a vrstvy | Prošlo v zachyceném domě: původní sokl a vstup. Nový běh na svazích nebyl proveden; jejich dřívější kontrola je v prostorové revizi a nejde o nové měření |
| Klikání | Prošlo ve výpočtových testech: nezávislé očekávané body horní části, přechodu, pevné nohy i okrajů; inverze vrací správnou zdrojovou masku. Ruční klikání nebylo nově zaznamenáno |
| Mlha a neaktivní stavy | Prošlo: cílené testy odmítají pohyb při `known=false`, `rest_visible=false` a neplatné konfiguraci; plná sada pokrývá stávající skrytí |
| Světlo | Prošlo v zachyceném svítání; původní lokální gradient a stín. Samostatný nový noční průchod neproveden, dřívější noc doložena v prostorové revizi |
| Čas a stav hry | Prošlo: živý dech i rozhlížení, skutečná pauza zastaví oba; čtení pohybu nemění serializovaný svět |
| Uložení | Nový idle nebyl samostatně zaznamenán po save/load. Používá existující uložený čas bez nového save stavu; plná regresní sada prošla |
| Běžná scéna | Prošlo: původní Relief, další obyvatelé a nosič, skutečná dodávka a přechod do výroby. Výkonový benchmark není součástí této revize |

Root prohlédl skutečnou scénu a šest výřezů pokrývajících nejmenší/největší
zachycený dech pro každý pohled hlavy. Výřezy jsou pouze technicky zvětšené
pixely z nativního záznamu. Nezávislý read-only review kódu (`sawmill_integration`)
nenašel konkrétní chybu v geometrii, inverzi, stínech ani přechodu do práce.

## Testy a video

| Běh | Výsledek |
|---|---|
| `./tests/run-headless.sh` | **859/859**, [čistý log](full-headless.log); 3 nativní pixelové případy výslovně vynechány a nezapočítány |
| `res://tests/sawmill_revision_runner.tscn -- --expected-art=v2` | **49/49**, [čistý log](focused-native.log), včetně všech 3 nativních pixelových kontrol |
| `res://tests/carpenter_idle_game_runner.tscn -- --output=<natural> --zoom=2.4` | **181 idle snímků, 0 selhání**, [report](natural/report.json) |

Nativní příkazy běžely přes Godot `--path game --audio-driver Dummy`.
Pixelový test kreslí skutečný vlastní rest sprite se stejným světlem:
891 změněných pixelů ramen, **0 změněných pixelů spodku**, 291 pozitivních
pixelů kontaktního stínu. Prázdná geometrie odpovídá starému kreslení;
kontrolní varianta bez stínu dokládá, že se stín skutečně vykreslil.
Výpočtové testy ověřují cyklus, horní/pevný pás, inverzi a chybná metadata.

- [Zvětšený idle v rychlosti 1×](natural/idle-detail-at-1x.mp4).
- [Celá scéna v rychlosti 1×](natural/idle-at-1x.mp4).
- [Časování a otisky videí](natural/video-timing.json), [výběr výřezů](sample-selection.json).

Záznam obsahuje 12.017413 s skutečného času a 12.001925 s simulačního postupu.
PNG se komprimovaly až po pauze. FFconcat uchovává naměřené intervaly
30.879–103.086 ms (medián 65.047 ms). Každé video má 182 zakódovaných obrazů;
poslední opakování pouze uzavírá mediánovou výdrž. Detail je crop
`[507,353,230,210]`, zvětšený 3× metodou nearest. Přesnou maximální odchylku
časových značek zaznamenává `video-timing.json` (méně než 2 ms).

`trial-natural/` uchovává první pokus s nesprávně popsaným požadovaným zoomem;
výsledky této revize vycházejí výhradně z opraveného finálního `natural/`.

Technická integrace prošla. Nový idle zatím nemá zaznamenané výtvarné přijetí
uživatelem; není novým schváleným etalonem pro další jednotky.
Samostatný distribuovaný export, nové směry chůze a další gesta jsou mimo rozsah.
