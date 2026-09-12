# Nezávislá kontrola: chop / W

2026-09-10 · agent animation_services · **REPAIR — koncový sek jde za postavu**.
Prohlédnut [celý arch](contact.png) raw 0–16 a samostatné fáze
[04](../images/frame_04.png), [07](../images/frame_07.png),
[08](../images/frame_08.png), [12](../images/frame_12.png).

Postava má sekat na západ, tedy doleva v obrázku. Raw 3–6 zvedají sekeru
přes ramena a záda; trup se přitom výrazně otáčí. Raw 7 prochází polohou
s čepelí vlevo, ale raw 8–12 už drží hlavu sekery **vpravo od těla**, za
osou pracovníka ve směru opačném k W. Raw 13–16 se vracejí. Výsledek
působí jako přetažený rotační švih, jehož dlouhá koncová póza není u
očekávaného západního cíle.

| Oblast | Výsledek |
|---|---|
| Jedna sekera / dvě ruce | **Prošlo základní prohlídkou.** Jeden navazující nástroj, dvě ruce na topůrku. Nevidím druhou sekeru, oddělenou hlavu nebo chybějící paži. |
| Směr a místo zásahu | **REPAIR.** Fáze 8–12 drží čepel na pravé straně, proti požadovanému W. Výška je přibližně pas/kyčel, ale prostorový cíl zůstává nesprávný. |
| Nohy / trup | Nohy zůstávají ve stejném postoji, postava nezačne chodit. Velká rotace trupu a nástroje přes záda vysvětluje chybný konec švihu; skutečný terén zde není. |
| Smyčka 1–16 | Má nápřah, průchod úderem a návrat. Raw 16 je podobný výchozímu držení, takže návaznost 16→1 není hlavní problém. |
| Přidané objekty / FX | **Prošlo:** bez stromu, špalku, efektů, částic nebo dalšího okolí. |
| Alfa / původ | [Helper](statistics.json): 17 skutečných RGBA fází, bez varování a přesných duplikátů, všechny zdrojové soubory zůstaly nezměněné. |

Pro opravu je třeba vést úder dolů a dopředu **nalevo od těla** a tam
zastavit čepel u zamýšleného kmene ve výši pasu. Dlouhá dopadová výdrž
nemá skončit na pravé straně za pracovníkem. Konkrétní kontakt vyžaduje
ověření proti skutečné pracovní poloze a stromu.

Žádný pixel, API záznam ani runtime balík nebyl změněn. Raw 00 je vstupní
reference, nikoli zde zavedený runtime idle. Nativní herní větev a
uživatelské výtvarné přijetí zatím nebyly ověřeny.
