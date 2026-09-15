# Audit přechodu pily v1 → v2 — 2026-09-12

Aktivní runtime byl po dokončení nativní prohlídky vrstev přepnut na v2.
Čerstvý import, focused headless **41/41**, celá povinná sada **854/854**
a focused native **41/41** prošly bez chyb a varování. Skutečné logy,
rozsah důkazu a konečné otisky obsahuje [runtime protokol](final-runtime-tests.md).
[Integrační záznam](../../briefs/sawmill-v2-integration.md).

## Minimální přepnutí

1. Dodat samostatný dům/manifest a registrované life/stock/work vrstvy pod
   `game/art/buildings/sawmill/v2/`, se skutečnou alfou a novými měřeními.
2. Přijmout pouze známé art revize v1/v2 v `SawmillSpriteLibrary.validate_manifest`.
   Provedeno; `schema_version` a herní footprint se nemění.
3. Správně prázdný v2 základ nepotřebuje backplate; jeho vynechání nebo prázdný
   řetězec nyní loader podporuje. Explicitní vadný patch se stále zamítne.
4. Po kompletaci přepnout `SawmillSpriteLibrary.MANIFEST_PATH` na v2. Tento krok
   **proveden 2026-09-12**. Žádná nová větev MainView či simulace nebyla potřeba.
5. Obnovit import a použít novou instanci. Existující instance knihovny domu
   nepřejímá novou hodnotu manifestu za běhu; operation cache uchovává i neúspěšné
   načtení a musí se při úpravách vyčistit nebo zaniknout s procesem.

## Runtime vazby

| Místo | Konkrétní vazba / dopad |
| --- | --- |
| `sawmill_sprite_library.gd:6` | Jediný výchozí asset path nyní v2. Constructor nadále přijímá explicitní manifest path pro izolovanou kontrolu další revize. |
| `sawmill_sprite_library.gd:66` | Původně striktní art v1; nyní allowlist v1/v2. Nezaměňovat s `supports()` vyžadujícím herní footprint v1. |
| `sawmill_sprite_library.gd:31` | Origin/rect/label/life/operation jsou metadatové; lze převést bez nové v2 renderer větve. |
| `sawmill_sprite_library.gd:45` | Depth používá pouze rozdíl Y sort_foot−door_threshold; X zůstává mapové kotvě. Novou geometrii musí tato stávající řada prokazatelně zvládnout. |
| `sawmill_operation_art.gd` | Canvas/backplate validace a kreslení jsou 800². Pro plánovaný 800² v2 není zobecnění potřeba. Frames mají shodný canvas a vlastní body/foot scale. |
| `production_building_life.gd` | Runtime neobsahuje path v1; potřebuje nové door/window/shutter/chimney/rest_foot/wood_uv a platné sprite paths. Světový human height 33, kouř a světelný halo jsou sdílený vzor, nikoli pixelové kotvy v1. |
| `sawmill_operation.gd` | Neobsahuje art path/kotvy. Log/plank accounting, productive progress, privacy, pause a reset zachovat. |
| `main_view.gd` | Dispatch podle `type == sawmill`, nikoli art verze; stávající draw/life/operation/hit/observe/reset hooky lze ponechat. |

Nové měření vyžadují prahy, scale, bbox/hashes, sort a UI anchor; všechny body
domácího života; každý stock slot, prop scale a přední maska; pracovní kláda,
foot, orientace/ground contact postavy a její překrytí. Zdrojové textury
člověka či zboží lze znovu použít pouze při skutečné shodě pohledu a materiálu.
V1 foreground obsahuje pixely konkrétních starých sloupků a nelze jej jen
přesunout na nový dům. Nový prázdný základ nemá dostat starý wall patch.

## Testy a záznamy vázané na v1

