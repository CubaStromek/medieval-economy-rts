# Dřevorubec PixelLab production v2 — napojení do hry

Datum: **2026-09-10**. **Historický audit před integrací.** Následující popis
původního rendereru zůstává záznamem výchozího stavu; aktuální napojení a jeho
ověření vlastní [herní integrační záznam](lumberjack-pixellab-game-v1-integration.md).
Nová výroba zahrnuje
osm směrů chůze se sekerou, obouručního kácení a chůze s kládou.

Vzhled a tělesné měřítko odkazují na [zadání postavy](lumberjack-v1.md)
a [zadání chůze](lumberjack-walk-without-log-kam-v2.md). Aktuální volba
uživatele pro novou produkci má přednost před historickými variantami
nošení v těchto záznamech. Nový manifest musí doložit skutečné vstupy,
aktuální nosnou pózu a naměřené kotvy; tento audit nevytváří další
výtvarnou autoritu. Platí [společný postup](../object-implementation-workflow.md).

## Současná větev a navržený čteč

Ověřený vstup je [main_view.worker_presentation()](../../../game/scripts/view/main_view.gd:1144)
→ [UnitSpriteLibrary.presentation_for()](../../../game/scripts/view/unit_sprite_library.gd:60)
→ main_view._draw_worker(). Knihovna vrací jeden statický obrázek profese,
zrcadlí ho pomocí faces_left() a přidává motion_offset() jako pohupování.
Její _load_atlas() navíc měří celý alfa obrys a omezuje ho šířkou 31 px.
**Tato větev není čtečka nové animace a není vhodná pro měřítko klády.**

Je potřeba specializovaná knihovna/čtečka manifestu dřevorubce připojená
v main_view.worker_presentation(), kde je dostupný svět pro strom a práci.
Ostatní profese mohou dál používat dosavadní knihovnu. Atlasové soubory
samotné žádná nynější herní větev nevybírá podle klipu/směru/snímku.

| Údaj | Navržený kontrakt |
|---|---|
| Klipy | walk_axe, chop, walk_log; ID prezentace, nikoli nové simulační akce |
| Směry / řádky | N, NE, E, SE, S, SW, W, NW |
| Vektory | (0,-1), (1,-1), (1,0), (1,1), (0,1), (-1,1), (-1,0), (-1,-1) |
| Region snímku | Celý původní canvas s explicitním atlasovým obdélníkem |
| Registrace | Společný anchor_source_px a naměřená body_height_source_px; nutná odlišnost klipu musí být explicitní a ověřená |
| Měřítko | world_scale = 33.0 / body_height_source_px; 33 je současné UnitSpriteLibrary.HUMAN_HEIGHT |
| Obrazový obdélník | Počátek = projected_feet − anchor_source_px × world_scale; rozměry = canvas_size × world_scale |
| Časování | Skutečný počet/pořadí, fps a zvolený rest_frame; případný vynechaný přesný koncový duplikát doložit |
| Výstup prezentace | Zachovat texture, rect, flip_h, cargo_position, hunger_position, shadow_size; přidat clip, direction, frame_index, renders_cargo |
| Nové obrázky | flip_h = false, bez dodatečného motion_offset() |

Autoritou směrů je [GridMapSim.MOVEMENT_DIRECTIONS](../../../game/scripts/simulation/grid_map_sim.gd:14).
Nejde o nový úhel kamery. Mřížka zůstává 40 × 40 px a výškový krok
8 px podle [MapProjection](../../../game/scripts/view/map_projection.gd:6).
Tělo určuje měřítko; sekera, konec klády ani nejnižší bota jednotlivého
snímku nejsou automatické kotvy či kalibrace. Nezmenšovat nosiče podle nákladu.

## Volba klipu a směru

1. Zachovat [_fog_entry_visible()](../../../game/scripts/view/main_view.gd:643):
   uvnitř budovy ani při ztrátě viditelnosti jednotku nekreslit, včetně
   stínu, nákladu a značek.
2. Viditelný pohyb znamená previous_position != position a
   visual_progress_ticks < visual_duration_ticks. Má přednost před
   state == idle, protože zrušený úkol může dokončovat již potvrzený krok.
   Směr je znaménko position − previous_position. Pokud carrying == log,
   použít walk_log; jinak walk_axe.
3. Stojící postava s carrying == log musí zachovat kládu ve zmrazeném
   rest_frame klipu walk_log, například při čekání na volné dveře.
4. chop se smí přehrávat pouze pro type == lumberjack, state == working,
   action == harvest, work_remaining > 0, platný zralý strom
   world.trees[source_id] a world.can_worker_work(worker). Samotné
   action == harvest při cestě ke stromu nestačí.
5. Jiné stání používá zmrazenou vhodnou pózu walk_axe. Při nulovém vektoru
   držet poslední nenulový směr; při nové/načtené postavě bez historie
   použít explicitní výchozí S. Směr neodvozovat z výškové projekce.

Poloha již vzniká v [_world_draw_entries()](../../../game/scripts/view/main_view.gd:550)
přes [worker_lerp_alpha()](../../../game/scripts/view/main_view.gd:1639).
Neinterpolovat ji podruhé. [_commit_worker_step()](../../../game/scripts/simulation/simulation_world.gd:1138)
bere délku přesunu z grid.step_duration_ticks(); terén, cesta a diagonála
tedy mění tempo skutečného pohybu. Ověřit krok vůči této rychlosti,
ne pouze podle GIFu. Fázi a případnou vazbu na ušlou vzdálenost řešit
v prezentaci; animační tempo nesmí změnit rychlost simulace.

## Kácení: současná mezera kontaktu

