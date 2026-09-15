# Pila — fyzické zásoby a pracovní cyklus v1

> Revize 2026-09-12: nový pohled a kresbu domu řeší [pila v2](sawmill-v2.md).
> Tento dokument uchovává původ a původní stavový kontrakt v1; staré
> geometrické kotvy a QA nejsou důkazem nové kresby.

Zadání uživatele **2026-09-12**: doplnit dynamické uložené klády a nařezaná
prkna a animovat činnost tesaře; prohlédnout původní Knights and Merchants.
Rozsah je rovnou herní integrace v návaznosti na předchozí výslovné zadání.
Stav **2026-09-12: zapojeno a ověřeno ve hře**. Finální výsledky a skutečné
snímky vede [QA této revize](../qa/sawmill-operation-v1/README.md).
[Integrační záznam](sawmill-operation-v1-integration.md).

Geometrii domu, jeho obrazovou registraci, lidské měřítko a původ vlastní
kresby vede [sawmill-v1](sawmill-v1.md). Směr materiálů a předolevé projekce
zůstává v0.2. Tento dodatek zavádí pouze stavové vrstvy a lokální pohyb
pracovníka a nástroje; má zachovat rozpoznatelnou architekturu i půdorys.
Odpočinkovou identitu tesaře vede [jeho brief](carpenter-rest-v1.md).

## Autoritativní stavy

| Vrstva | Zdroj a pravidlo |
|---|---|
| Uložené klády | `building.inputs.log`, nynější kapacita 4, samostatné čitelné pozice v levém loži |
| Hotová prkna | `building.outputs.plank`, nynější kapacita 6, samostatné čitelné pozice v pravém regálu |
| Zpracovávaná kláda | Samostatný kus na stolici při `process_remaining > 0`; při zahájení dávky se už odečetl ze skladových vstupů |
| Pracovník | Stejný skutečný domácí tesař a `inside_building_id`; žádná druhá simulační jednotka |
| Pracovní pohyb | Skutečný povolený `working/operate`, odpovídající `source_id`, den a kladný zbytek procesu; číst existující pravidlo života domu |
| Pauza, spánek, prázdno | Práce neanimuje; rozpracovaný kus se neztratí jen kvůli přerušení |
| Neznámý cizí stav | Návrat před čtením privátních zásob/obyvatele, neutrální podoba; neznámé není nula |

Aktuální recept `saw_planks` spotřebuje 1 kládu a po 60 skutečně produktivních
ticích vydá 2 prkna. Animace sleduje pozorovaný postup tohoto procesu.
Neodpočítává práci v kreslení, nezapočítává příchozí rezervace, nesené zboží
ani světové součty a nemění ekonomiku, kapacity nebo formát uložené hry.
Změněná kapacita nesmí tiše oříznout skutečné množství; nepodporované
mapování musí mít výslovně ošetřený fallback.

## Obrazový a animační kontrakt

Původní herní grafika slouží pouze k pozorování chování, mimo vlastní
produkční podklady. Přesné zjištění je v
[referenčním rozboru](../references/sawmill-kam-study-2026-09-12.md).
Rozlišovat původní RX obrazy, data houses.dat a výklad zdrojového kódu Remaku.
Naše počty zásob i délku dávky určuje naše simulace.

Před generováním změřit sloty, pracovní kontakt a masky předních částí
v produkčním canvasu 800². Výška těla 33 world px je zde přibližně
131.58 produkčních px domu, není to zdrojová výška samotného tesařova PNG.
Vrstvy vycházejí ze stejné registrace a výškové projekce domu. Stálé nohy,
opření rukou o nástroj a pevná velikost řezané klády se ověří v celém cyklu.

Zásoby nejsou namalované do celého domu. Každý kus má vlastní alfu a pevný
slot; přední podpěry regálu a stolice se znovu překreslí v potřebném pořadí.
Nové pracovní polohy zachovají krátké hnědé vlasy, čistou tvář, světlé
vyhrnuté rukávy a hnědou koženou zástěru existujícího tesaře.

## Požadované ověření

Zásoby 0–4 a 0–6, skutečné předání nosičem, začátek/spotřeba/dokončení dávky,
odnos prken, rozpracovaná kláda při pauze/noci, návrat k odpočinku, rychlost
a globální pauza, cizí mlha, save/load a přímý výběr skutečných pixelů.
Nativně prohlédnout celý pracovní cyklus a kritické kontakty rukou, nástroje
a řezané klády při běžném zoomu i v detailu, s plnými stojany i prázdnými.
Běžný menu → Relief průchod musí skutečně vyrábět a dopravovat zboží.
Předchozí úspěšné testy a obrázky denního/nočního odpočinku nejsou výsledky
této nové dodávky a nebudou tak přeznačeny.
