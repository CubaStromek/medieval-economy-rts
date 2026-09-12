# Diagnostika stínového polygonu

2026-09-10. Nový nativní průchod produkční hrou, stejný přirozený pracovní
cyklus, bez ukládání snímků. Ekonomický cyklus doběhl do ticku 94, ale test
správně selhal při konkrétním chybném polygonu odesílaném produkčním rendererem.
Tento běh je negativní důkaz fungování nové geometrické kontroly.

[Report](report.json) zachytil v `invalid_shadow_polygons[0]` tick 87,
řádek 17, `worker` 24 (jiná osoba než sledovaný dřevorubec 19), ground
`(8, 17.562210083)` a projektovanou kotvu `(340, 722.488403)`.
Odříznutý trojúhelník má body `(343.510131836, 720)`, `(343.394165039, 720)`,
`(343.430175781, 719.996032715)`. Jeho výška je jen 0.00397 obrazového px.
[Nativní log](run.log) zároveň obsahuje původní chybu triangulace.
Zdrojové skripty a hash skutečně načteného balíku jsou v reportu.

Žádný polygon, postava ani simulační stav nebyl diagnostikou měněn.
Samostatná oprava produkčního ořezu stínů a nový čistý běh následují.
