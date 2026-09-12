# Kontrola osmi pohledů dřevorubce se sekerou

**2026-09-10 · nezávislá vizuální kontrola Codex.** Prohlédnuto všech osm
skutečných RGBA PNG jednotlivě i na [kontaktním archu](contact.png).
Otisky souborů, rozměry, alfa a přesné meze jsou ve
[statistics.json](statistics.json); parametry generování v
[provenance.json](../provenance.json) a [request.json](../request.json).
Tento záznam hodnotí směrové reference před animací. Není schválením výsledné
animace, kotev, herní integrace ani výtvarného etalonu uživatelem.

## Skutečné pořadí a držení sekery

| Index | Pohled | Pozorovaný úchop a poloha nástroje |
|---|---|---|
| 00 | S | Anatomická pravá ruka je vlevo na obrázku; sekera směřuje ostřím dolů. Levá ruka je prázdná. |
| 01 | SE | Pravá ruka blíže k pozorovateli drží topůrko před tělem, přibližně vodorovně. Levá ruka je prázdná. |
| 02 | E | Pravá blízká ruka drží sekeru před tělem vodorovně; hlava nástroje je čitelná vpravo. |
| 03 | NE | Pravá ruka vpravo na obrázku drží šikmé topůrko; hlava sekery směřuje vzhůru a dopředu. Levá ruka je za tělem. |
| 04 | N | Anatomická pravá ruka je vpravo. Sekera je částečně zakrytá paží: část topůrka a hlavy je patrná u pravého ramene, další část u ruky. Levá ruka je prázdná. **Sekera nechybí.** |
| 05 | NW | Pravá vzdálenější paže je z velké části zakrytá tělem. Hlava sekery vyčnívá před vzdálenějším ramenem; úchop je částečně zakrytý. Bližší levá ruka je prázdná. **Částečné zakrytí není chybějící nástroj.** |
| 06 | W | Vzdálenější pravá ruka drží topůrko vodorovně před tělem. Bližší levá ruka visí volně; hlava sekery je čitelná vlevo. |
| 07 | SW | Pravá vzdálenější ruka drží sekeru šikmo dopředu a dolů. Levá blízká ruka je prázdná. |

**Výsledek:** pořadí je `S, SE, E, NE, N, NW, W, SW`. Není důkaz o výměně
pravé a levé ruky. V každém pohledu lze nástroj identifikovat. U NW není
celý úchop viditelný, proto nelze tvrdit přesnou anatomii všech zakrytých prstů.

Nástroj však mezi směry **mění nesenou polohu**: S ostří dolů, E/W přibližně
vodorovně, severní pohledy výše. Není to pouze perspektivní změna jedné
striktně zachované pózy. Přepnutí směru při chůzi může způsobit viditelný skok
sekery. Také nohy nezačínají ve zjevně totožné fázi kroku. Ověřit při animaci
a při skutečné změně směru; automaticky nezaměňovat tento stav za jednotnou
osmisměrnou animační fázi.

## Identita, alfa a obrazová poloha

- Hnědá čepice, obličej/vousy, olivová tunika, světlé vyhrnuté rukávy, pásek,
  hnědá přední zástěra, zadní světlé vázání a vysoké boty tvoří soudržnou postavu.
  Perspektivní kresba tváře a objem některých končetin se mírně mění.
- Všech osm výstupů má 256 × 256 px, skutečné průhledné i neprůhledné pixely,
  žádné poloprůhledné pixely a nulový počet nenulových alfa pixelů na hraně.
  Na prohlédnutých výstupech nejsou části těla či sekery uříznuté okrajem.
- Hlava zůstává přibližně kolem vodorovného středu canvasu. Rozsáhlé změny
  levé/pravé meze celkové alfy často způsobuje sekera, nikoli posun chodidel.
- Po vizuálním určení, že horní extrém je čepice a spodní extrém bota,
  odpovídají horní řádky čepice rozsahu **y=39–52** a nejnižší viditelné řádky
  bot rozsahu **y=197–214**. Rozdíl 17 zdrojových pixelů spodního extrému
  je diagnostika změny kresby/pózy, **nikoli hotová fyzická kotva**. Výška od
  čepice po nejnižší botu se pohybuje přibližně mezi 153 a 166 pixely.
- S jednou nohou vysunutou dopředu má jinou projekci chodidel než N či boční
  pohledy. Samotné zarovnání všech dolních alfa mezí by zaměnilo animovanou
  končetinu za pevný kontakt se zemí. Další registrace musí vycházet ze stejného
  společného bodu postavy a z kontroly celé animace; tento review žádné kotvy
  ani obrázky neposunul.

## Rozhodnutí pro další práci

Směrové reference jsou použitelné pro zadaný animační test: identita je
soudržná, všechny směry jsou rozlišitelné a sekera je přítomná ve správné ruce.
Zůstává ověřit stabilitu konkrétního úchopu v čase, rozdíly polohy sekery při
změně směru, společnou registraci postavy a skutečný kontakt se zemí ve hře.
Jednotlivé animace ani celá sada zatím tímto záznamem neprošly.

**Zásahy:** pouze tento záznam QA; žádný vstupní ani výstupní obraz nebyl upraven.
