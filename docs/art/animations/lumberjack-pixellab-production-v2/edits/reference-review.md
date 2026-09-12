# Kontrola prvních pracovních návrhů

Datum: 2026-09-10. Výstupy `/edit-image`, 1 zahrnutá generace za návrh.
Nejde o vybrané produkční reference; navazující animace z nich nebyly zadány.

## Log-S — odmítnutý návrh

Soubor `log-S/images/frame_00.png` byl prohlédnut. Generátor navzdory zadání
nakreslil kládu napříč přes obě ramena a obě ruce zvednuté. Chybí požadovaná
sekera na levém boku. Aktuální požadavek v autoritativním briefu je jedna
kláda podélně na anatomickém pravém rameni, přidržovaná pravou rukou;
levá ruka zůstává volná. Tuto chybu nepřenášet do dalších směrů.

## Chop-S — pracovní návrh k dalšímu zpřesnění

Soubor `chop-S/images/frame_00.png` byl prohlédnut. Obě ruce skutečně svírají
jedno topůrko a obě boty jsou na zemi. Generátor ale pozměnil velikost a
rozložení těla na plátně; vrch čepice je přibližně o 11 px výše než u
společného jižního základu. Jde o pozorování obrázku, nikoli o fyzickou
kotvu či přesné měření kostry. Neanimovat jako již sladěný hotový základ.

## Technický stav obou souborů

Úplná barva byla bezeztrátově rekonstruována z vrácených raw RGBA bytes;
klient porovnal rozměry, počet barev i polohu s PNG poskytovatele. Podrobnosti
jsou v příslušných `images.json`. Oba obrazy mají všech 65 536 alfa hodnot
255, tedy bílé neprůhledné pozadí i při požadavku `no_background: true`.
Nejde o průhledné produkční PNG. Původní odpovědi zůstávají zachované.

## Další připravený postup

Vyzkoušet placený nástroj Edit image (Pro) s podrobnějším zadáním a stále
stejným jediným vlastním jižním masterem. Navazující použití výstupů
PixelLabu čeká na výslovné potvrzení, které vyžádala automatická schvalovací
kontrola; otázka byla položena uživateli v této konverzaci.
