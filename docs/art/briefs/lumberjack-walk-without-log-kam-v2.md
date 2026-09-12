# Dřevorubec — dokončení chůze bez klády podle KaM

Datum: 2026-09-10. Uživatel kladně přijal obouruční kácení SE v3 a požádal navázat dokončením chůze bez klády. Současný rozsah je celá osmisměrná sada N, NE, E, SE, S, SW, W, NW; rozpracovaný SE pilot zůstává uložený.

Pohybovou předlohou je původní `uaWalk` + `uaWalkBooty`, osm fází na každý směr. Návrat s kládou není součástí této akce. Oblečení, tvář, čepice a malované materiály navazují na vlastní směrové reference a vlastní poslední kácení. Při chůzi je sekera vždy v anatomické pravé ruce a levá ruka volná. Obouruční úchop se týká kácení, nikoli chůze.

Zachovat stejnou kameru v každém směru, čitelné střídání opěrné nohy a protiběžnou práci paží; nevytvářet směry zrcadlením. Žádný zemní stín ani kláda. Průhlednost ověřit ze souboru, nevydávat bílé pozadí za alfa kanál.

Všechny původní referenční fáze používají společný počátek jednotky: 40 × 49 px, [19,41]. Přehledy jsou čisté skládání při zvětšení 8×, buňka 384 × 512 px, odsazení [32,40], výsledný původní počátek [184,368]. U chůze nezamykat nejnižší botu: musí zůstat pohyb chodidel i přirozený pohyb těla. Generativní překreslení je přibližné; přesná shoda kloubů nebo měřítka vyžaduje kontrolu skutečných výstupů.

Výstupy: verze `docs/art/animations/lumberjack-without-log-kam-v2/`, směrové archy, jednotlivé snímky, původ a zadání, společný náhled s KaM. Neprovádí se integrace do hry, změna rendereru ani gameplay. Schválení nové chůze a ověření ve hře dosud neproběhlo.
