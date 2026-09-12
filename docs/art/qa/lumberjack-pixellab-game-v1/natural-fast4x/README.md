# Přirozený cyklus při rychlosti 4×

**2026-09-10: prošlo.** Nový headless Godot 4.7.2 spustil stejný produkční
vstup menu → Osídlené údolí a skutečnou simulaci s `--speed=4 --no-capture`.
Nezměnil pracovní stav, pozici, strom, inventář ani pravidla.

[Report](report.json): **7 fází, 0 snímků, 0 chyb**, dokončené doručení v ticku
94, strom 5 → 4, výstup vlastní chaty 0 → 1. Pozorováno 91 odlišných ticků;
největší skok mezi pozorováními byl **5 ticků**, jednou. Proto tento běh
dokládá skutečný průchod více ticky mezi pozorováními, ale netvrdí, že každý
pracovní snímek probíhal v takovém skoku. [Log](run.log) je bez chyb.

Hudba N/A, Master/SFX beze změny; izolované dočasné save cesty se nezapsaly.
Jde o logickou kontrolu: nativní pixely, terénní kontakt a stíny dokládá
[finální běh v4](../natural-contact-v4/README.md), nikoli tento headless režim.
Report obsahuje hashe skutečného finálního produkčního kódu a balíku.
