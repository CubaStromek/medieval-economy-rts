# Nezávislá kontrola: walk_axe / NE

2026-09-10 · agent animation_services · skutečných 25 raw PNG 0–24.
Prohlédnut [celý kontaktový arch](contact.png) a samostatné raw 03, 06,
09, 12, 24 v původních 256 × 256 px. Posuzovaná smyčka: **1–24**;
raw 00 zůstává vstupní referencí.

**Výsledek: základní vizuální a technická kontrola prošla.** Severovýchodní
chůze ukazuje záda a pravý bok, jednu sekeru v pravé ruce a prázdnou levou
ruku. Obě nohy postupně vystupují z překryvu; nevidím záměnu rukou,
ztrátu končetiny, zdvojení sekery nebo odpojenou hlavu nástroje.

| Oblast | Pozorování / měření |
|---|---|
| Směr a ruce | Celá sekvence zachovává severovýchodní pohled. Pravá ruka na pravé straně obrázku nese sekeru, levá je prázdná. Topůrko a hlava zůstávají čitelné v jednom předmětu. |
| Nohy | Obě nohy mění přední/zadní polohu; ve fázích 3–7 a 15–19 se z tohoto úhlu více překrývají, ale v dalších fázích se znovu čitelně oddělí. Jde o celé střídání nohou, nikoli jednu stále stejnou nohu. |
| Počet kroků | V raw 1–24 jsou dvě zhruba dvanáctifázová opakování dvojkroku. Pro požadovaných 0,8 s na dvojkrok vychází **15 fps**; toto je návrh metadat, raw PNG se nemění. |
| Registrace | Horní mez y=47–52 px znamená malý svislý bob. V kontrolní oblasti `y<84` drží pravá alfa mez x=143; levá x=94–97 zahrnuje i rameno. Nevidím postupné odplouvání. Tato oblast není nová autorita pro pivot ani pro automatické srovnávání. |
| Obal | Alfa ≥1: levá mez 85–88, horní 47–52, pravá 184–190, dolní 201–215 px. Mění se kvůli nástroji a kroku; podle bbox se nemá přepočítávat kotva ani velikost. Pravá/dolní hranice výlučné. |
| Alfa | Všech 25 raw fází obsahuje viditelné i průhledné pixely. Nula viditelných pixelů na hraně plátna, žádná varování helperu. |
| Smyčka 24→1 | Póza pokračuje do dalšího kroku. Průměrná změna RGB po složení na #505550 je 2,968084 proti mediánu vnitřních přechodů 2,752757; přechod není výrazný číselný extrém. Číselná kontrola sama není schválením plynulosti. |
| Duplikáty | Žádné přesně shodné RGBA dvojice. Z tohoto posudku neplyne vyřazování fází. |

Důkazy: [statistics.json](statistics.json),
[měření a přechod 24→1](independent-loop-check.json).
Helper ověřil nezměněné zdrojové soubory. API data, PNG ani runtime balík
při této kontrole nebyly přepsány.

**Neověřeno:** nativní NE při 33 world px, shoda tempa s fyzickým pohybem,
kontakt s terénem, změny směrů, práce/náklad a výtvarné přijetí uživatelem.
Klip je způsobilý k dalšímu společnému balení a kontrole v reálném měřítku;
celá sada ani běžná herní cesta tím nejsou schválené.
