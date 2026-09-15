# Pila v2 — konečné runtime ověření, 2026-09-12

Produkční `SawmillSpriteLibrary.MANIFEST_PATH` je přepnutý na v2. Čerstvý
import, cílená headless sada **41/41**, povinná celá sada **854/854** a cílená
nativní sada **41/41** prošly na Godotu 4.7.2. Všechny čtyři procesy skončily
s kódem 0 a celé jejich logy neobsahují `SCRIPT ERROR`, `ERROR:`, `WARNING:`,
selhané případy ani zprávy o chybějících zdrojích.

| Vykonané ověření | Skutečný důkaz |
| --- | --- |
| Čerstvý import aktivního v2 | [final-import.txt](final-import.txt) |
| House 8 + home life 12 + operation 21; headless 41/41 | [final-focused-headless.txt](final-focused-headless.txt) |
| Celá povinná sada aktuálního sdíleného stromu; 854/854 | [final-full-headless.txt](final-full-headless.txt) |
| Týchž 41 případů v nativním rendereru, včetně pixelových větví | [final-focused-native.txt](final-focused-native.txt) |
| Úmyslně nesprávná očekávaná revize odmítnuta před testy, správný exit 1 | [final-revision-identity-negative.txt](final-revision-identity-negative.txt) |
| Všech 14 referencovaných PNG, oba manifesty a import remaps | [final-asset-hashes.json](final-asset-hashes.json) |
| Strojový souhrn kontrol logů a otisky runtime/test souborů | [final-runtime-checks.json](final-runtime-checks.json) |

Aktivní manifest má SHA256
`4308aa27f9962a2af75644122795a2b5f28435e57151b873b8310bc35e39bc67`,
operation manifest
`147aced8a66ac715a712e919d7295d4458c2f27f0665143686876ea5691b4e85`.
Oba a všech 14 PNG zůstaly stejné od předswitch auditu až po poslední nativní
ověření. Znovupoužité rest/look a šest pracovních PNG se neměnily; v2 je
registruje vlastními metadaty. Dům a jeho odvozené pracovní vrstvy mají
skutečnou alfu a existující importované zdroje.

Cílené případy ověřily skutečný import a cache, rozměry/půdorys a práh,
alpha hit selection, zaplacenou výstavbu a save, nedokončený/legacy fallback,
domácí přítomnost, noc/odpočinek, soukromí cizí budovy v mlze a zachování
stavu při pauze. Produkční část používá skutečné doručení/odvoz a recept
1 kláda → 2 prkna, rozpracovanou kládu oddělenou od skladu, odpracovaný
postup, přerušenou/slabší práci, načtení a reset světa. Art kontroly vyžadují
všech šest skutečných odlišných póz, každý přírůstek klád/prken po překrytí,
všech 35 kombinací zásob, stabilní registraci člověka a normální MainView
kreslení i klikání. Chybějící snímky mají pozitivní kontrolu platné dodávky;
nepodporovaná kapacita poskytne pravdivé množství místo zavádějícího počtu
nakreslených kusů.

Nová optional-backplate kontrola běžela nad reálným v2 setem: prázdná základní
stěna nepotřebuje patch; vynechání/prázdný řetězec zachová skutečné stock/work
vrstvy, neznámá cizí budova nemá dynamické overlays ani čtení soukromého stavu.
Vadný explicitní patch zůstává odmítnutý. Revidované testy hledají stock
rozdíly v celém 800² canvasu a berou life cesty z aktivního manifestu.

Nativní běh použil Apple M4, Compatibility / OpenGL 4.1 Metal. Několik
skutečných neprůhledných bodů spodku domu za dne i noci a odkrytých bodů
pracujícího tesaře v normální painter řadě souhlasilo s nezávisle kreslenou
nezakrytou referencí ve stejném místě. Body zároveň vybírají skutečnou pilu.
Tyto framebuffer větve jsou v headless režimu přeskočeny po pozitivních
kontrolách zdrojů; jejich vykonání zde dokládá samostatný nativní log.

Focused runner nyní bere identitu ze skutečného produkčního defaultu, nikoli
z preview-only `--manifest` argumentu. Proto nemůže vydat testy v1 za důkaz
kandidátního v2. Zpřesnění pouze tohoto runneru bylo ověřeno opakovaným
headless 41/41, očekávaným odmítnutím nesprávné revize a native 41/41.
Plný runner ani jeho sady se touto drobnou úpravou neměnily a celá povinná
sada nebyla bez důvodu opakována.

Další runtime/art opravy po přepnutí nebyly potřeba. Plná sada zahrnula
stávající hut/lumberjack, fog, terén, výstavbu, save, nutrition, housing,
produkční řetězce i aktuální HUD regrese. Změny gameplay, save formátu,
projekce či footprintu nebyly součástí přepnutí. Automatický důkaz doplňuje
[nativní vizuální prohlídka](dynamic-native/README.md) a
[skutečný průchod menu → mapa → doprava/práce → save/load](natural/report.json);
sám neprohlašuje výtvarný jazyk za uživatelem schválený.
