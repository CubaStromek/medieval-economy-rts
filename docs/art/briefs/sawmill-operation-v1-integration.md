# Pila — integrace zásob a práce v1

Datum **2026-09-12**, stav **zapojeno a ověřeno ve hře**.
[Zadání](sawmill-operation-v1.md), [geometrie domu](sawmill-v1.md),
[studie původní hry](../references/sawmill-kam-study-2026-09-12.md).

## Rozsah a data

Uživatel výslovně doplnil zásoby klád a prken a činnost tesaře k již zadanému
přímému zapojení pily do hry. Simulace, kapacity, cena, půdorys, projekce
ani save formát nepotřebují změnu. Postava u stolice je kreslená reprezentace
skutečného domácího pracovníka ve vrstvě domu.

`SawmillOperation` pozoruje každý skutečný simulační tick v hlavní scéně.
Čte fyzické vstupy/výstupy, samostatný rozpracovaný kus a skutečnou práci
z `ProductionBuildingLife`. Interpoluje minulý a již vykonaný produktivní
krok. Výživou vynechaný tick nepřidává pohyb. Reset se volá při novém světě
a načtení, i při načtení stejného ticku do stejného World objektu.
Historie je pouze zobrazovací cache, ne nové save pole.

## Kreslení a vrstvy

`SawmillOperationArt` přijímá jen oprávněný přehled a registrovaný dům.
Z `operation/manifest.json` načítá cache skutečných textur a alfa masek;
stejný geometrický výsledek používá kreslení i výběr. Nula nekreslí žádný
kus. Nepodporovaná budoucí kapacita má pravdivý číselný fallback místo
tichého oříznutí množství do známé hromady.

Pořadí: původní dům → lokální zadní stěna → uložené kusy → kláda v řezu →
pracovník → původní přední podpěry → domácí okno/kouř/odpočinek.
Skupina zachovává řádkové řazení, světlo, fyzickou výšku a mlhu domu.
Cizí mlha vrací neutrální stav před čtením privátních zásob/obyvatele;
prázdná zadní stěna je statická architektura.

## Vlastní podklady

Zásoby mají vlastní log a prkno z vestavěného imagegen, přesné sloty
v `operation/stock/geometry.json`. Přední podpěry z původního vlastního
domu překrývají zboží. [QA zásob](../qa/sawmill-operation-v1/stock-art-qa.md)
patří k této revizi, nikoli k dřívější prázdné pile.

Imagegen upravil dílnu bez zavěšené velké pily. Do hry vstupuje jen malá
maskovaná zadní stěna; původní vnější obrys a kontakty domu zůstávají přesné.
Samostatný vlastní log sedí na stolici a přetrvává i při pauze nebo v noci.

Tesař má šest skutečných poloh pro tah/vrat ruční pily, stejnou identitu
jako při odpočinku a tělesné měřítko 33 world px. Pevná opěrná paže,
společné spodní tělo a tuhý list řeší drift generované série. Masky,
registrace, provenance a měření patří k exportu pracovníka; přesné prompty
jsou v `docs/art/sources/sawmill-operation-v1/`. Původní KaM obrazy nebyly
generativním vstupem ani produkční vrstvou.

## Ověření

Stavové testy pokrývají skutečný příjem nosičem, spotřebu, dvě vyrobená
prkna, jejich vyzvednutí, produktivní i vynechané ticky, pauzu, mlhu,
rychlost a save/reset. Asset testy vyžadují skutečné importované obrázky
a pozitivní kontrolu. Nativní přehledy oddělují řízené kombinace od běžného
menu → Relief → výroba → noc → save/load. Záznam práce má skutečný
simulační i časový postup. Finální výsledky a snímky vede
[QA této revize](../qa/sawmill-operation-v1/README.md).

Finální podklady prošly 20/20 cílených kontrol bez okna i nativně
(včetně skutečných pixelů a výběru) a 849/849 úplné povinné sady.
Řízená nativní kontrola má 71 snímků; samostatná běžná cesta obsahuje
přirozenou dodávku, výrobu dvou prken, noc s přerušenou dávkou a save/load.
Záznam 1× používá 35 skutečně časovaných snímků a zachytil všech šest póz.
To dokládá implementaci; nejde o výtvarné schválení celé sady uživatelem.
