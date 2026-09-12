# Kontrola dřevorubce — PixelLab produkční v2

Datum: **2026-09-10**. Stav: **finální balík všech 24 kombinací je hotový: 439 animačních
snímků a 24 samostatných vstupních referencí. Plné samostatné nativní
QA prošlo; běžná herní cesta zůstává neověřená.** Záznam podle [QA šablony](../../object-qa-template.md).
[Implementační záznam](../../briefs/lumberjack-pixellab-production-v2-integration.md),
[produkční sada](../../animations/lumberjack-pixellab-production-v2/README.md).

## 1. Přesný předmět a autorizace

Jednotka `lumberjack`: `walk_axe`, `chop`, `walk_log`, každé v N, NE, E,
SE, S, SW, W, NW. Skutečné zdrojové animace existují pro všech 24
kombinací. To není důkaz přijetí všech prvních pokusů ani finálního balíku.
Identitu a vlastní původ určuje [kanonický brief](../../briefs/lumberjack-v1.md).

Předchozí omezení uploadů uživatel dne **2026-09-10** vyřešil odpovědí:
> Potvrzuji a zadam o zrušení té původní kontroly

Autorizoval tím opětovné odesílání vlastních odvozených výstupů PixelLabu
stejné službě a zrušil početní omezení uploadů. Jeden původní vlastní
master zůstává pravidlem výtvarné konzistence. Souhlas není vizuálním
přijetím výsledků. Archivní odmítnuté pokusy a jejich původní QA zůstávají
zachované, včetně příčné klády, neprůhledných/přerámovaných referencí,
nesprávných směrů a efektů přidaných do sekání.

Canvas je skutečně **256 × 256 RGBA**. Počty raw a vybraných fází se
liší podle prohlédnutého cyklu. [Uzavřený výběr](../../animations/lumberjack-pixellab-production-v2/delivery-selection.json)
obsahuje zdrojové indexy a směrové FPS. Finální součet je 439 animačních
fází: walk_axe 176, chop 140, walk_log 123. Raw00 reference jsou
archivované samostatně a nepočítají se jako další animační fáze.

## 2. Běžná herní cesta

**Neprovedena a zatím nezapojená.** Skutečný [nativní jižní pilot](../lumberjack-pixellab-v2-S-pilot/README.md)
a [FPS probe](../lumberjack-pixellab-direction-fps-probe/README.md)
používají samostatný prohlížeč. Nedokazují menu → běžná mapa → pracovník
jde ke stromu → kácí → převezme kládu → vrací se → odevzdá ji.

Budoucí kontrola musí zaznamenat skutečnou jednotku/strom, pozice,
zoom a simulační stavy; zachovat rozehranou pozici uživatele. Pevné
náhledové karty, pomocná kotva a kontaktní arch nejsou terén nebo
skutečně vykonaná práce. Finální společný [nativní běh](native/README.md) je dokončený:
15 skutečně zachycených a prohlédnutých PNG, 439/439 políček a 24/24
kombinací. Manifest výslovně uvádí `simulated_gameplay=false`.

## 3. Skutečná zdrojová kontrola a výběr

