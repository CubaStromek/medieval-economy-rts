# Pila v1 — vlastní dílna, komín a život domácího tesaře

> Revize 2026-09-12: nový pohled a kresbu domu řeší [pila v2](sawmill-v2.md).
> Tento dokument uchovává původ a původní stavový kontrakt v1; staré
> geometrické kotvy a QA nejsou důkazem nové kresby.

Datum **2026-09-12** · ID **sawmill** · asset **v1** · [manuál v0.2](../building-style-guide.md).
Stav základní verze: **zapojeno a ověřeno 2026-09-12**. [Integrace](sawmill-v1-integration.md) · [QA](../qa/sawmill-v1/README.md).
Následný požadavek na zásoby a skutečnou práci vede
[provozní dodatek v1](sawmill-operation-v1.md); jeho QA je samostatné.

**Vizuální porovnání 2026-09-12:** společný nativní záběr s produkční
dřevorubeckou chatou ukázal čelnější pohled pily, slabší dojem nadhledu,
jemnější pravidelnější detail a menší měřítko klád. Funkční integrace
prošla, výtvarné sjednocení vyžaduje další revizi. [Snímky a posouzení](../qa/sawmill-lumber-hut-comparison-2026-09-12/README.md).

Uživatel požádal o vlastní návrh ve stávajícím půdorysu a snadnou odlišitelnost
budov při společném výtvarném jazyku. Čistý koncept přijal slovem „super“,
doplnil komín a levé okno s chováním dřevorubecké chaty, tesaře pro domácí
odpočinek a následně výslovně potvrdil **rovnou zapojit do hry**.
Přijetí konceptového směru není schválení finálního herního etalonu celé sady.

## Úloha a vlastní identita

Pila zaměstnává tesaře a mění jednu kládu na dvě prkna. Má dlouhou nízkou
sedlovou střechu, malou uzavřenou levou část a velké otevřené pravé pracoviště.
Původní samostatný master má velkou rámovou pilu nad řezací stolicí.
Provozní dodatek nahrazuje její lokální plochu zadní stěnou a používá
ruční pilu skutečně pracujícího tesaře podle prohlédnutého pohybu v KaM.
Podpůrné motivy jsou prázdné lože klád a prázdný pravý regál prken.

Od dřevorubecké chaty ji odlišuje **jedna dlouhá nízká střecha a otevřená
řezací dílna**. Nekopíruje vyšší pravý domek s přístřeškem vlevo.
Barvy ani cedule nenahrazují vlastní siluetu. Rodinu spojují teplé kamenné
patky, masivní trámy, světlá hliněná výplň, matný šedohnědý šindel,
klidné malované plochy a nadhled zpředu zleva s čitelnými horními plochami.

Na následný požadavek přibyl malý kamenný komín nad levou místností a
otevírací okno na levém boku. Statický základ má zavřené dveře i okenice,
prázdná skladovací zařízení a neaktivní trvalou rámovou pilu. Žádný pracovník,
skladované klády/prkna, světlo ani kouř nejsou napevno namalované do domu.
Bez vodního kola, řeky, kruhové pily, vlajek, okolního dvorku či podstavce.

## Geometrie a první podklad

Autorita: game/data/buildings.json, záznam sawmill, BuildingFootprints a
MapProjection. Aktuální katalog ověřen 2026-09-12.

- Maska sever→jih **#### / #E##**, půdorys **4×2**, všech **8 polí obsazených**.
- Kotva je levé dolní pole; dveřní pole vůči kotvě (1,0), venkovní vstup (1,1).
- Zem 160×80 world px při 1×, osově zarovnaná mřížka 40×40.
  Lokálně od severozápadního rohu: zem (0,0)..(160,80), práh (60,80),
  vnější přístupová buňka (40,80)..(80,120).
- Registrace grafiky vychází ze skutečné projekce dveřního pole +(0,0.5).
  Výška terénu posouvá skutečnou zem o −8 world px/úroveň.
- Generátor dostal [nativní podklad](../qa/sawmill-v1/guide.png) hlavní scény,
  skutečný terén a skutečného tesaře 33 world px; [metadata](../qa/sawmill-v1/geometry.json).
  První podklad 1024², 4×, 160 source px/pole.
- Generátor změnil velikost canvasu a vlastní nakreslenou mřížku. První
  nadměrný návrh se odmítl, pravá dílna se zúžila a výsledná kresba se
  znovu přeměřila. Generovaná mřížka nebyla uznána za důkaz.
- Finální raw 1254²: práh (488,912), měřítko 0.16 world px/raw px.
  Skutečný půdorysný podklad v tomto zdroji je (113,412)..(1113,912).
  [Nezávislý překryv](../qa/sawmill-v1/footprint-check.png) kontroluje 11
  viditelných kontaktů: patky, práh, nohy zařízení a kraj dlažby jsou uvnitř.
- Technický export je rovnoměrné zmenšení na 800²; produkční měřítko 0.2508.
  Runtime kotvy, alpha bbox a hashe jsou pouze v
  [manifestu](../../../game/art/buildings/sawmill/v1/manifest.json).
- Bod řazení je samostatně evidovaný a má zde stejné souřadnice jako práh;
  není použit pomocný posun fyzické výšky. Příjemce stínu je skutečný terén.
- Střešní přesahy jsou oddělené: západ přibližně 0.64, východ 3.36 world px.
  Ve volné jižní vstupní buňce není zeď, stojan ani postava.
