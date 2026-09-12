# Dřevorubec — PixelLab chůze v1: dílčí zkouška

Datum: **2026-09-10**. Dodáno **osm statických směrů a první animace S
s devíti skutečnými snímky**. Ostatních sedm směrů chůze zatím není
vygenerovaných. Jižní krok se neuzavírá do plynulé smyčky a zadní statický
pohled N nemá viditelnou sekeru. Nejde o hotovou osmisměrnou chůzi ani
schválenou produkční grafiku.

- [Přehrávač skutečného S pilotu](preview.html) — původní PNG vložená beze změn;
  pauza/krokování, 5/10 fps, detail i malý náhled a kontrolní pozadí.
- [GIF jižního pilotu](gifs/S-10fps.gif) — devět snímků při 10 fps, detail
  i malý náhled. GIF má sloučené pozadí a omezenou paletu; zdrojová PNG
  zůstávají autoritou.
- [Všechny snímky S včetně vstupu](jobs/S/qa/all-returned-frames-contact-sheet.png)
  a [větší GIF 5 fps](jobs/S/qa/all-returned-frames-5fps.gif).
- [Osm statických rotací](rotations/rotations-review.png),
  [jejich vizuální kontrola](rotations/visual-qa.md).
- [QA této dílčí dodávky](../../qa/lumberjack-pixellab-walk-v1/README.md),
  [integrační záznam](../../briefs/lumberjack-pixellab-walk-v1-integration.md),
  [automatická měření](qa.json).

## Původ a skutečný rozsah

Uživatel zadal PixelLab API a osmisměrnou chůzi. Upřesnil **jeden původní
pohled S → osm směrů z PixelLab → animace**, aby se nepřenášely nesrovnalosti
osmi dřívějších referencí. Jediný vlastní výtvarný master je
[původní pohled S](../../animation-references/lumberjack-without-log/S.png).
Jeho technický vstup je uložen v `inputs/S-reference-128.png`; původ,
rozměry a převod dokládá `inputs/provenance.json`.

Zachovaná úplná zadání, vstupy a odpovědi API: `rotations/request.json`,
`rotations/result.json`, `jobs/S/request.json`, `jobs/S/result.json` a
jejich `provenance.json`. Výstupy PixelLabu nebyly následně opravovány ani
překreslovány. Osm vlastních starších směrů nebylo použito jako osm vstupů.
Identitu a původní kontrakty určují [zadání postavy](../../briefs/lumberjack-v1.md)
a [zadání chůze bez klády](../../briefs/lumberjack-walk-without-log-kam-v2.md).

Doložené nástroje: `/generate-8-rotations-v3` a `/animate-with-text-v3`.
S úloha požadovala `frame_count: 8`, ale dokončená odpověď obsahuje **9
odlišných RGBA obrázků**. Devátý není duplikát prvního. První se od
odeslaného vstupu liší pouze 94 pixely; výklad „znovu zpracovaný počáteční
snímek + osm generovaných“ je inference, nikoli potvrzený kontrakt tohoto
endpointu. Žádný snímek se nevyhazuje. [Měření](jobs/S/qa/frame-count-analysis.json).

Spotřeba podle [posledního ověření zůstatku](connection/final-check/balance.json):
**4 bezplatné generace, 36 ze 40 zbývá; USD 0**.

## Známé vady a další práce

S snímky střídají postavení nohou, zachovávají směr a sekeru v anatomické
pravé ruce. Začátek a konec však mají opačnou předsunutou nohu; chybí
návrat do původní fáze. Skok 08 → 00 není opraven. V dalších fázích se také
zesvětluje a mění čitelnost hlavy sekery. Při pohledu N není sekera ani
její topůrko viditelné, proto správné vybavení nelze potvrdit pouhým
předpokladem, že je zakryté.

Další uploady výstupů PixelLabu pro opravu N a navazující animace zastavila
**automatická schvalovací kontrola**: vyložila uživatelovu formulaci „jeden
obrázek“ jako omezení všech odesílaných obrázků, včetně odvozených výstupů
PixelLabu. Pokračování vyžaduje nové výslovné potvrzení tohoto opětovného
použití. Zde zachycená lokální kontrola nic dalšího do API neodeslala.

Hra, renderer, simulace, save a dosavadní atlasy nebyly změněné. Běžná
herní cesta, kontakt s terénem, řazení, mlha a uživatelské přijetí nejsou
ověřené. Plochá zelená v přehrávači není herní screenshot.

## Reprodukce náhledu a technické kontroly

[preview_pixellab_walk.py](../../../../tools/preview_pixellab_walk.py)
čte skutečné PNG, zachovává celé canvas a měří alfu, rozměry, počty,
SHA256, duplicity a přesnou RGBA shodu každé buňky atlasu. Nemění polohu
podle nejnižší boty. S tělo bylo v původním canvas změřeno od vrchu čepice
po nejnižší botu: 108 px. Jedna společná náhledová škála proto zobrazuje
tuto výšku jako 33 px; nejde o hotovou herní registraci.

```sh
python3 tools/preview_pixellab_walk.py \
  docs/art/animations/lumberjack-pixellab-walk-v1 \
  --input-layout jobs --directions S --expected-frames 8 \
  --body-height-source 108 \
  --review-note 'Pouze S; devět skutečných snímků, neuzavřený krok. Ostatních sedm směrů chůze chybí.'
```

Samostatné výstupy `atlas.png`, `contact-sheet.png`, `qa.json`,
`qa-summary.md`, `preview.html` a `gifs/` obsahují **jen dodanou S animaci**.
Statické rotace jsou odděleně v `rotations/`. Každý GIF zobrazuje všechny
skutečné fáze s jejich indexem; nepřidává chybějící kroky ani přechody.
5/10 fps jsou zkušební rychlosti, ne schválené tempo herní chůze.