| Soubor / případ | Přesná vazba | Při v2 |
| --- | --- | --- |
| `sawmill_sprite_tests.gd`, invalid metadata | `asset_version: v2` dříve negativní případ | Připraveno: negativní je neznámé v999, v2 má pozitivní schema kontrolu; to není důkaz existujícího v2 obrázku. |
| `sawmill_sprite_tests.gd`, missing | Chybějící cesta původně uvnitř v1 | Upraveno: odvozená od aktivního manifestu. |
| `sawmill_sprite_tests.gd`, native lower pixels | Vyhledává skutečné alpha pixely spodní poloviny | Znovu ověřit pozitivní vzorky proti v2; neoslabovat pokrytí kvůli novému překrytí. |
| `sawmill_operation_art_tests.gd`, flatten/diff | 800² a původní v1 rack ROI x350–674/y425–549 | Upraveno: rozdíly se měří v celém 800² canvasu. |
| `sawmill_operation_art_tests.gd`, unknown | Původně vyžadoval právě jeden backplate | Upraveno: podle optional backplate 0/1 architektonických overlays, vždy bez labels/frame a bez čtení sentinel private state. |
| `sawmill_operation_art_tests.gd`, positive | Některé prázdné stavy vyžadovaly neprázdný seznam layers | Upraveno: samostatná aktivní pozitivní kontrola musí načíst skutečné full stocks + worker frame; prázdný stav může legitimně nemít overlay. |
| `sawmill_operation_art_tests.gd`, frames | Šest distinct poses a šest vzorků jedné v1 pracovní sekundy | Pokud se počty změní, zapsat záměr nové sady a ověřit všechny dodané frames; timing stále vychází ze skutečné práce. |
| `production_building_life_tests.gd`, poslední dva případy | Původně přímé v1 resting JSON/PNG paths, 256px canvas,165px body,0.2scale, y79 head/body split | Upraveno: čte active house.life.rest_sprite a jeho look paths. Měření 256/165/0.2/y79 zůstává pro výslovně zamýšlené znovupoužití přesných existujících PNG; při změně jejich pixelů znovu změřit. |
| `sawmill_operation_tests.gd` | Stavové fixture numbers 4/6/60,33world,footprint1 | Jsou současné herní kontrakty; nejsou art hardcoding a zůstávají. |
| `preview_sawmill_life.gd`, `preview_sawmill_operation.gd` | Původně v1 QA output directories a hash paths | Upraveno přes `sawmill_qa_assets.gd`: active revision output dirs, skutečný manifest path/hash, rest/look/operation asset hashes. |
| `sawmill_life_game_runner.gd` | Původně v1 outputs/hash paths a source focus `(400,385)` | Upraveno: active revision identity a focus ze skutečného alpha bbox; nativní kompozici ještě prohlédnout. |
| `sawmill_operation_game_runner.gd` | Původně v1 outputs, finished/operation paths pro hashes | Upraveno: společný QA resolver následuje aktivní renderer manifest a všechny jeho referencované vrstvy. |

Části screenshot/video cest nejsou runtime problém, ale mohou vytvořit
nesprávný důkaz: v2 obraz s otiskem starého v1 manifestu. Proto kontrolovat
otisky každého skutečně načteného zdroje a označit novou revizi v QA runneru.

## Provedené ověření

Předswitch [souborový snapshot](pre-switch-resource-audit.json) kontroluje
14 referencovaných PNG: všechny mají RGBA8 hlavičku a existující Godot import
remap, všechny deklarované SHA256 se shodují. Přítomny jsou 4/6 stock sloty,
šest existujících worker frames, rest/look reference a nový processing log;
backplate správně chybí. Toto je nezávislá kontrola souborů a cest, ne výsledek
načtení tříd v Godotu nebo přijetí výsledných pixelů. Snapshot zachovává tehdejší
default v1; [konečný snapshot](final-asset-hashes.json) dokládá stejné soubory
a oba manifesty beze změny až po poslední nativní test aktivního v2.

Syntaxe připraveného optional-backplate kódu a souvisejících testů prošla
kontrolou parseru. Přidána jedna assetová kontrola (operation suite má
nyní 21 případů): vynechaný/prázdný patch zachová reálné stock/worker vrstvy;
unknown nečte sentinel soukromá data a nic nepřidá; vadný typ, chybějící soubor
nebo jiný rozměr explicitního patche stále musí selhat.

Nová case byla skutečně vykonána s kompletním v2 setem ve focused i plné sadě.
Aktivní house/life/operation testy mají **8 + 12 + 21 = 41** případů. Plná
sada aktuálního sdíleného stromu skutečně vypsala **854/854**; nejde o převzatý
starší počet 849 z v1 ani dřívější odhad 850. Nativní focused běh navíc prošel
pixelovými větvemi spodku domu za dne/noci a pracujícího tesaře v normální
MainView řadě. Žádná oprava runtime či art setu nebyla po přepnutí potřebná.

QA preview helper umí explicitní `--manifest` override pro kandidátní revize.
Focused revision runner proto ověřuje identitu přímo z produkčního
`SawmillSpriteLibrary.MANIFEST_PATH`, stejně jako jím volané testy. Samostatná
negativní kontrola s požadavkem na v1 a preview v1 správně odmítla skutečný
default v2 před testy. Tato úprava pouze runneru byla znovu ověřena headless
41/41 a následně native 41/41; plná sada používá vlastní nezměněný runner.

Geometrie a pohyb zůstávají samostatně doloženy v
[nativní prohlídce vrstev](dynamic-native/README.md); průchod přes skutečné
menu/mapu/dopravu/save-load má [vlastní report](natural/report.json).
Automatické testy samy neprohlašují výtvarný styl za uživatelem schválený.
