# Připravená oprava jižní chůze — loop v2

Datum: **2026-09-10**. Stav: **připravené lokálně, neodeslané**.

Automatická kontrola schvalování zablokovala další odeslání obrázků do
PixelLab. Před jakoukoli následující generací je potřeba výslovný souhlas
uživatele s tímto odesláním; týká se také opětovného použití vlastních
výstupů PixelLab jako vstupů. Tento plán ani dřívější úspěšné požadavky
nejsou náhradou tohoto souhlasu. Žádný požadavek popsaný níže nebyl odeslán.

## Konkrétní jeden požadavek

Cílem je úplný pravý a levý krok s návratem do stejné fáze, navazující na
dosavadní [jižní pilot](jobs/S/provenance.json). Původní devítisnímkový
výsledek zůstane zachovaný. Identitu, kameru a měřítko určuje
[stávající implementační záznam](../../briefs/lumberjack-pixellab-walk-v1-integration.md).

| Parametr | Připravená hodnota |
|---|---|
| Cíl | `POST https://api.pixellab.ai/v2/animate-with-text-v3` |
| `first_frame` | Celý nezměněný RGBA soubor [direction-inputs/S.png](direction-inputs/S.png), 128 × 128 px |
| `last_frame` | Tentýž PNG se stejnými bytes jako `first_frame` |
| SHA256 vstupního souboru | `d1284f8474d970cd06fa71bf914b007d3c3b35b31987065bc978c7f877c7ea56` |
| `action` | Přesný obsah [prompts/walk-S-loop-v2.txt](prompts/walk-S-loop-v2.txt) |
| `frame_count` | `16` |
| `seed` | `20260911`, stejně jako první jižní pokus |
| `no_background` | `true` |
| `enhance_prompt` | `false`; bez dodatečné generace rozšířeného promptu |
| `drift_threshold` | Vynechat; výchozí chování služby |
| `loop` | Neposílat; schéma takový parametr nemá |
| Archiv požadavku a výsledků | Nová složka `jobs/S-loop-v2/`; žádné přepsání `jobs/S/` |

Vstup byl prohlédnut: už zachycuje rozkročenou postavu v kroku, takže
není potřeba lokálně vytvářet novou výchozí pózu. Koncový snímek je vodítko
interpolace; shodné vstupní obrázky nejsou zárukou stejného výstupního
konce ani kvalitní smyčky. Více snímků poskytuje prostor pro celý cyklus,
nikoli důkaz jeho správnosti.

Odeslat pouze tento jeden nový jižní test až po uvedeném souhlasu.
Předem ověřit zůstatek a omezení v [budget.json](budget.json); režim zůstává
`free_only` bez nákupu nebo navýšení rozpočtu. Veřejná dokumentace pro
128 × 128 / 16 snímků uvádí 4 generace; tuto hodnotu používat jako
rezervu (`--reserve-generations 4`), skutečnou spotřebu zapsat podle odpovědi a zůstatku.
Při nejasné odpovědi automaticky neopakovat placený/generační POST;
nejprve zjistit stav známé úlohy.

## Co skutečně říká API dokumentace

Ověřeno proti veřejnému
[OpenAPI schématu](https://api.pixellab.ai/v2/openapi.json), místní kopie
`/private/tmp/pixellab-openapi-20260910.json`:

- `AnimateWithTextV3Request` podporuje `last_frame` jako volitelnou cílovou
  pózu. `frame_count` je sudé číslo 4–16. Při 128 × 128 × 16 = 262 144
  splní tento požadavek rozpočet nejvýše 524 288 pixelů.
- Přímý `/animate-with-text-v3` nemá `loop` ani `keep_first_frame` a jeho
  schéma zakazuje další parametry (`additionalProperties: false`).
- Příbuzný spravovaný endpoint `/characters/animations` má
  `keep_first_frame: true` jako výchozí volbu. Jeho dokumentace výslovně
  vysvětluje, že `frame_count=8` uloží 9 snímků včetně vstupní reference;
  `false` uloží pouze 8 nových snímků. **To je vysvětlující analogie pro
  našich 9 vrácených snímků, nikoli stoprocentní kontrakt přímého endpointu.**
- Proto se počet vrácených snímků musí změřit. Při požadavku na 16 snímků
  nelze natvrdo předpokládat přesně 16 ani 17 a žádný snímek automaticky
  zahodit. Dosavadních 9 snímků je 9 odlišných RGBA obrazů podle
  [technické kontroly](jobs/S/qa/frame-count-analysis.json).

Další primární zdroje:
[interaktivní API dokumentace](https://api.pixellab.ai/v2/docs),
[parametry a generační náklady v3](https://www.pixellab.ai/docs/tools/animate-with-text-new).

## Kontrola po případném schváleném pokusu

1. Archivovat skutečně odeslané zadání, otisky obou vstupů, odpověď,
   identifikátor úlohy a všechny vrácené původní PNG.
2. Změřit skutečný počet, rozměry, alfu a shody RGBA; vyznačit případnou
   totožnou referenci a koncový duplikát. Teprve podle důkazu určit, zda
   má být v přehrávání vynechán skutečný duplicitní koncový snímek.
3. V pořadí snímků ověřit oporu na pravé noze, přenos váhy, oporu na levé
   noze a návrat do výchozí fáze. Požadovaný pohyb není zpětné přehrání
   půlkroku. Zkontrolovat návaznost posledního a prvního snímku.
4. Prohlédnout úchop anatomickou pravou rukou, jedinou sekeru, stálou
   identitu, rozměry těla, otáčení a pohyb chodidel při 5 a 10 fps i krokování.
   Nemaskovat chyby změnou měřítka nebo automatickým zarovnáním podle bot.
5. Zapsat skutečný výsledek do [QA](../../qa/lumberjack-pixellab-walk-v1/README.md).
   Výtvarná kontrola tohoto testu sama neznamená schválení celé sady ani
   ověření běžné herní cesty. Ostatní směry nejsou součástí tohoto jednoho
   připraveného požadavku.
