# Dřevorubec — chůze bez klády, osm směrů

Připraveno **2026-09-10**: **8 směrů × 8 fází = 64 snímků** vlastní malované postavy podle původního cyklu KaM. Sekera zůstává v anatomické pravé ruce, levá je volná. Bez samostatného zemního stínu. Tato revize navazuje na rozpracovaný SE pilot; starší soubory zůstaly zachované.

## Výstupy

- [Přehled všech směrů](directions-overview.png).
- `sources/N.png` až `NW.png`: osm výchozích směrových archů 1536 × 1024 px, mřížka 4 × 2.
- `sheets/N.png` až `NW.png`: osm finálních archů po sjednocení měřítka a ukotvení.
- [Společný sprite atlas](sprite-atlas.png): 3072 × 4096 px, 8 řad směrů N/NE/E/SE/S/SW/W/NW a 8 sloupců fází 00–07; každá buňka odpovídá finálnímu PNG.
- `frames/DIR/00.png` až `07.png`: finální snímky 384 × 512 px; pořadí vždy zleva doprava a poté druhá řada.
- `reviews/DIR-10fps.gif` a `DIR-5fps.gif`: osmifázové smyčky 0,8 s a 1,6 s. Jedna společná paleta v každém GIFu; PNG zůstávají plně RGB.
- `raw/DIR/`: bezeztrátové buňky výchozích archů. `manifest.json` obsahuje cesty, rozměry, součty a časování.
- `registration.json`: společné měřítko pro každý směr, naměřené body čepice a celočíselné posuny všech 64 fází. Společná kotva jednotky je **[184,368]** na plátně **384 × 512 px**.
- `preview-validation.json`: provedené kontroly a jejich meze.

## Původ a zadání

Použit byl vestavěný generátor OpenAI `image_gen`, celkem **11 volání** včetně oprav. Samostatná zadání: [N](prompts/N.txt), [NE](prompts/NE.txt), [E](prompts/E.txt), [SE](prompts/SE.txt), [S](prompts/S.txt), [SW](prompts/SW.txt), [W](prompts/W.txt), [NW](prompts/NW.txt). Přesné vstupy, další opravná zadání a vybrané generované soubory zaznamenávají tři soubory `generation-notes-*.json`.

Pohybová reference: lokální export `uaWalk` + `uaWalkBooty`, osm původních fází pro každý směr. Pro každý směr byla použita jeho vlastní reference; protilehlé směry nevznikly zrcadlením. Vzhled vychází z vlastních osmi obrázků v `docs/art/animation-references/lumberjack-without-log/`. Původní KaM obrázky nejsou součástí těchto finálních sprite archů.

NW prošel opravou ruky ve čtvrté fázi. U SE byla opravena pátá fáze (index 04): odstraněn nežádoucí červený detail za ramenem. Tento jeden snímek pochází ze samostatné generativní opravy, přizpůsobené původní buňce společným zmenšením celé buňky. Ostatní fáze SE zůstaly z prvního archu; neúspěšná oprava celého archu se nepoužívá. Zdroj a výsledek detailní opravy jsou uchované v `repair-inputs/` a `repair-results/`.

## Stav a omezení

**PNG mají neprůhledné téměř bílé pozadí, nikoli skutečný alfa kanál.** Sada je připravená k vizuálnímu posouzení; nebyla integrována ani ověřena ve hře. Nová chůze zatím nemá uživatelské schválení.

Jde o generativní překreslení podle původních fází, ne o přesnou kopii souřadnic kloubů. Každý směr dostal jedno společné měřítko podle mediánu výšky čepice–podrážka v osmi původních a osmi vlastních fázích. Po převzorkování se všechny fáze posunuly tak, aby vrchol a střed horní části čepice odpovídaly příslušné původní fázi při stejném převodu originálu 8× + [32,40]. Tím se původní počátek [19,41] převádí na společnou kotvu **[184,368]**. Zachovává se původní pohyb čepice vzhůru, dolů i do stran; nezamyká se bota ani se nestředí celá silueta.

Tato kotva je odvozená z viditelné čepice, nikoli z původní kostry nové kresby. Neprokazuje fyzikálně přesný došlap nebo neklouzání při přesunu po mapě. Odchylky generované geometrie, překrytí končetin a natočení trupu zůstávají, zvláště u východního směru. Původní zdroje se neměnily; finální snímky jsou převzorkované a posunuté, proto se za pixelově totožné se zdrojem označují pouze `raw` výřezy.

Při statické kontrole byly ověřeny opačné poloviny kroku a návrat 8→1 bez zjevné změny směru nebo ruky. Technické kontroly ověřily všech 64 PNG výřezů a osmifázové časování GIFů. Rychlost náhledu je volba pro posouzení; není potvrzením sladění s herní rychlostí pohybu.
