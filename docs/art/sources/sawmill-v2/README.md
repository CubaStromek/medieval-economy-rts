# Pila v2 — vlastní zdroje a původ, 2026-09-12

Uživatel povolil přepracování po společném srovnání pily v1 a dřevorubecké
chaty: „ano klidně přepracuj porad iterujeme“. Výsledný styl stále patří
k pracovnímu směru v0.2; tento souhlas není schválením etalonu celého katalogu.

Čtyři obrazové kroky byly vytvořeny vestavěným `image_gen.imagegen`.
Žádné KaM pixely nebyly vstupem ani součástí výsledku. KaM sloužilo
v předchozí [studii chování](../../references/sawmill-kam-study-2026-09-12.md)
jen k pozorování role zásob a práce. Přímá vlastní obrazová reference je
`game/art/buildings/lumber_hut/v1/finished.png`.

| Krok | Přesný prompt a soubor | Výsledek |
| --- | --- | --- |
| 1 | `prompt-01.txt`, `concept-01.png` | Nová dlouhá střecha, předolevý nadhled, hrubší šindel a kámen, prázdné pracovní zóny. Vstupy: vlastní produkční chata a skutečný `qa/sawmill-v2/ground-guide.png`. Malé dveře a falešná šachovnice nebyly přijaty pro produkci. |
| 2 | `prompt-02.txt`, `concept-02-key.png` | Editace kroku1: vyšší střecha a místnost, čistý barevný technický podklad. Dveře stále nízké vůči33world člověku. |
| 3 | `prompt-03.txt`, `concept-03-key.png` | Editace kroku2: další výška dveří při zachování zemních kontaktů. Výška vyhověla, šířka ne. |
| 4 | `prompt-04.txt`, `concept-04-key.png` | Editace kroku3: širší dveře. Vybraný finální1254² RGB master. |

Vybraný master SHA256:
`3ff20d909aaa9dd05788c4545a657d2984bb03a8a4ffd7118cb80da506d12115`.
Skutečně použitý guide SHA256:
`430d05965aee4c3bce7e33e866c35caa66301d2802a7094cca610ee35eef9136`.
`ground-guide-minimal.*` je nepoužitý paralelní technický návrh.
`ground-guide-rebuilt.png` je pozdější reprodukce návodu; nezaměňovat jej
za přesný vstup generátoru.

`export-base.cjs` pouze odstraní technický podklad se zachováním hran,
vytvoří skutečnou alfu a jednotně zmenší obraz na800². Nedeformuje budovu,
nemění její půdorys a nekreslí nové umělecké detaily. Přesné měřené kontakty,
registrace, práh, koeficienty, výsledné otisky a omezení filtračního lemu jsou
v [geometrii04](../../qa/sawmill-v2/concept-04-geometry.json),
[base exportu](../../qa/sawmill-v2/base-export.json) a
[nativním ověření podkladu](../../qa/sawmill-v2/base-native/README.md).

`export-life-work.cjs` nastavuje nově změřené otvory a kontakty.
Odpočinková postava, její dva pohledy a šest pracovních fází jsou přesné
vlastní produkční PNG v1. Přebírá se postava, nikoli staré kotvy domu.
Pracovní kláda je vlastní v1 rekvizita, technicky otočená o15° podle nové
stolice. Neměnná výška těla je33world; ruční pila není součástí domu.
Zásoby a přední masky mají samostatný export a geometrický záznam.

[Návrhový brief](../../briefs/sawmill-v2.md) ·
[integrační záznam](../../briefs/sawmill-v2-integration.md) ·
[skutečné QA výsledky](../../qa/sawmill-v2/README.md).