| Činnost / směry | Výsledek k tomuto záznamu | Důkaz / konkrétní limit |
|---|---|---|
| `walk_axe`, všech 8 | **PASS pro další balení.** Střídání obou nohou, pravá ruka s jedinou sekerou, levá volná; skutečné počty cyklů řídí FPS. | Individuální `jobs/walk_axe/<směr>/qa`; [W](../../animations/lumberjack-pixellab-production-v2/jobs/walk_axe/W/qa/independent-review.md) má vzdálený úchop částečně zakrytý. |
| `walk_log/N` | **PASS po výběru raw 1–11 / 13,75 fps**, jeden dvojkrok za 0,8 s. | [N QA](../../animations/lumberjack-pixellab-production-v2/jobs/walk_log/N/qa/independent-review.md): raw 12–16 opakuje jen půl kroku; všech 17 raw zůstává. |
| `walk_log`, ostatních 7 | **PASS pro raw 1–16 / 20 fps**, jeden dvojkrok za 0,8 s. | Jedna kláda podélně na pravém rameni, pravá opora, levá volná, sekera na levém boku. [W QA](../../animations/lumberjack-pixellab-production-v2/jobs/walk_log/W/qa/independent-review.md): vysoký kontakt ramene je zakrytý; nelze jej fyzicky potvrdit. |
| `chop/S` | Prohlédnut a vybrán `repairs/chop-S-waist-empty`, raw 1–16 / 12 fps. | Oprava nízkého původního úderu a následného pokusu s přidaným kmenem/efekty; archivní joby zůstávají. |
| `chop/N` | **PASS pro raw 1–12 / 9 fps**, jeden zásah za 1,333… s. | [Výběr N](../../animations/lumberjack-pixellab-production-v2/repairs/chop-N-forward/qa/independent-review.md): raw 13–16 je další nedokončený nápřah; dolní úchop zakrytý, delší výdrž. |
| `chop/NE,NW,SE,SW` | Prohlédnuty výběry raw 1–16 / 12 fps, jeden zásah za 1,333… s. | Individuální QA u `jobs/chop/<směr>`; některé vzdálené úchopy jsou zakryté. |
| `chop/E` | **Vybráno `repairs/chop-E-slow-24`, raw 1–24 / 18 fps.** | Čistý celý cyklus prohlédnut rootem a nezávisle; předchozí pokusy s efekty jsou archivní. |
| `chop/W` | **Vybráno `repairs/chop-W-slow-24`, raw 1–24 / 18 fps.** | Root i [nezávislá kontrola](../../animations/lumberjack-pixellab-production-v2/repairs/chop-W-slow-24/qa/independent-review.md) prohlédli čistý celý cyklus se dvěma rukama před tělem. [Starší forward výběr](../../animations/lumberjack-pixellab-production-v2/repairs/chop-W-forward/qa/independent-selection-review.md) je překonaný a není v dodávce. |

| Společná kontrola | Skutečný výsledek |
|---|---|
| Raw alpha, rozměry a okraje | Měřeno u prohlédnutých jobů; 256² RGBA se skutečnou průhledností, zachované původní hashe. Finální atlasová kontrola prošla. |
| Statická registrace | [Provedené posuny a provenance](../../animations/lumberjack-pixellab-production-v2/registered-inputs/README.md): celé statické RGBA, celočíselně podle čepice; žádné viditelné pixely oříznuté. Log nad hlavou se nevydává za cap top. |
| Tělesné měřítko a kotva | Pracovní (128,205), 163 source px → 33 world px. Technicky ověřeno v S pilotu; fyzická kalibrace zůstává předběžná. |
| Animované fáze | Bez vyrovnávání bot, individuálního trimu nebo dodatečného bobu. Původní pohyb nohou se nepoužívá pro přepočet ground kotvy. |
| Finální kopie/atlas/APNG | **PASS: všech 439 fází.** Původní PNG bajty, celé atlasové regiony i zdrojové oblasti dekódovaných APNG přesně souhlasí; žádné varování. |
| Smyčky a tempo | Zdrojové konce a počty skutečných kroků/zásahů prohlédnuty; výše zaznamenané výběry. Společný přehled vznikl; tempo vůči simulovanému pohybu a běžné přechody čekají. |
| Kontakt, terén, strom, hloubka/stíny | **Neověřeno ve hře.** Cap registrace není fyzická kalibrace. |
| Přechody práce/nákladu, interiér, mlha, světlo, UI, save, výkon | **Neověřeno v běžné cestě.** Reader samotný tyto větve neaktivuje. |

Stavební masky, stavební kroky, sklad budovy a růst stromu: **N/A**,
předmětem je animovaná jednotka. Kontrolní strom není nový stromový asset.

## 4. Skutečně provedené technické běhy

