# Truhlář — živý odpočinek u pily

Datum: 2026-09-13. ID `carpenter`, pila v2. Rozsah: doplnění klidové animace
existujícího obyvatele. Použit `pixellab-godot-unit-pipeline`, projektový
[postup objektů](../object-implementation-workflow.md) a
[integrační šablona](../object-integration-template.md).
Stav: zapojeno a ověřeno v běžné hře 2026-09-13.

## Zadání a vlastní podklady

Uživatel navázal dotazem na idle animaci. Předchozí
[oprava usazení](carpenter-sawmill-spatial-v1-integration.md) upravila stíny,
osvětlení a pracovní výšku; odpočinku zůstávalo pouze rozhlížení.
Nově doplněno jemné dýchání a přirozený pohyb ramen při stejném opřeném postoji.

Vlastní [odpočinková identita, původ a měření](carpenter-rest-v1.md) zůstávají
autoritativní. Všechny původní PNG, jejich alfy a otočení hlavy jsou zachované.
Nevyráběla se nová grafika ani externí animační sada; jde o řízený pohyb
existujícího obrázku v rendereru.

## Geometrie a pohyb

Autoritativní hodnoty jsou v `game/art/buildings/sawmill/v2/manifest.json`
→ `life.rest_sprite.idle_motion`.

| Kontrakt | Hodnota |
|---|---|
| Canvas / výška | Původních 256²; 165 source px → 33 world px |
| Cyklus dechu | 4.8 s podle existujícího simulačního času; fáze odlišená ID obyvatele |
| Horní tělo | Do source y108 posun jako jeden celek: hlava, krk, ramena i složené ruce |
| Maximální posun | Source(+0.6,−1.5), tedy(+0.12,−0.30)world px |
| Přechod | Přes zástěru source y108–142 plynulý prostorový útlum posunu |
| Pevná část | Od source y142 celá dolní zástěra, nohy a boty bez posunu |
| Kontakt a stín | Původní kotevní bod, `rest_rect`, sokl a kontaktní elipsy beze změny |

Tři pásy používají stejné původní UV a přesně navazující vrcholy. Tělo se
celé nenafukuje, neposkakuje ani neotáčí kolem bot. Dech má hladký kosinový
náběh i výdech. Volba a prolnutí existujících pohledů hlavy probíhají před
posunem, takže krk zůstává spojený s trupem.

## Stavy, čtenář a kompatibilita

`BuildingWorkerIdle` vzorkuje pohyb bez změny simulace. `ProductionBuildingLife`
jej používá pouze při skutečném známém odpočinku obyvatele. Osobní pauza
v práci dovoluje domácí idle; globální pauza zastaví čas, dech i rozhlížení.
Při začátku práce, odchodu a spánku idle zmizí podle stávajících pravidel.

`BuildingWorkerAppearance` přijímá volitelnou geometrii pásů a zachovává
lokální světelný přechod podle původních UV. Kontaktní stíny se kreslí
samostatně bez deformace. Klikání převádí bod přes přesnou inverzi stejného
pohybu na masku aktuálního pohledu hlavy; nevzniká nová obdélníková hit plocha.

Chybějící `idle_motion` ponechá původní kresbu. Neplatné hodnoty, překlápějící
se pásy nebo pohyb zasahující měřený bod chodidla se bezpečně odmítnou.
Půdorys, hloubkové řazení, postoj při práci, zásoby, kamera a save formát se
nemění. Nový pohyb nepotřebuje ukládat animační historii a navazuje na
stávající uložený čas a ID.

## Ověření a předání

[QA záznam](../qa/carpenter-idle-v1/README.md) vede přesné testy a otisky.
Kontroly pokrývají inverzní klikání v pohybující se části, opakování dechu,
skryté stavy, neměnnost hry a pixelově stálé nohy/stíny. Nativní cesta
menu → Relief zachycuje 12 s skutečného odpočinku při 1×, skutečnou pauzu a
následnou výrobu po skutečné dodávce klády. Umělé fáze pro kontrolu pixelů
jsou vedeny odděleně od normální hry.

Finální výsledek: 859/859 bezokenních testů a 49/49 nativních kontrol.
Záznam má 181 snímků skutečného idle, všechny tři pohledy hlavy a pevnou
registraci nohou. Pauza zachovala přesně stejné pixely postavy. Skutečná
dodávka klády následně spustila práci v ticku 236. Video zachovává naměřené
časování; nový idle nebyl v této revizi samostatně ověřován po save/load.

Nové směry chůze, jiná klidová gesta a samostatný export hry nejsou součástí
této dodávky. Výtvarné přijetí nového idle uživatelem zatím není zaznamenáno.
