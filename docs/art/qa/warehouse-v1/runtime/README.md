# Skladiště v1 — nativní ověření

Runner: `game/tests/warehouse_game_runner.tscn`.

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --path game --audio-driver Dummy --windowed --resolution 1280x800 \
  --log-file ../docs/art/qa/warehouse-v1/runtime/native.log \
  res://tests/warehouse_game_runner.tscn
```

Volitelný výstup: `-- --capture=/absolutní/cesta`.

První část vstupuje skutečným menu do Reliefu. Vykoná každý simulační tick,
pozoruje reálné přesuny zásob a skutečný noční návrat nocležníků, pak uloží
a načte jen vlastní dočasný soubor. Nečte hráčovy uložené pozice. Hudba při
spuštění používá Dummy audio driver; runner zároveň ztlumí případný samostatný
hudební bus.

Druhá část je výslovně označená izolovaná vizuální fixture v čerstvé scéně Main:
stejné skladiště vedle chaty a pily, 0.75×/1×/2.4×, den/noc, prázdné/plné
zásoby bez změny pixelů a vyvýšený půdorys s přístupem. Její ručně nastavené
stavy nejsou vydávány za normální gameplay.

`report.json` nese skutečný výsledek, čtené otisky assetů, stavy i chyby.
Samotná existence runneru ani tohoto souboru není průchod testů.