| Běh | Rozsah a důkaz | Výsledek |
|---|---|---|
| Skutečný S pilot | [QA](../lumberjack-pixellab-v2-S-pilot/README.md): 25 raw / 24 vybraných, PNG/atlas/APNG, nový Godot import, pět prohlédnutých nativních PNG, časové ovládání | **PASS v samostatném prohlížeči**, archivní 12 fps, žádná běžná hra |
| Godot směrové FPS | [Probe](../lumberjack-pixellab-direction-fps-probe/README.md): 18/18 metadatových a 8/8 ovládacích kontrol; skutečné S/W, override i fallback, oddělené native captures | **PASS technického kontraktu**, není úplný produkční balík |
| Packer směrové FPS | [Měření](../lumberjack-pixellab-direction-fps-probe/packer-timing-review.md): směrový override, fallback, časový výběr, přesná délka APNG a zachování zdrojových RGBA | **PASS offline probe**, část dat syntetická, není výtvarné přijetí |
| Přehledový exportér | [Finální 3 × 8 přehled](../../animations/lumberjack-pixellab-production-v2/preview/overview.apng.png): všech 24 buněk, 120 plnobarevných fází, přesně 1/30 s; prohlédnuto 0 / 0,5 / 1 / 1,5 s | **PASS mechanického výňatku**, [validace](../../animations/lumberjack-pixellab-production-v2/preview/overview-validation.json) potvrzuje RGB a zachování vstupů |
| Finální kompletní balík | [439 animačních fází](../../animations/lumberjack-pixellab-production-v2/package/manifest.json), 24 raw00 referencí; [měření](../../animations/lumberjack-pixellab-production-v2/pack-validation.json), [soubory](../../animations/lumberjack-pixellab-production-v2/delivery-files.json) | **PASS**, 0 varování, 0 symlinků |
| Předávací archiv | [ZIP](../../animations/lumberjack-pixellab-production-v2/lumberjack-pixellab-v2.zip); [kontrola CRC/bajtů a aktuálního obsahu](../../animations/lumberjack-pixellab-production-v2/qa/zip-validation.json), [návod](../../animations/lumberjack-pixellab-production-v2/DELIVERY.md) | **PASS** |
| Finální nativní kompletní sada | [Nativní QA](native/README.md): nový Godot 4.7.2 import, `require-complete`, 439/439 fází a 24/24 kombinací, 15 prohlédnutých PNG při 1×/3× | **PASS samostatné ukázky**, bez chyb či varování readeru; normální hra není simulovaná |
| Běžná hra / regrese | Produkční renderer a skutečné stavy simulace | **Neprovedeno** |


Při nativním 3× náhledu je čitelná jediná sekera a jednotlivé fáze všech
činností. Při 1× je rozpoznatelná postava a nesená kláda; detaily rukou
zůstávají omezené skutečnou velikostí. [Manifest zachycení](native/native-capture-manifest.json)
a [provenance runtime kopie](native/package-provenance.json) spojují
snímky s finálním balíkem a oddělují jej od uchovaného historického S pilotu.
Nativní fixní karty neprokazují kontakt s terénem, zásahem stromu, přechody
činností ani herní mlhu, světlo, stíny, UI a výkon běžné osady.

[Audit spotřeby](../../animations/lumberjack-pixellab-production-v2/qa/cost-audit.md)
k **2026-09-10 17:43:52 UTC** potvrzuje 55 unikátních dokončených serverových
úloh, 560 zahrnutých generací a 0 USD za generování, bez běžících rezerv.
Zahrnuje odmítnuté pokusy i finální E/W; cenu předplatného nezahrnuje.
Potvrzené náklady se sčítají po unikátních ID; poklesy souběžných globálních
zůstatků nejsou cenou jednotlivých jobů.

## 5. Rozhodnutí této verze

| Oblast | Stav k 2026-09-10 |
|---|---|
| Existující zdrojové animace | Všech 24 kombinací má skutečný výstup; první vadné pokusy nejsou přijaté |
| Zdrojová kvalita dvou chůzí | Osm směrů každé činnosti prohlédnuto; připuštěno k finálnímu balení s uvedenými occlusion limity |
| Zdrojová kvalita sekání | Všech osm směrů vybráno a prohlédnuto; čisté slow-24 opravy E/W nahradily předchozí pokusy a mají nezávislý PASS |
| Finální technická kompletace | **PASS: 24 kombinací / 439 fází / 24 vstupních referencí**, přesné pixely a nulová varování |
| Nativní technika | **PASS:** skutečný S pilot, směrový FPS probe i plná finální sada; 15 nativních snímků prohlédnuto |
| Běžná herní implementace | Nezapojená / neověřená |
| Přijetí uživatelem / etalon | Neuděleno / ne |

Starší v1 s neuzavřeným jižním krokem, chybějící sekerou N a hrubým GIF
není etalon. Technické balení, zdrojová kresba, skutečný kontakt ve hře a
uživatelské přijetí jsou samostatné výsledky a nepřebírají se ze starých verzí.
