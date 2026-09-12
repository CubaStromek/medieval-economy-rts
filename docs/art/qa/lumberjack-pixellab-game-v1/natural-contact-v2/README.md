# Běžná hra — pracovní postoj, první opakování

2026-09-10. Tento diagnostický běh zachovává skutečné výsledky včetně dvou
nedořešených kontrol; není závěrečným čistým během.

Produkční menu → Osídlené údolí → původní worker 19, hut 2, tree 13.
Přirozený pracovní cyklus znovu dokončil těžbu, převzetí jedné klády a její
doručení v ticku 94. Strom 5 → 4 a výstup chaty 0 → 1; simulace ani její
souřadnice nebyly přepsány. Hudba N/A, Master/SFX beze změny.

Prohlédnuty byly skutečné detailní PNG začátku, středu a konce sekání,
převzetí klády a prvního zpátečního kroku. Nový stabilní postoj je napravo od
kmene a úder W nyní míří do dolní části správného kmene, místo aby postava
stála v jeho středu a sekala mimo něj. Viz [střed sekání](05-chop-middle-2_4x.png)
a [začátek](04-chop-start-2_4x.png). Sousední střecha stále zakrývá chodidla;
tento konkrétní záběr nedokládá jejich kontakt s terénem.

Při práci zůstává logická zem `(3, 13)`. Skutečná výtvarná a stínová kontaktní
zem je `(3.25812888, 12.99862003)`, projektovaná kotva
`(150.32514954, 539.94482422)` světových px. Data jsou v [reportu](report.json),
včetně skutečných hashů sedmi skriptů při startu a nezměněného manifestu
`7aa01262a49e4e682f87c9a8445f6fc79ec1fd6f18154f34d8a11a320a43fa64`.
Zaostření kamery už používá reset smoothingu a metadata se čtou po renderu;
`foot_screen` je v souřadnicích viewportu před roztažením okna.

**Zbývající problémy tohoto běhu:**

- [Nativní log](run.log) jednou obsahuje `Invalid polygon data, triangulation
  failed` v produkčním `_paint_dynamic_row`. Ekonomický úspěch tuto chybu
  nepokrývá. Následující kontrola musí prokázat její odstranění.
- Požadavek na 60 skutečných burst snímků selhal: uložilo se **25**, od
  simulačního času 0.9199 do 3.7626 s. Komprese celého PNG za běhu snížila
  četnost pozorování. Žádný snímek se nedoplňoval ani neduplikoval. Report
  správně hlásí jednu chybu počtu; pracovní cyklus a 17 fázových PNG vznikly.
  Runner pro další běh drží skutečné obrazy v paměti a ukládá je až po cyklu.

Nativní prostředí: Godot 4.7.2, OpenGL 4.1/Metal Compatibility, Apple M4,
PNG 1280 × 800. Přirozený úsvit, stávající mlha, zoomy 1× a 2.4×.
Výsledek jiných směrů, svahů, nocí a klikání patří do oddělené sady.
