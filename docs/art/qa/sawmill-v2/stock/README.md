# Pila v2 — zásoby a popředí

Datum **2026-09-12**. Technická extrakce a registrace vlastních kreseb po
nativním ověření nového domu a prohlídce zásobního kompozitu. Tento záznam
ověřuje soubory a izolované obrazové stavy; hlavní nativní průchod pily,
skutečnou výrobu, dopravu a mlhu vede nadřazené QA.

Autoritativní výstup je
[stock/geometry.json](../../../../../game/art/buildings/sawmill/v2/operation/stock/geometry.json).
Fragment pro skládání provozního manifestu je
[stock-fields.json](../../../sources/sawmill-v2/stock-fields.json):
`stock.log`, `stock.plank`, `work.foreground`, hashe a provenance.

## Vlastní původ a měřítko

Čtyři klády používají **stejný vlastní malovaný kus jako dřevorubecká chata**,
ze zdroje `docs/art/concepts/lumber-hut-v3-stock/logs-6.png` a jeho původního
extrakčního polygonu. Zdrojové měřítko `640/1254 × 0,225` world px je
zachované. Nová produkční kláda je pouze technický výřez 126 × 124 px,
se skutečnou alfou a čelní kotvou `[102,96]`; nedošlo ke změně natočení,
proporcí, barev ani kresby. Skladba je 2 + 2.

Prkno je nezměněný RGBA výřez 1299 × 694 px z vlastního high-res masteru
pily v1. Nový regál v masteru má obdobný směr a kompozit ukázal, že další
obrazová generace není potřebná. Každý kus se kreslí uniformně v obdélníku
76 × 40,603541 px domu, tedy 14,236035 × 7,605703 world px. Drží přesný
poměr stran původního výřezu. Dvě police mají po třech postupně přibývajících
kusech; zdrojové soubory v1 se nezměnily.

Rozdíl od předmasterového návrhu je záměrný a měřený: skutečný nový dům se
kalibroval na **0,18731625 world px/px** místo původně plánovaných 0,25.
Klády zachovaly world měřítko chaty, takže jejich kresba v novém 800² canvasu
je větší. Absolutní kotvy určil skutečný prázdný stojan, nikoli starý guide.

## Vrstvy

`foreground.png` obsahuje pouze přesné pixely nového
`game/art/buildings/sawmill/v2/finished.png` se SHA
`642c85d997c985c62750bbb0e70270e60fe7bd7834b77729f5a8be3bc140591a`.
Masky jsou nově měřené pro přední sloupky a lištu lože, pravý stojan,
levou hranu místnosti, prostřední a pravý sloup a příslušné vzpěry.
Nepoužívá se maska ani vzorek domu v1. Přední lišta lože byla v detailu
znovu přeměřena, aby nepřekrývala konce klád plochou mimo skutečné dřevo.

Zásoby se vykreslují po jednotlivých slotech; společné popředí patří **až
za zásoby a pracovníka**. Fragment proto uvádí popředí v `work.foreground`.
Tato kresba podle stávajícího rendereru platí i při neaktivní práci se
známým stavem budovy. Zásoby jednotlivě nemají další duplicitní popředí.
Pracovní stůl, zpracovávaná kláda a kontakty nástroje nejsou součástí tohoto
exportu.

## Ověření

Prohlédnuté finální obrazy:

- [Plné zásoby v detailu](stock-full-detail-3x.png).
- [Všech pět stavů klád 0–4](log-all-states-2x.png).
- [Všech sedm stavů prken 0–6](plank-all-states-2x.png).
- [Celý dům s plnými zásobami](stock-full.png).

[Dekódované PNG a přírůstky](asset-verification.json) potvrzují skutečnou
alfu všech exportů a nulový zbytkový purpurový klíč. Čtyři kládové přírůstky
mění 2509, 2609, 2640 a 2752 viditelných pixelů v 800² kompozitu; šest
prken mění 1148, 1190, 1171, 1162, 1191 a 1186 pixelů. Žádný slot není
prázdný ani zcela ukrytý. Nulové stavy nechávají prázdné dřevěné lože
a dvě trvalé konstrukční police. Foreground má 28 034 nenulových pixelů
a zachovává původní RGBA hodnoty domu ve vybrané oblasti.

Čtyři měřené kontakty stojanů `[338,580]`, `[427,557]`, `[620,472]`,
`[706,518]` jsou v obsazeném půdorysu 4 × 2. Souřadnice vůči skutečnému
dveřnímu prahu a kontrola každého bodu jsou v metadatech. Čelní kotva
klády a spodní bod prkna označují uložení zboží na podpěře; nejsou to
nové pozemní registrační kotvy domu. Žádné zboží nezabírá jižní přístup.

## Nezávislá závěrečná kontrola měřítka a země

[Závěrečný přepočet](final-size-ground-check.json) ověřil stejný původní
obraz a shodu měřítka: chata i nová pila kreslí jeden pixel původní klády
jako **0,114832535885 world px** (číselný rozdíl pouze 1,39 × 10⁻¹⁷).
Žádné zvětšení samotného zboží vůči chatě nevzniklo.

Samostatný surový výřez v2 má alfa obal 13,894737 × 13,779904 world px;
již resamplovaná a popředím oříznutá kláda chaty 14,175 × 13,5 world px.
Rozdíl obalu je přibližně 0,28 world px na osu, při 2,4× méně než
0,68 obrazového pixelu. Příčina byla ověřena reprodukcí původního
exportu chaty: před popředím má obal `[151,465,214,527]`, po něm
`[151,465,214,525]`. Rekonstrukce má **nulový rozdíl alfa pixelů**
proti skutečné produkční kládě chaty; její přední lišta ořezává
0,45 world px výšky. Rozdílný obal tedy vzniká resamplingem a konkrétním
zakrytím, nikoli odlišným měřítkem nebo změnou proporcí původní klády.

Při maximální zásobě jsou i konzervativní obrazové obaly obou skupin
uvnitř obdélníku obsazené země. Nejbližší vlastní podpěra zůstává
**14,68 world px severně od hranice jižního dveřního přístupu**;
všechny čtyři kontakty stojanů prošly jednotlivě. Finální kontrola pouze
četla produkční soubory a znovu potvrdila jejich nezměněné hashe.

Původní maketa byla přezkoumána nad skutečným domem a finální export
znovu prohlédnut ve všech množstvích. Toto není záznam skutečného dopravce
nebo změny inventáře při běžné hře; tyto kontroly je nutné číst v nativním
QA nové revize, bez přeznačování výsledků v1.
Nativní snímky a ověření s pracujícím tesařem zajišťuje samostatná
geometrická kontrola pily v2 v [nadřazeném QA](../README.md).
