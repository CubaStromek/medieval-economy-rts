# Vlastní kláda a prkno pro pilu — 2026-09-12

Přesné zdroje, imagegen zadání a role vstupu: [stock-provenance.json](stock-provenance.json).
Vstupem byla pouze vlastní hotová pila jako reference materiálu/kamery;
KaM obrázek nebyl předán generátoru. Každý prop má vlastní uchovaný RGB raw
a technicky vyexportovaný RGBA master. Žádná kopie budovy se negenerovala.

Reprodukce: Node + Sharp, `export-stock.cjs`. Balík používá bundled Sharp
přes `NODE_PATH=/Users/openclaw/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules`.
Exporter ukládá do `game/art/buildings/sawmill/v1/operation/stock/`, původní
manifest pily nemění. Při jiném house SHA se zastaví, protože masky vycházejí
z přesných současných pixelů.

Produkční `[log.png,plank.png]`, sloty a původní překrývající architektura:
`geometry.json`. Props již jsou v měřítku house800², `source_to_house_scale=1`.
Pracovní in-process kláda může využít tento vlastní master jako zdroj, ale její
umístění/stav/počet nejsou součástí inventářového renderu.

[Zdrojová měření](stock-source-measurements.json) ·
[provedené asset QA](../../qa/sawmill-operation-v1/stock-art-qa.md) ·
[vodicí preflight](../../qa/sawmill-operation-v1/geometry-preflight.md).
