# Pila — geometrický preflight provozu v1

Datum **2026-09-12**, měřeno přímo na současném `finished.png` **800 × 800**,
SHA-256 `349924968b535bf299d9933e00d476bdf357f87a3011b628a420a2d7e06315a4`.
Stav: **technický návrh před výrobou inventářových rastrů a pracovní pózy**.
[Vodicí obrázek](guide.png) · [detail 4×](guide-work-area-4x.png) ·
[strojová geometrie](geometry-preflight.json) · [reprodukovatelný overlay](build-guide.cjs).

Přečten současný [brief pily](../../briefs/sawmill-v1.md),
[manifest](../../../../game/art/buildings/sawmill/v1/manifest.json),
[výtvarný manuál](../../building-style-guide.md) a [workflow](../../object-implementation-workflow.md).
Původní dům ani jeho manifest tento preflight neupravuje. Všechny vodicí tvary
jsou technické značky; nejde o dodanou produkční kresbu zásob.

## Souřadnice a fyzická zem

Zde uváděné body jsou **produkční house px v 800² canvasu**. Přesný převod
na původní 1254² raw je **×1.5675**, do world px **×0.2508**.
Prah domu zůstává `[311.323764,581.818182]`. Ground bounds jsou
`[72.089314,262.838915]–[710.047847,581.818182]`, odpovídají půdorysu4×2.
Volná jižní přístupová buňka je `[231.578947,581.818182]–[391.068581,741.307815]`.
Zdi ani stojany se neposouvají a nevzniká nová obsazená buňka.

Zvýšené zásoby samy neleží na terénu. Footprint se ověřuje přes patky
jejich existujících podpěr: lože `[382,540]`, `[426,533]`; regál `[586,524]`,
`[656,539]`. Všechny jsou uvnitř obsazené země. Nejjižnější z těchto kontaktů
je42 produkčních px (10.5worldpx) před koncem půdorysu. Renderované zásoby
nedosáhnou přístupového čtverce ani dveřního otvoru. Skutečný svah se následně
ověří v nativní hře, tento obrázkový preflight jej nenahrazuje.

## Zásoby a pořadí

| Zóna | Prohlédnutý stálý nábytek | Počet a plán |
|---|---|---|
| Klády vlevo | Malé nízké lože přibližně x374–426, y476–541 | `building.inputs.log`, kapacita4;2×2 kompaktní zásoba, každý kus samostatně |
| Prkna vpravo | Dvoupatrový regál přibližně x577–659, y442–539 | `building.outputs.plank`, kapacita6; dolní3 pak horní3 |

Původní lože je výrazně menší než u dřevorubecké chaty. Nelze na ně přenést
její dlouhou kládu a její kotvy. Zdejší generovaný log musí být kompaktní,
orientovaný do hloubky horní-levý → dolní-pravý konec. Přední čela umístit
mezi nejbližší sloupky, aby alespoň část každého z4kusů zůstala čitelná.
Předběžné rozměry a pozice jsou v JSON; při exportu se ještě upraví podle
skutečné siluety tak, aby žádná čela nezmizela za pravým sloupkem lože.

Prkna kopírují perspektivní směr bočních lišt regálu. Navržený prop envelope
76×42px, sloty v pořadí množství1…6 jsou `[579,479]`, `[579,473]`, `[579,467]`,
`[579,443]`, `[579,437]`, `[579,431]`. To jsou levé horní rohy prop canvasu,
nikoli body země. Raw pozice jsou ve strojovém JSON. Horní a spodní trojice
stojí na dvou existujících policích; nekreslit6prken do jedné neprůhledné hromady.

Při počtuN se kreslí sloty1…N; fyzický pickup odstraní poslední obsazený slot.
Pořadí kreslení uvnitř vrstvy je spodní/zadní kus → vyšší/přední kus.
Kapacita není vyčtena z obrázku:4 a6 jsou aktuální katalog. Nula nekreslí
žádné zboží. Jinou kapacitu musí renderer výslovně odmítnout nebo přemapovat;
nesmí tichým clampem tvrdit plný stav při jiném inventáři.

