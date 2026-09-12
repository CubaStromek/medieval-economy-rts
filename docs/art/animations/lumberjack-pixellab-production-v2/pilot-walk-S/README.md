# Skutečný pilot · chůze se sekerou na jih

2026-09-10. **1 z 24 kombinací klipu a směru**, nikoli kompletní produkční sada.

[Spustit HTML náhled](preview/index.html) · [APNG](preview/walk_axe/S.apng.png) ·
[manifest](package/manifest.json) · [nativní QA](../../../qa/lumberjack-pixellab-v2-S-pilot/README.md).

Packer zachoval původní RGBA. Z 25 vrácených raw snímků je podle
výslovného zadání vybráno 1–24. Vstupní raw 00 zůstává beze změny
v původní složce `../jobs/walk_axe/S/images`; není součástí runtime smyčky.
`jobs` je symlink na `../jobs`, nikoli druhá kopie generací.

Předběžná společná kotva `(128,205)`, tělo `163 → 33 px`, 12 fps,
dvousekundová smyčka. Žádné posouvání nebo ořez jednotlivých fází.
`rest_frame=0` odkazuje na raw 1. Parametry a autorita:
[scope.json](scope.json), [selection.json](selection.json).

Balík je přesně zkopírován do `game/art/units/lumberjack-pixellab-v2/`,
kde jej načítá samostatná scéna `res://tools/preview_pixellab_lumberjack.tscn`.
Hlavní hra jej zatím nepoužívá. Budoucí kompletní sada runtime kopii nahradí;
tato oddělená složka a její QA uchovávají přesnou verzi pilotu.
