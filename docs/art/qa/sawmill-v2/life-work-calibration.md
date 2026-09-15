# Pila v2 — registrace života a práce, 2026-09-12

Tento záznam odděluje technický preflight od následného nativního důkazu.
Jde o původní kalibraci ze dne 2026-09-12. Pracovní výšku a kotvu od
2026-09-13 nahrazuje [oprava usazení truhláře](../../briefs/carpenter-sawmill-spatial-v1-integration.md):
31world se zachovaným kontaktem dlaně, vlastní kontaktní stíny a lokální
zastínění těla; odpočinková výška33world zůstává.
Autoritou hodnot je `sources/sawmill-v2/life-work-fields.json`; generuje jej
`export-life-work.cjs`. Geometrie domu je v `concept-04-geometry.json`.

Odpočinkový tesař má stejné vlastní PNG a výšku33world jako v1. Nový kontakt
raw(289,1023) jej staví na přední levý kamenný sokl; horní část těla leží
u sloupu, střed dveří a levé okno zůstávají volné. Technický kompozit byl
prohlédnut; nejde ještě o důkaz nočních otvorů ve hře.

Pracovní tesař používá všech šest původních vlastních fází bez změny pixelů,
nový kontakt raw(974,890), původní měřenou výšku412sourcepx a ground contact.
Boty stojí na obsazené zemi před malovanou hranou dílny. Pracovní kláda je
rigidně otočená o15° podle směru stolice. Všechny fáze byly vizuálně porovnány
v `work-contact-preflight.png`: podpůrná ruka zůstává na kládě, pila s druhou
rukou vykonává tah, trup a nohy neposkakují. Tento zvětšený technický kompozit
nemá herní zem ani budoucí masky; finální nativní práce jej musí doplnit.

Dveřní a okenní čtyřúhelníky jsou změřeny na novém masteru04. Základ obsahuje
zavřené dřevo, stav pouze odhaluje tmavý interiér nebo teplé noční okno.
Komínový počátek leží na vrchní ploše vlastního kamenného komína. Staré v1
otevřené okenice ani stará záplata dílenské stěny se nepřenášejí.
