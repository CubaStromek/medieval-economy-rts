# Nezávislá kontrola: walk_log / W

2026-09-10 · agent animation_services. Prohlédnut [celý arch](contact.png)
raw 0–16 a samostatné raw 00, 01, 05, 09, 13, 16 v původních 256 × 256 px.
Posuzovaná smyčka je **1–16**; raw 00 zůstává zdrojovou referencí.

**PASS pro základní chůzi a konzistenci vybavení; přesný kontakt pravého
ramene s kládou zůstává zakrytý a neověřený.** Kláda je vysoko za hlavou
na vzdálené pravé straně; horní podpůrná ruka je čitelná, ale v čistém
profilu nelze spolehlivě vidět její nosný kontakt s ramenem. Tato vysoká
poloha je už ve vstupním raw 00, nevzniká teprve přeskokem během animace.

| Oblast | Pozorování / měření |
|---|---|
| Počet cyklů | **Jeden celý dvojkrok v 16 fázích**: nohy si v první a druhé polovině vystřídají přední/zadní polohu a na konci se vracejí. Pro zadaných 0,8 s na dvojkrok doporučuji **20 fps** (`16/20=0,8`). Hodnota 10 fps by prodloužila tento jeden cyklus na 1,6 s. |
| Směr / nohy | Celá sekvence drží západní profil. Obě nohy jsou během cyklu čitelné, v přechodech se překrývají; nejde o opakování jediné nohy. |
| Volná ruka | Bližší anatomická levá ruka visí a houpe se bez předmětu; nepozoruji její přechod k držení klády nebo sekery. |
| Kláda / pravá ruka | Jeden nepřerušovaný podélný kus dřeva; prsty vzdálenější pravé ruky jej drží u předního konce. Poloha a tvar zůstávají během chůze přibližně stabilní. Přesné dosednutí na rameno je výše uvedená otevřená kontrola. |
| Sekera na levém boku | Jedna zavěšená sekera u bližšího levého boku: čepel u opasku, topůrko směrem dolů. Levá dlaň ji nenese; nevidím druhou sekeru nebo přenos mezi rukama. |
| Alfa / obal | Všech 17 raw fází má viditelné i průhledné pixely, nula viditelných pixelů na hraně plátna. Pro 1–16 je horní mez 46–51, pravá mez klády stále 195 px; celé alfa meze v [měření](independent-loop-check.json). Podle vybavení se nemá přepočítávat kotva nebo velikost. |
| Smyčka 16→1 | Póza pokračuje do další fáze. Průměrná změna RGB po složení na #505550 činí 2,890569 proti mediánu vnitřních přechodů 2,704229; nejde o výrazný číselný extrém. Není to samostatné schválení přirozenosti chůze. |

Důkazy: [statistics.json](statistics.json), [nezávislá kontrola cyklu](independent-loop-check.json).
Žádné přesné RGBA duplikáty; helper ověřil nezměněné raw soubory.
Při této kontrole nebyla změněna fps, API data, PNG, jejich pořadí ani
runtime balík. Nativní W v herním měřítku, skutečný terén, předání nákladu
a uživatelské výtvarné přijetí nejsou tímto posudkem doložené.
