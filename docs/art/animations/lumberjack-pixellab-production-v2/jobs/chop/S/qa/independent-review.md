# Nezávislá kontrola: chop / S

2026-09-10 · agent animation_services · pouze kontrola skutečných souborů.
Prohlédnut [celý kontaktový arch](contact.png) 0–16 a samostatné raw
fáze 03, 06, 07, 12, 15 a 16 v původních 256 × 256 px.
Žádné generování, úpravy pixelů ani přepsání runtime balíku.

**Závěr: čitelné obouruční seknutí jednou sekerou, bez zjevného základního
rozpadu postavy či nástroje. Jako prototyp pracovní animace použitelné.**
Z izolovaného klipu bych však ještě neoznačil za ověřené kácení stojícího
stromu: úder končí velmi nízko před botami a působí také jako štípání
nízkého špalku. Správný kontakt musí ukázat až skutečný strom a pracovní
poloha ve hře.

| Oblast | Pozorování |
|---|---|
| Jedna sekera | Ve zkoumaných fázích jedna hlava spojená s jedním topůrkem; nevidím zdvojení, odpojenou čepel ani přeskok nástroje do jiné ruky. |
| Obě ruce | V nápřahu i úderu lze číst dvě ruce na topůrku. Mění se jejich vzájemná poloha při vedení sekery, ale žádná další paže nebo chybějící končetina není zjevná. Při 33 px tento detail ještě nebyl nativně ověřen. |
| Průběh | Raw 1–5 zvedají nástroj; 6 přechází do úderu; 7–11 drží nízkou koncovou polohu; 12–16 se vracejí do výchozího držení. Jedna srozumitelná akce. |
| Tempo / výdrže | Největší prostorová změna je 6→7; na dopadu následuje výdrž přibližně pěti fází 7–11. Při 12 fps asi 0,42 s. Působí to jako stylizovaný rychlý úder a delší podržení. |
| Textura během výdrže | Fáze 7–11 nejsou pixelově identické. Silueta je téměř stejná, uvnitř se nepatrně mění textura/barvy. Proto je nelze bez výslovného rozhodnutí vyřadit jako přesné duplikáty. |
| Trup / nohy | Trup se při úderu předkloní, chodidla vizuálně drží stejný postoj; nevidím přešlapování či chůzi. Změna dolního alfa obalu na y=225 je především nízko vedená čepel, nikoli důvod posouvat celou postavu. Skutečný kontakt chodidel s terénem není tímto archem ověřen. |
| Smyčka 1–16 | Raw 16 se vrací do diagonálního výchozího držení, raw 1 přirozeně pokračuje nápřahem. Nemusí být shodné, aby časová sekvence dávala smysl. Pomocná [kontrola přechodu 16→1](independent-loop-check.json) není vizuálním schválením celé smyčky. |

Raw 00 zůstává původní vstupní referencí. Tento posudek **není** pokyn
měnit výběr packeru, nastavení fps, délku výdrže ani idle. Zde nebyla
spuštěna nativní pracovní animace, nebyl vložen strom a neověřovala se
událost zásahu nebo herní fázování. Výtvarné přijetí uživatelem není doložené.
