# Vizuální kontrola osmi rotací PixelLab

Datum: **2026-09-10**. Nezávislá kontrola: agent `walk_preview`.
Skutečně prohlédnuto: `rotations-review.png`, samostatný
`images/frame_04.png` a vlastní původní vstup
`docs/art/animation-references/lumberjack-without-log/S.png`.

Tento záznam hodnotí statické vstupy následné animace. Neprokazuje
plynulost chůze, správné tělesné měřítko ve hře ani přijetí uživatelem.
Přesné technické otisky a parametry generování musí doplnit produkční
záznam; samotná vizuální prohlídka je neměří.

| Soubor | Vizuálně potvrzený směr | Vybavení a ruce |
|---|---|---|
| `images/frame_00.png` | S | Sekera na obrazové levé straně odpovídá anatomické pravé ruce; levá volná |
| `images/frame_01.png` | SE | Viditelná pravá ruka drží sekeru; levá volná |
| `images/frame_02.png` | E | Pravá blízká ruka drží vodorovné topůrko; sekera před postavou |
| `images/frame_03.png` | NE | Pravá ruka a sekera viditelné na obrazové pravé straně |
| `images/frame_04.png` | N | **Sekera ani topůrko nejsou viditelné; obě ruce vypadají prázdné. Správnou přítomnost/úchop nelze potvrdit.** |
| `images/frame_05.png` | NW | Za pravou stranou těla je krátký dřevěný úsek topůrka, hlava sekery zakrytá. Možná přirozená okluze; nutná kontrola celé animace |
| `images/frame_06.png` | W | Hlava sekery před tělem, pravá nosná ruka převážně zakrytá tělem. Viditelná levá ruka visí volně; jasné přehození ruky nebylo nalezeno |
| `images/frame_07.png` | SW | Sekera na vzdálenější anatomické pravé straně, levá bližší ruka volná |

Rustikální postava, rezavá čepice, olivová tunika, světlé vyhrnuté rukávy,
hnědá přední zástěra a boty jsou mezi směry rozpoznatelně konzistentní.
Zadní směry nezobrazují přední zástěru na zádech. Vyvýšený pohled zůstává
čitelný; kontrola nepřiřazuje přesný numerický úhel kamery.

Počet viditelných rukou/nástrojů v ostatních směrech nevykazuje z přehledu
jasné zdvojení. Mění se poloha nástroje a končetin, proto tento arch není
důkazem přesné stejné fáze kroku nebo rigidní rotace postavy.

**Závěr pro pilot:** S je použitelný vstup pro zkoušku chůze. Soubor N má
konkrétní nevyřešenou vadu vybavení; nelze ji obecně omluvit okluzí bez
dalšího důkazu. V N animaci zvlášť ověřit jednu sekeru, stálý pravý úchop
a návaznost jejího zobrazení. U NW a W zvlášť ověřit, že zakrytí nástroje
přirozeně navazuje v celém cyklu. Celá sada se tímto neschvaluje jako
hotová produkční grafika.
