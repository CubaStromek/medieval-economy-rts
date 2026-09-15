# Život výrobní budovy — společný vzor

Datum **2026-09-12**. Samostatná, pouze čtecí vrstva
`game/scripts/view/production_building_life.gd` zavádí opakovatelný stavový
kontrakt pro individuálně nakreslené výrobní domy. Původní dřevorubecká
chata a její renderer zůstávají beze změny. Výtvarné kotvy ani konkrétní
postava se mezi profesemi nekopírují.

## Pravdivé stavy

Pracovníka určuje `world.workplace_worker(building.id)` a povolání katalog.
Pouhé přidělení nestačí: domácí přítomnost vyžaduje
`worker.inside_building_id == building.id`. Nosič na návštěvě nerozsvítí
domácnost majitele. Cizí budova při zapnuté mlze končí ve stavu `known=false`
ještě před čtením pracovníka; její neutrální obraz není tvrzení o nepřítomnosti.

| Situace | Obraz |
|---|---|
| Pracovník mimo vlastní dům | Zavřené dveře a okno, bez postavy a domácího kouře |
| Den, doma a skutečně pracuje | Otevřené dveře; žádná odpočinková postava |
| Den, doma a odpočívá | Otevřené dveře a tmavé otevřené okno; vlastní klidová postava |
| Noc, skutečně doma | Zavřené dveře, teplé okno a jemný kouř z domácího ohniště |
| Noc, dosud na cestě | Bez světla a kouře |
| Rozestavěná budova | Bez této dokončené vrstvy |

Odpočinek vyžaduje skutečný idle stav nebo osobní/provozní pauzu doma,
prázdné ruce, žádné jídlo, odevzdávání nákladu, cestování nebo spánek.
Aktivní práci potvrzuje vlastní obsluha ve stavu `working/operate`, správné
`source_id`, povolená práce a kladné `process_remaining`. Samotné klády,
prkna, rozpracovaná dávka ani povolená budova nejsou důkazem práce.

Tesař po dokončení poslední dávky zůstává skutečně uvnitř a může přejít do
idle stavu; nový materiál znovu spustí práci a postava odpočinku zmizí.
Osobní či provozní pauza používá skutečnou cestu návratu. Nečinný pracovník
libovolně stojící venku se kvůli kresbě neteleportuje domů. Noční rozvrh
20:00–05:00 zachovává vlastněnou pilu jako místo spánku. Návštěva hostince
je jiná budova a její fyzické opuštění dál řídí simulace.

Zásoby mají samostatný renderer a čtou skutečné inventáře. Tento modul
zásoby nemění ani nečte. Globální pauza zmrazí čas, ne přítomnost; osobní
pauza umožní doma odpočívat. Rozhlížení používá uložené simulační tickování,
12sekundový klidný cyklus a 0,45sekundové přechody hlavy. Tělo, opření
a chodidla zůstávají registrované. Postava zastupuje skutečnou skrytou
jednotku a používá její ID pro výběr; nevytváří nového občana ani kolizi.

## Datový kontrakt pro integraci

`house` obsahuje `texture`, `rect`, `source_to_world` a slovník `life`
přenesený z manifestu konkrétní budovy. Souřadnice jsou vždy v původním
canvasu budovy; názvy povolání se odvozují z katalogu.

```json
{
  "life": {
    "door": [[0,0],[1,0],[1,1],[0,1]],
    "window": [[0,0],[1,0],[1,1],[0,1]],
    "chimney": [0,0],
    "rest_foot": [0,0],
    "wood_uv": [[0,0],[1,0],[1,1],[0,1]],
    "window_shutters": [],
    "door_base_open": false,
    "window_base_open": false,
    "rest_sprite": {
      "texture": "res://art/buildings/OBJECT/VERSION/life/resting.png",
      "body_height_px": 0,
      "ground_contact": [0,0],
      "look_textures": {
        "left": "res://art/buildings/OBJECT/VERSION/life/left.png",
        "right": "res://art/buildings/OBJECT/VERSION/life/right.png"
      }
    }
  }
}
```

Čísla výše jsou pouze popis polí, nikoli použitelná geometrie. `door`
a `window` vyznačují vnitřní otvor bez rámu, v pořadí levý horní, pravý horní,
pravý dolní, levý dolní bod. `wood_uv` vzorkuje vlastní dřevo v textuře domu.
`window_shutters` obsahují volitelné samostatné otevřené okenice. Výchozí
statická kresba má zavřené dveře i okno; otevření pouze mění příslušné
registrované otvory. Příznaky `*_base_open` podporují opačný základ,
avšak původní postranní otevřené okenice musí autor vyřešit samostatnou
registrovanou vrstvou, jinak zůstanou viditelné i vedle zavřeného otvoru.

Postava má samostatný canvas s reálnou alfou a měřenou tělesnou výškou,
nikoli měřítko odvozené od zbraně, pily či prázdného okraje. Renderer ji
kalibruje na 33 world px. Volitelné pohledy mají identické tělo a canvas;
přechody mění pouze rozdílné pixely a masky se pro ně uloží do cache.
Ověření, že se mění jen hlava, stále patří konkrétní dodávce a QA.

Všechny veřejné metody jsou **instanční**:
`presentation_for(world, building, house, tick_fraction)`,
`draw(canvas, life, house, ambient)`, `rest_rect(life)`,
`contains_point(life, world_point)`, `rest_pose_for(life)`.
Kreslit uvnitř stejného řádku domu, aby fungoval terén, stromy, mlha a výška.
Kouř a svit nejsou klikací; odpočinková postava má vlastní alfa hitmasku.

## Ověření

Samostatná sada `game/tests/production_building_life_tests.gd` ověřuje
normální výrobu z klády, návrat při pauze a v noci, skutečného majitele
vs. návštěvu, nezávislost inventářů, ukončení odpočinku při práci,
privátní stav před čtením obyvatele a neměnnost simulačních dat.
Nativní obrazové výsledky, konkrétní geometrie a měřítko patří QA pily.
Samotný průchod těchto stavových testů není výtvarná přejímka budovy.

K **2026-09-12** prošlo **12/12** případů včetně importovaných skutečných
tesařových PNG, 33px tělesného měřítka, alfa klikání a neměnného těla všech
tří pohledů. [Nativní kontrola pily](qa/sawmill-v1/visual/README.md)
dokládá 12 obrazových scénářů a 96 snímků klidového cyklu. Vzor je nyní
zapojen do pily; další budova musí dostat vlastní kresbu, kotvy a povolený
stavový kontrakt. Strážní a obslužné budovy s jiným rozvrhem tento domácí
režim automaticky nepřebírají.

## Zásoby a práce pily — doplnění 2026-09-12

[Provoz pily](briefs/sawmill-operation-v1-integration.md) nyní propojuje tento
domácí stav se samostatnou prezentací skutečných inventářů a rozpracované
dávky. `SawmillOperation` pozoruje každý vykonaný tick; pracovní cyklus
nepostupuje během vynechané práce. `SawmillOperationArt` registruje jednotlivé
kusy a pracovníka ve vrstvě domu. Rozpracovaný kus přetrvává při přerušení,
zatímco pracovník přejde podle skutečného domácího stavu k odpočinku nebo spánku.

Další výroby mohou použít stejné oddělení domácnosti, uloženého materiálu
a produktivní práce. Recept, kapacity, nástroj, fáze i kontakty musí určit
vlastní brief; šest póz a šest cyklů pily nejsou obecné hodnoty.
