# Nezávislé srovnání: chop E slow 24 proti slow 8

2026-09-10 · agent animation_services · **PASS, doporučeno vybrat raw 1–24 při 18 fps**.
Prohlédnut [celý arch](contact.png), 25 raw fází 0–24, a samostatně
[06](../images/frame_06.png), [12](../images/frame_12.png),
[17](../images/frame_17.png), [24](../images/frame_24.png).
Srovnáno s dříve prohlédnutou [čistou variantou slow 8](../../chop-E-slow-8/qa/independent-review.md).

| Oblast | Nový 24fázový výsledek |
|---|---|
| Průběh | Raw 1–6 postupně zvedají nástroj, 7–16 jej vedou dolů před postavu, 17–19 drží koncovou polohu, 20–24 se vracejí. Jeden úplný úder a návrat. |
| Směr a výška | Čepel zůstává před postavou napravo ve směru E, při úderu přibližně ve výši pasu. Neobjeví se dlouhá dopadová póza na opačné straně těla. |
| Obě ruce / jedna sekera | Ruce zůstávají před tělem na jednom topůrku, čepel je navázaná na stejný nástroj. Nevzniká druhá zbraň, chybějící končetina nebo ruka přemístěná za opačný bok. |
| Bez efektů | Žádný vějíř, pohybová stopa, částice, strom či špalek. Velký efekt z dřívějšího E-forward zde není. |
| Postoj | Nohy drží stejnou polohu; naměřená levá alfa mez je x=99 a dolní y=206 ve všech raw fázích. Změna pravé/horní meze patří nástroji. |
| Smyčka | Raw 24 obnoví diagonální držení a raw 1 zahájí další nápřah. Raw 00 zůstává oddělenou zdrojovou referencí. |

Proti slow 8 jsou skutečně přítomné další mezilehlé polohy sekery a rukou
při zvedání, seku i návratu; nejde pouze o proložení stejných statických
obrázků. Přibližné výdrže zůstávají na vrcholu a při dopadu, což je pro
pracovní cyklus čitelné. Obě verze drží čistý tvar, ale 24 fází je vhodnější
pro následnou nativní kontrolu plynulosti.

Zvolené rychlosti zachovají stejnou celkovou dobu: **24/18 = 8/6 = 1,333… s**.
Vyšší fps zde neznamená zrychlení celé akce. Doporučení se vztahuje na
skutečný výběr raw **1–24**, bez duplikování nebo vytváření mezisnímků.

[Technická kontrola](statistics.json) uvádí 25 skutečných RGBA fází,
nulová varování, nulové přesné duplikáty a nezměněné zdroje. Nativní
čitelnost při 33 px, přesný kontakt s herním stromem a uživatelské
výtvarné přijetí se tímto kontaktním archem ještě neprokazují. Při této
kontrole se neměnily pixely, fps v balíku, API data ani runtime manifest.
