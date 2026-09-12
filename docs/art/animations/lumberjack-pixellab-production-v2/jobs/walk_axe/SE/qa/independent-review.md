# Nezávislá kontrola chůze SE · PixMiniMax 24

**2026-09-10 · PASS pro pokračování do kompletace.** Doporučená pohybová
sekvence je **01–24**, při zachování všech 25 původních PNG. Nebyl zjištěn
chybějící krok, ztracená sekera ani neplatná alfa. Před sjednocením celé sady
je nutné doladit tempo: tento klip nemá stejný počet dvojkroků jako S/24.

Prohlédnuto všech 25 obrázků na [kontaktním archu](contact.png), navíc
samostatně 06, 12 a 24. Doklady:
[alfa, meze a otisky](statistics.json),
[hranice smyčky a opakování fází](loop-selection-analysis.json).

- Blízká anatomická pravá noha je vpředu v počáteční fázi a kolem 12/24;
  v okolí 05–06/18–19 je vzadu, zatímco druhá noha jde dopředu. Mezi nimi
  jsou zdvih a průchozí fáze. Sled tedy obsahuje obě nohy a celé dvojkroky.
- Přibližně **dva dvojkroky za 24 generovaných snímků**, s cyklem okolo
  12–13 fází. Snímky 12 a 13 mají téměř shodnou pózu i obal; vzniká krátké
  podržení uprostřed delšího sledu. Není správné převzít ze S tvrzení
  „tři osmifázové cykly“ jen podle shodného počtu souborů.
- Přechod **24 → 01** má RGB rozdíl na šedém podkladu 1,875738, zatímco
  sousední přechody mají rozsah 0,285182–3,605911. Není zde výjimečný skok
  na hranici vybrané smyčky. Krátké podržení uvnitř sledu ale není tímto
  průměrem odstraněno.
- Sekera zůstává v pravé ruce, má jednu hlavu a jedno topůrko. Drží se
  nízko, mírně před nohama podle reference; nepřehazuje se do druhé ruky.
  Levá ruka je prázdná a během kroku se částečně skrývá za tělem.
- Čepice, vousy, tunika, světlé rukávy, přední zástěra a boty drží identitu.
  Nevidím zásadní deformaci končetiny či otočení mimo SE. Jemná kresba se
  mění a nelze ji označit za dokonale pevnou texturu.
- Všech 25 snímků má skutečnou alfu 0/255, viditelný obsah i průhledné okolí,
  žádný nenulový alfa pixel na hraně a žádné přesné RGBA duplikáty. Čepice
  pravidelně kolísá přibližně mezi y=47 a y=52; nejde o kumulativní svislý
  odchod z canvasu. Živý obal nohou nebyl použit jako registrační kotva.

**Praktické omezení:** při stejném fps bude tento SE kráčet přibližně
pomaleji než osmifázové cykly S/E. Při kompletaci zkontrolovat fázi změny
směru, frekvenci kroku a krátké podržení 12–13. Může být nutné explicitní
nastavení tempa podle směru nebo doložený výběr fází. Tento review nic
nestříhal ani nepřekresloval a nedoporučuje novou placenou generaci kvůli
anatomii či sekeře.

Herní kontakt se zemí, vazba na rychlost jednotky a přijetí uživatelem
zůstávají neověřené. Samotná kontrola izolovaných PNG je nenahrazuje.
