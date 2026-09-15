# Pila v2 — sjednocení pohledu a malované kresby

Datum **2026-09-12** · ID `sawmill` · výtvarný směr **v0.2**.
Stav: **integrováno a ověřeno**, výchozí hra používá v2; další výtvarná iterace zůstává možná.
Uživatel po [společném porovnání](../qa/sawmill-lumber-hut-comparison-2026-09-12/README.md)
výslovně zadal přepracování: „ano klidně přepracuj porad iterujeme“.
Souhlas zahrnuje navazující zapojení do hry; nejde o schválení hotového v2 etalonu.

## Cíl a odlišení

Zachovat širokou nízkou pilu, obytnou část vlevo s komínem a levým oknem,
otevřenou dílnu vpravo a dobře čitelné oddělené skladovací prostory.
Sjednotit výraznější předolevý nadhled a směry konstrukčních hran se
skutečnou produkční dřevorubeckou chatou. Silueta nemá kopírovat její
dvojici výškově odsazených střech.

Větší zaoblené šindele, silné dřevěné konstrukce, nepravidelný teplý kámen,
střídmá omítka a jasné objemy při běžném měřítku. Klády stejného vizuálního
měřítka jako u chaty; prostor pro zásoby musí toto měřítko umožnit.
Vyšší nadhled musí být vidět i na rovných plochách stolice, stojanů a komína,
ne pouze na jinak skloněné střeše. Nevymýšlet přesný 3D kamerový úhel.

## Neměnné herní smlouvy

Půdorys **4 × 2**, `#### / #E##`, 160 × 80 world px, 40px buňka,
footprint_version **1**. Dveřní pole je vůči mapové kotvě (1,0), venkovní
přístup (1,1); práh leží na jižní hraně dveřního pole. Referenční člověk 33 world px. Art v2 nemění geometrii ani save.
Skutečné nové hodnoty byly změřeny na masteru04 a ověřeny nad podkladem:
[geometrie a QA](../qa/sawmill-v2/README.md). Kotvy v1 nebyly přeneseny.

Podklad: `docs/art/sources/sawmill-v2/`; první návrh musí mít všechny patky,
stěny i blokující rekvizity uvnitř obsazené země a volný dveřní přístup.
Střešní přesahy se posuzují zvlášť. Nepasující návrh se opraví před deriváty.

## Stavy a vrstvy

Autoritou zůstává [provozní kontrakt](sawmill-operation-v1.md) a
[domácí život](../production-building-life-pattern.md). V2 musí zachovat
0–4 fyzické vstupní klády, 0–6 hotových prken, samostatnou rozpracovanou
kládu, skutečné řezání, odpočinek, levé okno, dveře a noční komín.
Soukromí v mlze, zrychlení/pauza a save/load se nemění.

Statický master bude mít prázdné stojany a pracovní stůl bez klády,
pracovníka nebo zavěšené rámové pily. Pohyblivá ruční pila patří pracovníkovi.
Všechny kotvy dveří, okna, komína, zásob, práce i předních masek se změří znovu.
Existující vlastní postava se smí převzít jen při ověřeném měřítku a kontaktu;
nedostatečný nadhled či kontakt vyžaduje vlastní novou obrazovou variantu.

## Produkce a ověření

Vestavěný imagegen, vlastní produkční chata jako přímá stylová a pohledová
reference, nový technický ground guide. Originální KaM grafika není vstup.
Nové masters a prompty zůstanou pod `sources/sawmill-v2/`, produkce pod
`game/art/buildings/sawmill/v2/`. Starší podklady v1 se zachovají.

Přejímka: společný nativní záběr s chatou, 0.75×/1×/2.4×, skutečná alfa,
měřené kontakty i vyvýšený okraj, všechny zásoby a domácí/pracovní stavy,
klikání/zakrytí/mlha, běžná hra a save/load. Dřívější výsledky v1 nejsou
ověřením v2. Nové stavební fáze nejsou součástí této výtvarné revize;
dosavadní standardní stavební větev zůstává.