## Masky a překrytí

`foreground_polygons_house` v JSON obsahuje konkrétní kandidáty:
přední sloupky a příčku malého lože, středový a pravý stavební sloup,
přední sloupky a čela polic pravého regálu, levé ostění a spodní okapový pás.
Raw polygon je vždy stejná maska ×1.5675. Červené plochy vodicího detailu
byly prohlédnuty; nejde ještě o důkaz bezchybných produkčních okrajů.

Exportovat **původní RGBA pixely domu** pod těmito maskami jako samostatné
popředí. Nechat vlastní alfu původního domu, masky nejsou barevnou náhradou
dřeva. Při finálním složení preferovat vynulování stock pixelů pod maskou
nebo přesné překreslení původního popředí; nedělat barevné nové nosníky.
Maskovat jen skutečně přední části. Zadní lišty musí ležet za zásobou.
Statický stůl a jeho pravá stojina patří do samostatného pracovního systému;
zásoba klád nesmí překrýt levý okraj stolice.

Pořadí: prázdná architektura → uskladněné klády/prkna → masky stojanů →
samostatná pracovní geometrie a člověk se svým správným překrytím → život domu.
Pracovní kláda na stole je `process_remaining>0` podle skutečné produktivní
operace; není dalším kusem inventáře a nesmí zvětšit `inputs.log`.

## Pracovník a pila — návrh pro samostatnou výrobu

Tesař33worldpx má v měřítku tohoto domu **131.578947 house px**.
Pracovní otvor je přibližně x372–553, y391–555. Původní kovový list je
uvnitř `[437,447]–[516,473]`, stůl má horní plochu přibližně polygon
`[424,485],[526,478],[545,487],[434,495]`. Kontaktní oblast řezu kolem `[478,470]`.

Přímé postavení ZA rám na x490 by dalo horní břevno před spodní část obličeje.
**Doporučená poloha je vpravo před stolicí:** chodidla `[538,549]`
(raw `[843.315,860.558]`), hlava asi `[534,417.421]`, envelope x513–555.
Hledí k pile vlevo, ruce mohou navazovat kolem `[514,448]`, `[525,431]`.
Je to prostorový návrh; skutečný úchop, lokty a dráhu nového stroje určí
prohlédnutá póza, nikoli pouhé převzetí těchto dvou bodů.

Horní hlava je pod okapem a pracovník nezasahuje do přístupu. Vpravo jej
musí správně překrýt středový sloup, nikoli zásoba prken. Stůl/kladivo/list
se nesmí bezmyšlenkovitě kreslit přes celé tělo; pravé ruce a přední tělo
jsou před stolicí. Obě nohy a bod stínu zachovat na skutečné zemi.

## Praktický export bez nového domu

1. Imagegen dostane vlastní hotovou pilu pouze jako materiálovou/kamerovou
   referenci a technický směr skladovacích lišt. Vygeneruje samostatně
   **jednu kládu** a **jedno prkno**, bez polic, lidí, země, stínu a pozadí.
   KaM není obrazový vstup.
2. Uchovat raw/prompt; skutečnou alfu ověřit. Pokud je použit technický klíč,
   změřit jeho vlastní barvu a rozsah, odstranit lem, nemít namalovanou šachovnici.
3. Celek každého prop zmenšit jedním měřítkem a registrovat v samostatném
   canvasu. Rozměry/vizuální kontakty přeměřit, uchovat hash a trim offset.
4. Sloty jsou prosté překlady stejného vlastního props PNG. Stojanové
   popředí vyříznout z původního domu; bez regenerace architektury.
5. Prohlédnout všechny0–4/0–6stavy i společné maximum na skutečné pile,
   na1× a detailu. Potom dodávku ověřit nativně s fyzickým předáním a mlhou.

Preflight neprováděl simulační ani produkční změny. Následná autorizovaná
výroba zásob má vlastní soubory `sawmill-operation-v1` a nezávislý stock manifest;
stávající manifest pily se mění až při jejím konkrétním zapojení.
