**Opravy po code review, 4. 9. 2026**

Implementace opravuje všechny čtyři potvrzené funkční nálezy a zmenšuje hlavní
zdroje duplicity a hromadění odpovědností. Existující veřejné API světa a save
verze 5 zůstávají kompatibilní; platné historické verze 1–4 mají migrační testy.

1. Tick eviduje už aktualizované jednotky. Výměna míst spotřebuje aktualizaci
   obou pracovníků; jednotku nelze znovu posunout ani jí dvakrát zkrátit čekání.
   Regrese se ověřuje přes celé ticky pro obě pořadí ID a délky kroku 1/2/4/6.
2. Zablokované doručení zahodí neplatnou trasu, uchová náklad a vybere dostupný
   kompatibilní cíl. Výběr i pohyb pracují se stejnými dočasnými překážkami.
   Bez cíle pracovník v omezeném intervalu opakuje hledání. Testy zahrnují
   stavbu, obsazený průchod, nově postavený cíl i náhradní dřevorubeckou chatu.
3. `WorldSnapshot` vlastní serializaci, validaci a migrace. Všechny používané
   struktury a hodnoty procházejí kontrolou před přijetím stagingu; vadné savy
   vracejí `false` bez změny živého světa. Obnova pracovníků používá společnou
   inicializaci `spawn_worker()`.
4. Mezerník se zpracuje před GUI včetně uvolnění a opakování klávesy. Pauzu mění
   pouze samostatný stisk. Enter i kliknutí na tlačítko nadále fungují. Test
   posílá události přes skutečný viewport a ověřuje focus i frontu výcviku.

`GameHud` odděluje konstrukci a texty UI od kamery, vykreslování a příkazů
v `MainView`. Čte model a vysílá signály; příkazy stále provádí view. Pohybové
definice pocházejí z jediného JSON zdroje s oddělenými kopiemi pro jednotlivé
světy. A* a Dijkstra sdílejí haldu se zachovaným deterministickým pořadím;
600 porovnání s předchozími algoritmy na 50 seedovaných mapách dalo stejné trasy.

Společná sada má **50 testovacích případů** a prošla na Godotu **4.6.1**.
Obsahuje původních 34 testů, 60 variant vadných vstupů ve čtyřech skupinách,
integrační testy pohybu/vstupu a dvě ekonomiky po 3 000 tickách s kontrolou
rezervací, zásob, úkolů a obnovených JSON snapshotů. Nové testy jsou součástí
standardního `res://tests/test_runner.tscn` a spouštějí se běžným launcherem.

Závěrečné ověření navíc zopakovalo oba původní scénáře z review po 10 000
tickách: celkem 20 000 ticků, 24 načtených snapshotů a žádné porušení
kontrolovaných invariantů. Výchozí ekonomika skončila se 113 uloženými prkny,
varianta s pěti vycvičenými jednotkami navíc se 159. Závěrečný import a testy
proběhly bez GDScript chyb; ověřená kopie herních souborů odpovídá pracovnímu
stromu. `git diff --check` prošel.
