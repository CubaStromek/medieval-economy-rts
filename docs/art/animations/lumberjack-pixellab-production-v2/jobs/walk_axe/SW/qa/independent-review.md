# Nezávislá kontrola chůze SW · PixMiniMax 24

**2026-09-10 · PASS pro pokračování do kompletace.** Doporučená pohybová
sekvence je **01–24**, při zachování všech 25 původních PNG. Anatomie, obě
střídající se nohy, sekera a skutečná alfa jsou použitelné. Kadenci je třeba
sladit s ostatními směry; počet 24 snímků neznamená tři dvojkroky jako u S.

Prohlédnuto všech 25 skutečných obrázků na [kontaktním archu](contact.png),
navíc jednotlivě 06, 12 a 24. Měření:
[statistics.json](statistics.json) a
[loop-selection-analysis.json](loop-selection-analysis.json).

- Obě nohy střídají zřetelně odlišné přední a zadní fáze; kolem 06–08 je
  vpředu jiná noha než v počáteční/vracející se fázi kolem 00/12–13/24.
  Při průchodu se nohy částečně překrývají, ale nevzniká jednostranný krok.
- Viditelně jsou zde přibližně **dva celé dvojkroky**, cyklus okolo 12–13
  fází. Průměrný RGB rozdíl při odstupu 12 snímků je 1,828934, při odstupu
  8 snímků 5,676392; to podporuje prohlédnuté delší opakování. Nejde o
  přesně totožné kopie jednotlivých obrázků.
- Přechod **24 → 01** má RGB rozdíl po složení na šedý podklad 2,158854;
  běžné sousední přechody mají rozsah 0,942846–3,691294. Hranice vybrané
  smyčky proto nepředstavuje neobvykle velký skok. Reference 00 zůstává
  mimo doporučený pohybový rozsah.
- Sekera zůstává v anatomické pravé ruce na vzdálenější straně postavy,
  vystrčená šikmo vpřed a dolů. Hlava i topůrko jsou čitelné v celém sledu,
  nástroj se neduplikuje ani nepřehazuje. Bližší levá ruka je prázdná.
- Postava zůstává otočená SW, s konzistentní čepicí, vousy, tunikou,
  rukávy, páskem, přední zástěrou a botami. Kresba drobných detailů se
  mění, avšak nevidím zásadní záměnu těla nebo rozpad nástroje.
- Všechny snímky mají 256 × 256 px, obsah i skutečnou průhlednost, alfa
  hodnoty 0/255 a nulový počet nenulových alfa pixelů na hraně. Nejsou
  oříznuté boty ani sekera. Čepice pravidelně kolísá mezi y=46 a y=52;
  postava nekumuluje posun napříč canvasem. Meze nástroje a živých nohou
  nejsou považovány za pevné registrační kotvy.

**Praktické omezení:** při společném fps nebude frekvence tohoto kroku
stejná jako u S/E s přibližně osmi fázemi na dvojkrok. Při kompletaci je
nutné zkontrolovat tempo a změny směru a případně explicitně nastavit
tempo podle směru či doložený výběr fází. Novou generaci kvůli chybějící
noze, sekeře nebo alfě tento výsledek nevyžaduje.

Původní soubory nebyly změněny. Kontakt s herním terénem, návaznost na
rychlost jednotky a uživatelské přijetí touto izolovanou kontrolou nevznikají.
