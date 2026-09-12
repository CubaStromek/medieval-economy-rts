# Nezávislá kontrola: chop / E

2026-09-10 · agent animation_services · **REPAIR — chybný směr dokončení seku**.
Prohlédnut [celý arch](contact.png) raw 0–16 a samostatné fáze
[05](../images/frame_05.png), [06](../images/frame_06.png),
[08](../images/frame_08.png), [13](../images/frame_13.png).

Postava začíná směrem na východ, tedy doprava v obrázku. V raw 1–4 zvedá
jednu sekeru oběma rukama. Raw 5 ještě vede čepel před sebe doprava;
raw 6 však přetočí trup k divákovi a sekera pokračuje napříč tělem doleva.
Raw 7–12 ji drží **nalevo od postavy**, proti určenému směru E. Raw 13–16
se vracejí doprava. Jako samostatný pohyb je to široký švih přes tělo,
ale koncová poloha nepodporuje očekávaný zásah stromu před postavou na východě.

| Oblast | Výsledek |
|---|---|
| Jedna sekera / dvě ruce | **Prošlo základní prohlídkou.** Čepel a topůrko tvoří jeden nástroj; obě ruce jej vedou. Nevidím extra paži, druhou sekeru nebo odpojenou čepel. |
| Směr a místo zásahu | **REPAIR.** Dlouhá koncová výdrž 6–12 je na opačné straně těla než zamýšlený cíl E. Čepel je v těchto fázích přibližně u kyčle/stehna; prioritou je správná strana a bod zastavení. |
| Nohy / trup | Nohy vizuálně drží postoj, žádná chůze. Trup se během seku výrazně natočí k divákovi. Fixní rámec není důkazem kontaktu s reálným terénem. |
| Smyčka 1–16 | Zvednutí → švih → návrat jsou rozeznatelné, 16 se vrací k výchozí póze a může pokračovat 1. Návaznost začátku a konce neopravuje vnitřní chybnou trajektorii. |
| Přidané objekty / FX | **Prošlo:** nevidím strom, špalek, částice, úlomky ani další prostředí. |
| Alfa / původ | [Helper](statistics.json): 17 skutečných RGBA fází, žádné varování nebo přesné duplikáty, zdroje nezměněné. |

Pro opravu je třeba zastavit hlavu sekery **před tělem na pravé straně
obrázku**, u zamýšleného kmene ve výši pasu; nenechat dlouhou dopadovou
pózu přejít vlevo za osu pracovníka. Konkrétní úderový bod pak musí být
ověřen proti hernímu stromu.

Žádný pixel, API záznam ani runtime balík nebyl změněn. Raw 00 je vstupní
reference, ne zde zavedený idle. Nativní vykreslení tohoto klipu ve hře
a uživatelské přijetí nebyly ověřeny.
