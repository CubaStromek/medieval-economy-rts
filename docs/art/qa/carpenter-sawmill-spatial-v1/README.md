# Truhlář u pily — nativní kontrola usazení

Datum skutečného běhu: **2026-09-13**, Godot4.7.2, macOS/Apple M4,
Compatibility/OpenGL. [Integrační záznam](../../briefs/carpenter-sawmill-spatial-v1-integration.md),
[přesná geometrie](../../sources/carpenter-sawmill-spatial-v1/geometry.json),
[strojové ověření a otisky](verification.json).
Struktura odpovídá [objektové QA šabloně](../../object-qa-template.md).

## Rozsah a výsledek

Opraveno vykreslení existujících šesti pracovních póz a odpočinku:
31world pracovní výška, zachovaná opřená dlaň, lokální zastínění pod střechou
a kontaktní stíny u skutečně zatížených bot. Odpočinek nadále33world.
Obrazy před/po vznikly v čerstvých nativních instancích stejného Main.

Všechny původní PNG mají stejné otisky před i po změně. Z assetových souborů
se změnily pouze dva manifesty; otisky se během každého nativního běhu
nezměnily. Půdorys, zem, řazení domu, zásoby, recept a save formát se nemění.
Tato dodávka neobsahuje nové směry, chůzi ani přemalovanou animační sadu.

## Vizuální ověření

| Kontrola | Výsledek a důkaz |
|---|---|
| Výška, opěrná ruka a stůl | Prošlo: [před/po](before-after.png), menší ohnutá figura odpovídá stolici; pevný kontaktní bod se nezměnil |
| Všech šest pracovních póz | Prošlo: [nativní fáze](all-work-poses.png), společné nohy a dlaň, jediná pevná pila; bez nového přeskakování registrace |
| Stíny a místní světlo | Prošlo: stín přímo pod oběma pracovními podrážkami, horní část těla v jemném stínu; [detail](after/motion/work-000.png) |
| Odpočinek | Prošlo: [denní odpočinek](after/frames/day-rest.png), jedna zatížená bota na soklu; druhá zvednutá noha nemá falešný pozemní stín |
| Běžná velikost a terén | Prošlo: [kontext](after/context.png),0.75×,1×,2.4×, zvýšený základ a přední strom; původní řazení a zakrytí zachovány |
| Průhlednost a klikání | Prošlo: stejné alfy zdrojů, skutečné pixelové testy gradientu, stín nerozšiřuje hit masku; opřená dlaň ověřena číselně |
| Mlha, pauza a skryté stavy | Prošlo: cílená sada ověřuje neodhalené cizí zásoby/osoby, pauzu a skutečný produktivní čas; stín je součástí stejné podmíněné kresby jako osoba |
| Noc a načtení | Prošlo: [načtená noc](natural/loaded-night-home.png), bez venkovního truhláře a jeho kontaktního stínu; okno a kouř zůstávají funkční |

Root prohlédl srovnání, všech šest pracovních fází, přehled různých měřítek
a terénu, pracovní i odpočinkové snímky a načtenou noc. Druhá nezávislá
kontrola doporučila zachovat31/33 a současné stíny; nevznikly rušivé
oddělené skvrny a obličej i předloktí zůstávají čitelné.
Technické přijetí a tuto vizuální kontrolu neoznačujeme za nové uživatelské
schválení celé výtvarné sady.

## Skutečná herní cesta a video

Menu → výběr Relief → skutečný nosič → dům4/truhlář20 → výroba → noc →
izolované save/load. [Report](natural/report.json) a [log](natural/native.log):
**6 fází,8 snímků,34 pohybových pozorování,0 selhání**.
Odpočinek tick3, práce237, hotová dvě prkna296, noc i načtení3750.
Žádné přepisování pracovního stavu či zásob pro tuto cestu; hráčovy save
soubory se neotevíraly. Samostatná předchozí/současná stavová kontrola má
94 snímků v každé variantě a je výslovně řízenou QA scénou.

- [Celá skutečná hra v rychlosti1×](natural/work-at-1x.mp4).
- [Zvětšený výřez práce při stejném časování](natural/work-detail-at-1x.mp4).
- [Časování](natural/video-timing.json):34 pozorování, všech6 póz,
  3.495506s skutečného času a3.450820s simulačního postupu.

Intervaly jsou skutečně naměřené (90–291ms, medián101.491ms), nikoli
vymyšlených pevných FPS. Video má35 zakódovaných obrazů, poslední opakování
pouze ukončuje výdrž. Největší odchylka zakódovaného času je0.494ms.
Při záznamu se obrázky bufferují a komprimují až poté. Výřez je pouze
technické zvětšení pixelů stejného záznamu, ne nový render ve větším měřítku.

## Testy a reprodukce

| Běh | Výsledek |
|---|---|
| `./tests/run-headless.sh` | **856/856**, [čistý log](full-headless.log); dva nové nativní pixelové případy výslovně přeskočeny a nejsou přičteny |
| Nativní `res://tests/sawmill_revision_runner.tscn -- --expected-art=v2` | **45/45**, [čistý log](focused-native.log), včetně dvou skutečných pixelových kontrol helperu |
| `res://tools/preview_sawmill_operation.tscn -- --output=<before nebo after>` |94 stavových/pohybových snímků; [aktuální log](after/native.log), oddělená skutečná výrobní dávka |
| `res://tests/sawmill_operation_game_runner.tscn -- --capture=<natural>` |Normální výše popsaná hra,0 selhání |

Nativní příkazy používají `godot --path game --audio-driver Dummy`.
Výřezy reprodukuje `docs/art/sources/carpenter-sawmill-spatial-v1/make-previews.cjs`
s projektovým Node/Sharp. Video vychází z `natural/work-motion.ffconcat`
a FFmpeg `-safe 0 -f concat -fps_mode vfr`; detailní crop vede
[preview geometrie](preview-geometry.json).

Poznámka k evidenci: převzaté capture runnery mají ve výstupní šabloně
historické datum2026-09-12. Tento záznam a verification.json uvádějí skutečné
datum nového běhu2026-09-13. Dřívější headless pokus měl omezení zápisu
Godot uživatelského logu v sandboxu; finální povinný i nativní běh jsou čisté.
Samostatný distribuovaný export nebyl v rozsahu požadavku a nebyl ověřen.
