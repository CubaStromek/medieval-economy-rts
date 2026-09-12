# Nezávislá kontrola chůze E · PixMiniMax 8

**2026-09-10. Doporučení: ponechat; snímky 01–08 jsou vhodným kandidátem
pro pohybovou smyčku.** Prohlédnuto všech devět skutečných PNG na
[kontaktním archu](contact.png), navíc jednotlivě 00, 01, 04 a 08.
Mechanická měření: [statistics.json](statistics.json) a doplňková
[kontrola vybrané smyčky](loop-selection-analysis.json).

## Celý krok a smyčka

- Blízká **pravá noha** je vpředu v okolí 01 a 08 a vzadu v 04–05.
  Vzdálenější noha střídá opačně; jsou viditelné fáze zdvihu, průchodu a
  postavení před tělo. V těchto osmi generovaných fázích je **jeden celý
  dvojkrok**, nikoli opakované předsouvání stejné nohy.
- Přechod **08 → 01** má průměrný RGB rozdíl po složení na šedý podklad
  **1,566004** na stupnici kanálů 0–255. Běžné sousední přechody v původním
  sledu mají hodnoty přibližně **1,447–3,239**. U této hranice nevidím
  výjimečný skok tvaru, úchopu nebo těla. Číslo podporuje prohlédnutý sled;
  samo není důkazem kvality chůze na terénu.
- Koncový 08 **není přesnou kopií reference 00**. Postava se vrací do
  odpovídající fáze, ale nohy a drobné detaily se liší. Proto ponechat 00
  v archivu/reference a do pohybové smyčky explicitně vybrat 01–08.
  Tato kontrola snímky nesmazala, nepřeskupila ani neupravila.

Oproti [S/24](../../S/qa/independent-review.md), kde je přibližně stejný
osmifázový dvojkrok zopakován třikrát, E/8 dosahuje úplného kroku jedním
osmifázovým sledem. Kratší zadání v tomto konkrétním pohledu nezpůsobilo
ztrátu druhého kroku. Z toho nelze předem odvodit kvalitu jiné činnosti
či směru. Při stejném fps mají osmifázový E a opakované osmifázové cykly S
podobnou základní frekvenci kroků; přepínání směrů stále vyžaduje herní QA.

## Postava, sekera, obrazová poloha a alfa

Identita a oděv zůstávají soudržné. Sekera se drží v anatomické pravé ruce,
má stále jednu hlavu a jedno topůrko, nevymizí ani nepřeskočí do druhé ruky.
Je nesena nízko, mírně šikmo před pravou nohou podle vstupní reference.
Proti ní se drobně mění loket, silueta bot a kresba detailů; nevidím zásadní
anatomický rozpad nebo otočení postavy z východního směru.

Hlava zůstává přibližně kolem stejného středu; horní řádek čepice kolísá
jen mezi y=49 a y=52. Rozšíření bočních mezí kresby souvisí zejména s krokem
a rukou/nástrojem. Není důkaz kumulativního posouvání celé postavy po canvasu.
Tato mez není fyzickou kotvou a nebylo provedeno zarovnání podle živého obalu.

Všech devět výstupů má 256 × 256 px, skutečný viditelný obsah i průhledné
okolí, alfa 0/255 a žádný nenulový alfa pixel na hraně. Na prohlédnutém sledu
není bílý obdélník, namalovaná šachovnice ani uříznutá část těla či sekery.
Zůstává ověřit tempo, kontakt bot s terénem, drobné blikání kresby v herní
velikosti a změny směru. Výtvarné přijetí uživatelem tímto záznamem nevzniká.

**Skutečná cena tohoto požadavku:** 3 zahrnuté generace, shodně v
`usage.generations` a `last_response.billing_usage.generations` v
[result.json](../result.json); USD je 0. Změna globálního zůstatku není při
souběžných úlohách samostatným měřením ceny tohoto klipu.
