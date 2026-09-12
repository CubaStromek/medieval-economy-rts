# Nezávislá kontrola: walk_axe / W

2026-09-10 · agent animation_services · skutečných 25 raw PNG 0–24.
Prohlédnut [celý kontaktový arch](contact.png) a samostatné raw 01, 08,
12, 24 v původních 256 × 256 px. Posuzovaná smyčka: **1–24**; raw 00
je uchovaný vstup, nikoli zde ověřený runtime idle.

**Výsledek: základní vizuální a technická kontrola prošla.** Chůze na západ
je čitelná, jedna sekera zůstává ve vzdálenější pravé ruce a bližší levá
ruka je volná. Nevidím záměnu rukou, další končetinu, ztrátu nohy ani
zjevný rozpad nástroje. Sekera má viditelnou hlavu a navazující topůrko;
částečné překrytí vzdálené ruky tělem je v tomto pohledu očekávané.

| Oblast | Pozorování / měření |
|---|---|
| Směr a ruce | Celá sekvence drží západní směr. Bližší levá ruka se houpe bez předmětu; sekeru vede vzdálenější pravá ruka. Hrudník a ramena se během chůze lehce natáčejí, nejde o přepnutí směru. |
| Nohy | Jsou vidět obě nohy a střídání přední/zadní polohy. V překryvu se jedna krátce schovává za druhou; netvrdím tím zánik nohy. Sekvence obsahuje dvě zhruba dvanáctifázová opakování celého kroku. |
| Registrace | Žádný posun plátna nebo automatická korekce. V horní kontrolní oblasti `y<84` je levá alfa mez hlavy x=112–113; horní mez y=48–52. Změna je malý bob, bez postupného odplouvání postavy. Oblast není měřením anatomického pivotu. |
| Obal | Alfa ≥1: levá mez 82–93, horní 48–52, pravá 158–168, dolní 207–218 px. Pohybující se ruce, sekera a boty mění obal; podle něj se nemá přepočítávat kotva ani měřítko. Pravá/dolní hranice jsou výlučné. |
| Alfa | Všech 25 raw fází obsahuje průhledné i viditelné pixely. Nula viditelných pixelů na hraně plátna. Bez varování helperu. |
| Smyčka 24→1 | Póza pokračuje do další fáze kroku. Průměrná změna RGB po složení na #505550 je 3,373784 proti mediánu vnitřních přechodů 3,177119; přechod není výrazný číselný extrém. Metrika není samostatným důkazem přirozenosti pohybu. |
| Duplikáty | Žádné přesně shodné RGBA dvojice; zdrojové fáze se nemají bez explicitního výběru krátit. |

Důkazy: [statistics.json](statistics.json),
[nezávislá měření a přechod 24→1](independent-loop-check.json).
Helper ověřil, že zdrojové soubory zůstaly nezměněné. API data ani runtime
balík nebyly při této kontrole upravovány.

**Neověřeno:** nativní vykreslení W při 33 world px, rychlost vůči skutečnému
pohybu, kontakt s terénem, přechody do ostatních směrů/práce/nákladu a přijetí
uživatelem. Tento posudek připouští klip k dalšímu balení a společné kontrole;
neoznačuje celou sadu ani běžnou herní integraci za schválenou.
