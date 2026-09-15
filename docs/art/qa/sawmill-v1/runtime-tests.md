# Pila — zaměřené runtime kontroly, 2026-09-12

Godot 4.7.2. Nativní běh: OpenGL Compatibility, Apple M4, zvukový ovladač
Dummy. Testovací světy jsou izolované; nepřepisují hráčovy uložené hry.

| Sada | Bez grafického okna | Nativně |
|---|---:|---:|
| Pila — skutečný import a napojení hlavní scény | 8/8 | 8/8 |
| Regrese dřevorubecké chaty — přítomnost a den/noc | 13/13 | 13/13 |
| Regrese dřevorubecké chaty — stavba | 12/12 | 12/12 |
| Regrese dřevorubecké chaty — zásoby | 8/8 | 8/8 |

Reprodukce pily:

```sh
godot --headless --path game --audio-driver Dummy res://tests/sawmill_sprite_runner.tscn
godot --path game --audio-driver Dummy res://tests/sawmill_sprite_runner.tscn
```

Regresní scény: `res://tests/lumber_hut_life_runner.tscn`,
`res://tests/lumber_hut_construction_runner.tscn`,
`res://tests/lumber_hut_stock_runner.tscn`; stejné argumenty. Zachované logy:
[pila bez okna](sprite-headless.txt), [pila nativně](sprite-native.txt),
[život chaty](regression-lumber-hut-life.txt),
[stavba chaty](regression-lumber-hut-construction.txt),
[zásoby chaty](regression-lumber-hut-stock.txt),
[život chaty nativně](regression-lumber-hut-life-native.txt),
[stavba chaty nativně](regression-lumber-hut-construction-native.txt),
[zásoby chaty nativně](regression-lumber-hut-stock-native.txt).

Pila načítá skutečný 800² RGBA soubor. Testy ověřily sdílení textury a alfa
masky, mipmapy, zamítnutí chybných číselných registračních údajů, neexistující
resource, zachovaný půdorys osmi polí a volný vnější vstup, starší footprint 0,
stavbu a srovnávání bez předčasné hotové kresby. Při třech skutečných úrovních
rovného terénu se bitmapa posunula přesně o 24 world px spolu s prahem.
Skutečný Builder a dva Carriers dokončili placenou stavbu; spotřeba surovin
i následné JSON uložení a načtení zůstaly přesné.

Klikací kontrola používá skutečné neprůhledné a průhledné pixely mimo
obsazenou zem a všech osm obsazených buněk. Nativní kontrola dolních částí
vybírá nejméně tři neprůhledné plošky z dodaného obrázku a porovnává skutečnou
hlavní scénu se stejnou texturou, registrací a světlem překreslenými nad
terénem. RGB tolerance je 0.025; kontroly proběhly při ticku 1750 a 4750,
zoomu 2.4×. Stejné konkrétní pixely jsou zkontrolovány také přes výběr hlavní
scény. Tím existuje pozitivní kontrola, že sprite opravdu vznikl a spodní
pixely nejsou přemalované trávou; pouhá shoda prázdných obrázků by neprošla.
Bez grafického okna se tato pixelová část výslovně vynechává.

Zdrojový `finished.png` ověřený při bězích:
`349924968b535bf299d9933e00d476bdf357f87a3011b628a420a2d7e06315a4`.
Čtečkou ověřené raw RGBA8:
`d199241761a5a34a1febb87990e165b8f79f868ec16007c5788b5bdfcbda6651`.
Nastavení importu `process/fix_alpha_border=false` zachovává přesné produkční
RGBA bajty, které se kontrolují před vytvořením mipmap. Původní první pokus
s výchozím přepisem RGB průhledných pixelů byl korektně odmítnut; výše jsou
výsledky po opravě nastavení a novém importu.

Úplná povinná sada po vložení finálních stavových obrázků prošla
**829/829**, návratový kód 0, bez chyb skriptů a bez resource warnings:
`./tests/run-headless.sh`, [plný log](full-suite.txt). Zůstala pouze hlášení
macOS o certifikátech a nemožnosti zapisovat výchozí log do uživatelského
adresáře v sandboxu; textový důkaz běhu je zachovaný přímo v projektu.

První úplný běh odhalil zastaralý název `ActivityPanel` v již existujícím
testu nebe. Test přerušil část kontrol chybou null objektu, přesto jeho
souhrn uváděl nula selhání. [Původní log](full-suite-before-sky-clock-test-fix.txt)
zůstává archivovaný. Úzká oprava používá aktuální `EntityActivityPanel`
a při chybějícím prvku nyní výslovně přidá selhání. Žádný runtime HUD kód
se kvůli tomu nezměnil. [Zaměřený běh nebe](sky-clock-focused.txt) prošel
5/5 a teprve následný úplný běh výše dokládá všech 829 případů bez chyby skriptu.

Tento protokol dokládá bitmapové napojení a uvedené regrese. Nepřebírá roli
výtvarného přijetí, snímků běžné mapy, měření jednotlivých konstrukčních
kontaktů ani kontroly finálního odpočinkového obrázku tesaře. Ty mají vlastní
záznam v hlavním QA. Nové sady pily (8) a výrobního domácího života (12) jsou
zaregistrované v úplném projektovém `test_runner.gd`.

Audit společné větve vykreslování: bitmapa pily se zapíná pouze pro
dokončené současné budovy `sawmill` s footprint 1. Její život se vykresluje
ve stejném řádku, pod stejným světlem, terénem a mlhou. Neznámý cizí dům
nevstoupí do výběru a jeho život vrací neutrální stav před čtením obyvatele.
Alfa odpočinku pily a chaty používá oddělené čtečky; nedochází k vypůjčení
masky dřevorubce pro tesaře. Stíny nadále přijímá skutečný půdorys, nikoli
pomocný bod řazení. Současná vektorová stavba pily zůstává zachovaná;
nové grafické stavební fáze a proměnlivé bitmapy zásob pily tato verze nedodává.
