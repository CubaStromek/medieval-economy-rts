# Pila v2 — plán finálního ověření, 2026-09-12

Postup byl vykonán 2026-09-12 po kompletní nativní prohlídce life/stock/work
vrstev a přepnutí produkčního defaultu na v2. Skutečné výsledky: čistý import,
focused headless **41/41**, povinná plná sada **854/854**, focused native
**41/41**. [Konečný protokol a logy](final-runtime-tests.md) rozlišují
automatické kontroly, nativní pixelové větve a samostatnou herní prohlídku.
Nativní běhy byly koordinované a jejich okna se nepřekrývala.

## Přesné běhy po přepnutí

Nejprve skutečný import nových souborů a čerstvý proces Godotu. Ze současného
repo kořene:

```sh
godot --headless --path game --editor --import --quit
godot --headless --path game --scene res://tests/sawmill_revision_runner.tscn -- --expected-art=v2
./tests/run-headless.sh
```

Společný focused scene runner vykoná existující `sawmill_sprite_tests` (8),
`production_building_life_tests` (12) a `sawmill_operation_tests` (21), aktuálně
celkem **41**. Vypíše skutečnou aktivní cestu manifestu, art verzi a SHA256;
neshoda s `--expected-art=v2` vrátí chybu před testy. Žádné nové imaginární
assety ani alternativní stavová logika se tím netestují. Kompletní sada už
obsahuje stejné tři sady a dotčené regrese. Původní plán odhadoval **850**,
aktuální sdílený strom při skutečném běhu vypsal **854/854**; do QA je zapsán
tento skutečný výsledek.

Po uvolnění nativního rendereru:

```sh
godot --path game --audio-driver Dummy --scene res://tests/sawmill_revision_runner.tscn -- --expected-art=v2
```

Tentýž 41případový runner navíc vykonal podmíněné native framebuffer větve
spodku domu a pracujícího tesaře. Headless varianty těchto případů ověřují
pozitivní asset/state kontrolu; samy neporovnávají framebuffer.

Výsledky zachovat pod novým `docs/art/qa/sawmill-v2/`: import log,
focused-headless log, complete-headless log, focused-native log a snapshot
hashů všech aktivně referencovaných souborů. U každého běhu ověřit návratový
kód, skutečný závěrečný počet i celý log na `SCRIPT ERROR`, `ERROR:`,
`WARNING:` a chybějící zdroje. Exit 0 s přerušeným testem není úspěch.

## Vizuální a běžná herní kontrola

`preview_sawmill_life.tscn` a `preview_sawmill_operation.tscn` používají
skutečný Main renderer ve vynucených stavových vzorcích; normal-game
`sawmill_life_game_runner.tscn` a `sawmill_operation_game_runner.tscn` prochází
menu, mapu, skutečnou dopravu, dávku, noc a izolované save/load. Jejich output
cesty a hash identity nyní sledují aktivní manifest. Konkrétní pořadí nativních
záběrů koordinovat s vlastníkem vizuálního QA; samotný tento plán je nespouští.

## Zbývající pevná čísla a jejich význam

| Kontrola | Čísla / geometrie | Co ověřit po kompletaci v2 |
| --- | --- | --- |
| Reused rest PNG | 256² canvas,165px body,0.2world/source scale, head/body hranice y79 | Zamýšlené přesné PNG reuse doložit hashem. Test již bere skutečné active life texture/look paths. Pokud se pixels změní, přeměřit, nikoli jen přepsat očekávání. |
| Rest fixture anchor | Syntetický house rect/scale a rest_foot `[100,220]`, očekávaná world foot `[120,94]` | Je to izolovaná kontrola registrace postavy, nikoli nové umístění u v2 dveří. Skutečný rest_foot z v2 musí být prohlédnut v Main. |
| Work PNG a rytmus | 6 distinct frames,6 cyklů/60 productive ticks,33worldpx | Zachované přesné pracovní PNG musí souhlasit s novou orientací/dveřmi/pracovní deskou. Aktuální algebra používá nové foot/body metadata a testuje stabilitu rect. |
| Work occlusion | Body samples se hledají ve skutečné alfě a odfiltrují pozdější foreground | V2 musí stále nabídnout více skutečně odkrytých opaque pracovníkových pixelů. Neoslabovat test jen kvůli vadné nové masce. |
| House lower pixels | Nezávislé hledání solid bodů ve spodní půlce/čtvrtinových pásmech | Zkontrolovat, že body patří skutečnému spodku a native reference je viditelná ve stejném místě. |
| Stock proof | 800² celý canvas a >40 změněných pixelů pro každý kus | Žádná v1 ROI již není; nové masky nesmějí kus schovat nebo zakrýt práh. |
| Katalog/simulace | 4 vstupní/6 výstupních kusů,1log→2plank/60ticks,footprint v1/8occupiedcells | Jsou herní kontrakty, ne staré art kotvy. V2 je nemění. |
| QA camera | Focus dle active alpha bbox; native pixelové testy mají door−60world a zoom2.4 | Snímky musí ukázat celé cílové body. Camera framing není oprávnění měnit herní projekci. |

Nové window/door/shutter polygony, chimney origin, wood UV, rest_foot,
pracovní kláda a masky nosných sloupků vyžadují geometrický a vizuální důkaz.
Shoda vzorce kotvy s vlastním manifestem neprokazuje, že je tato kotva správně
nakreslená. Přehled,1× motion, noc a hrana vyvýšeného základu proto zůstávají
samostatnou nezbytnou součástí QA.

Samostatné simulační regrese nyní nepřidávají užitečný důkaz nové kresby:
state adapter/simulace se neměnily a kompletní závěrečný běh je stejně pokryje.
Při konkrétním selhání se zopakuje pouze příslušná opravená větev a potřebné
regrese; jinak není důvod znovu násobit stejné běhy.