- Světlý dveřní otvor je přibližně 202 raw px =32.3 world px proti 33px tělu.
  Je těsný a stylizovaný; původní zamýšlený cíl 35–38 px nebyl plně dosažen.
  Skutečný snímek s člověkem je součástí QA, nikoli tvrzení o splněném cíli.

Pro obecný nadhled byla prohlédnuta originální dřevorubecká chata na
[Knights and Merchants NET](https://www.knightsandmerchants.net/information/buildings).
Nebylo obkresleno její uspořádání, předána jako obrazový generativní vstup
ani přibalena její grafika. Prohlédnutý vlastní lumber-hut-v3 sloužil
ke kontrole odlišitelnosti, není schváleným etalonem. Číselný úhel kamery se nevymýšlí.

## Dodané denní a noční stavy

Přesný společný kontrakt: [život výrobních budov](../production-building-life-pattern.md).
Nový reader ProductionBuildingLife je parametrický, pilu aktivuje její vlastní
manifest. Dřevorubecká chata zachovává dosavadní funkční reader.

| Skutečný stav | Obraz |
|---|---|
| Domácí pracovník mimo pilu | Zavřené dveře i okno, bez kouře a odpočinkové postavy |
| Den, skutečná práce uvnitř | Otevřené dveře, zavřené okno, žádná odpočinková postava |
| Den, odpočinek doma | Otevřené dveře a tmavé otevřené okno; tesař u předního levého sloupku se jemně rozhlíží |
| Noc, domácí fyzicky uvnitř | Zavřené dveře, otevřené teplé okno a jemný kouř; postava odpočinku skrytá |
| Noc, prázdný dům | Tmavý zavřený dům bez kouře |
| Cizí dům při zapnuté mlze | Neutrální základ; reader nečte skrytého obyvatele ani práci |
| Rozestavěná budova | Dosavadní vektorové staveniště; žádné nové dokončené vrstvy |

Přidělení samo není přítomnost: rozhoduje domácí pracovník z katalogu a
skutečné inside_building_id. Rest navíc vylučuje náklad, spánek, jídlo,
odevzdávání, odchod a produktivní working/operate. Při povolené skutečné práci
s process_remaining>0 tesař nemůže zároveň odpočívat.
Noční světlo/kouř jsou domácí atmosféra, nikoli signalizace spuštěné výroby.
Neznámý stav není nula zásob nebo potvrzená nepřítomnost.

Dveře, okno a kouř mají vlastní měřené kotvy ve společném canvasu.
Odpočinkový tesař má [samostatný brief](carpenter-rest-v1.md), skutečnou alfu,
tělo 33 world px a tři natočení hlavy na stejném těle. Nepřidává druhou
simulační jednotku, náklad či rezervaci pole. Celý 12sekundový klidový cyklus
čte simulační čas; globální pauza zastaví hlavu a efekty. Svit zůstává lokální.
Klikání, řazení, zakrytí a mlha jsou stejné jako u domu.

## Zásoby a stavební sada

Základní dodávka ještě neměla inventářové rastry. Následný uživatelský
požadavek a jejich implementaci vede [provozní dodatek](sawmill-operation-v1.md).
Autorita: log z building.inputs, nynější input_capacity4; plank z
building.outputs, nynější output_capacity6. Přidávání/odebírání má číst
fyzické předání/spotřebu, nikoli rezervace, nesené kusy nebo světový součet.
Nula musí vyprázdnit stojan, změna kapacity vyžaduje explicitní nové mapování.

Pořadí: zadní architektura → samostatné klády/prkna → přední lišty
a sloupky → domácí vrstvy. Pozice log_slot_1…4 a plank_slot_1…6 jsou
změřené v samostatné provozní geometrii. UI čísel zůstává
samostatný text. Stavový artwork staveniště není součástí tohoto zadání;
dosavadní srovnávání a konstrukce mají zachované chování. Počet kroků
dřevorubecké chaty se nepřenáší.

## Výroba, soubory a přijetí

Vestavěný **imagegen**, konkrétní model nástroj neuvádí.
Skutečná zadání: [první](sawmill-v1-prompt.txt),
[02](sawmill-v1-correction-02.txt), [03](sawmill-v1-correction-03.txt),
[komín/okno04](sawmill-v1-correction-04.txt),
[zavřené okenice05](sawmill-v1-correction-05.txt).
Každá revize dostala uvedený předchozí vlastní výstup; první navíc nativní podklad.

Raw pokusy a finální RGB jsou zachované v docs/art/sources/sawmill-v1/.
[Exporter](../sources/sawmill-v1/export-sawmill.cjs) odstraní změřené technické
pozadí, zachová RGBA master a vytvoří produkční800², manifest a kontrolní archy.
[Asset validation](../qa/sawmill-v1/asset-validation.json) uvádí skutečnou alfu,
otisky, kontakty a poznané meze. [Čistý návrh](../concepts/sawmill-v1.png)
je prezentační kompozice stejného vlastního masteru na světlém podkladu.

Běžný menu→Relief průchod, skutečná výroba/noc, save/load, cílené i regresní
testy a všechny prohlédnuté záběry: [QA](../qa/sawmill-v1/README.md).
Finální herní výtvarné přijetí uživatelem: **zatím neuděleno**.
Společný schválený etalon celé sady: **ne**.