[_generate_tasks()](../../../game/scripts/simulation/simulation_world.gd:886)
dává úkolu stromu target = tree.position.
[_assign_task()](../../../game/scripts/simulation/simulation_world.gd:1024)
tento cíl pro harvest_tree neposune; nastaví action = harvest.
[_on_worker_arrived()](../../../game/scripts/simulation/simulation_world.gd:1456)
spustí práci na cíli. **Pracovník tedy stojí ve stejné simulační buňce
jako strom a tree.position − worker.position je nula.**

Pro první napojení zachovat poslední příchodový směr pracovníka jako
směr kácení. Nevydávat ho za vypočtené natočení z nenulového vektoru
ke stromu. Kontakt sekery s kmenem je nutné ověřit v běžné hře. Pokud
je potřeba postoj vedle kmene uvnitř buňky, navrhnout explicitní
prezentační polohu chodidel, odpovídající stín, řazení a výběr.
Přesun cíle do sousední simulační buňky by měnil cestování/pracovní
pravidla a není automatickým důsledkem dodání obrázků.

Délku práce číst z world.catalog.unit(lumberjack).harvest_ticks
(současná data: 30 ticků), postup z work_remaining. [_tick_worker()](../../../game/scripts/simulation/simulation_world.gd:901)
jej snižuje jen při povoleném pracovním ticku. Pro plynulou interpolaci
fáze použít skutečně pozorovaný pracovní postup a prezentační cache.
**Nevolat allow_worker_work_tick() z rendereru:** přes
[Nutrition.allow_work_tick()](../../../game/scripts/simulation/nutrition.gd:75)
mění zbytek pracovního úsilí. world.can_worker_work() je čtecí podmínka.

Simulace nemá události jednotlivých úderů. Případný impact_frame je
vizuální značka, nikoli událost výroby dřeva. Úbytek stromu a náklad
provádí výhradně [_finish_work()](../../../game/scripts/simulation/simulation_world.gd:1517):
sníží tree.amount, případně odstraní strom a nastaví carrying = log.
Animace tyto změny nesmí provádět ani předbíhat.

## Náklad, pauza a uložené pozice

[_draw_worker()](../../../game/scripts/view/main_view.gd:1149) dnes kreslí
symbol každého carrying přes UnitSpriteLibrary.paint_cargo(). U nového
atlasu potlačit symbol pouze při carrying == log a skutečném
renders_cargo == log z vybrané prezentace. Fallback bez nakreslené
klády dál potřebuje symbol. Načasování odevzdání určuje jedině
[_deliver_ware()](../../../game/scripts/simulation/simulation_world.gd:2178),
které u specialisty nejprve řeší fyzický vstup do domovské budovy.
Zásoby chaty ani rezervace úkolu nenahrazují stav worker.carrying.

Čas animace musí vycházet ze simulačního ticku a
clamp(accumulator / FIXED_TICK_SECONDS, 0, 1). Tick je 0,1 s podle
[DayCycle.TICK_SECONDS](../../../game/scripts/simulation/day_cycle.gd:7).
[_process()](../../../game/scripts/view/main_view.gd:154) při rychlosti 0
akumulátor nezvětšuje. Pauza a hlavní menu musí zmrazit i klipy;
nepoužívat nástěnné hodiny nebo AnimatedSprite běžící mimo simulaci.

[WorldSnapshot.to_data()](../../../game/scripts/simulation/world_snapshot.gd:25)
dnes neukládá action, work_remaining, previous_position ani animační fázi.
Po načtení se úkoly znovu odvozují. Zachovat tento kontrakt a nepřidávat
kvůli atlasu save verzi. Neslibovat identickou rozehranou pózu po
save/load; bezpečně zobrazit stav skutečně načteného světa.

## Co zbývá zapojit a ověřit

- Načíst/cacheovat atlasové regiony v nové knihovně a připojit ji přes
  main_view.worker_presentation(). Stejný výsledek používá kreslení i výběr.
- Upravit podmínku generického nákladu v _draw_worker() a hit test v
  [_worker_id_at_visual_position()](../../../game/scripts/view/main_view.gd:1068).
  Dnes stačí rect.grow(2); celý průhledný canvas by zvětšil klikací oblast.
  Použít alfu vybraného snímku nebo explicitní tělesnou hit oblast;
  neměnit kvůli tomu registraci podle pohyblivého alfa obrysu.
- Zachovat ground_position pro řazení, skutečnou projekci, pozemní
  _draw_unit_shadow(), tónování _update_day_lighting() a fog/interiér.
- Běžná cesta: game/project.godot → scenes/game_session.tscn →
  [GameSession._start_new_game() / _open_game()](../../../game/scripts/view/game_session.gd:87)
  → scenes/main.tscn → main_view.gd. HTML a grafický sandbox ji nenahrazují.
  Projekt deklaruje Godot **4.7 / GL Compatibility**; přesnou verzi
  použitého enginu zaznamenat při skutečném QA.
- Dodat nativní snímky/přehrání všech osmi směrů a tří klipů a běžný
  odchod z chaty → příchod ke stromu → práci → vznik klády → návrat/vstup.
  Navíc zastavení s nákladem, změnu směru, rovinu/svah, strom před/za
  jednotkou, den/noc, fog, výběr, pauzu a save/load.
- Ve skutečné hře ověřit oba kroky, oba pracovní úchopy, kontakt ostří,
  jedinou kládu a shodnou výšku člověka ve všech klipech. Samotný import,
  platný manifest a průhledné PNG tuto kontrolu nenahrazují.

Kontakty a běžná herní cesta jsou k tomuto datu **neověřené**.
Tento návrh neprohlašuje schválený výtvarný etalon ani hotovou integraci.
