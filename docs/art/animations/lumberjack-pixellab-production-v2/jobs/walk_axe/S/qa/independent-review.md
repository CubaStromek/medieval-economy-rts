# Nezávislá kontrola chůze S · PixMiniMax

**2026-09-10. Doporučení: pokračovat se zbývajícími směry chůze.** Tento pilot
řeší základní problém střídání nohou a zachovává postavu i sekeru. Před herním
exportem je potřeba správně zvolit rozsah smyčky a ověřit výsledek v herním
měřítku. Nejde o uživatelské schválení ani dokončené herní QA.

Prohlédnuto všech **25 skutečných PNG** na [kontaktním archu](contact.png),
navíc jednotlivě snímky 00, 04, 08 a 24. Provedena měření všech snímků,
sousedních dvojic a návratu konce na začátek:
[statistics.json](statistics.json). Toto je kontrola skutečného obrazového
sledu a jeho pixelů; nebylo tím doloženo chování celé jednotky na herním terénu.

## Krok a návaznost

- **Střídají se obě nohy.** Anatomická pravá noha (vlevo na čelním obrázku)
  je vpředu přibližně v 00/08/16/24. Anatomická levá je vpředu v 04/12/20.
  Mezi nimi jsou průchozí fáze se zdvihem a výměnou nohou. Není to další
  případ opakovaného kroku pouze jedné nohy.
- Obrazový rytmus odpovídá přibližně **osmi fázím na celý dvojkrok**,
  opakovaným třikrát v 24 generovaných snímcích. Požadavek v promptu na jeden
  celý cyklus nebyl doslovně splněn jako 24 odlišných pohybových fází.
  Nejde však o chybějící druhý krok. Stejné fáze nejsou souborově totožné;
  obsahují drobné výtvarné variace.
- Dodatečné měření průměrného RGB rozdílu při stejných rozměrech, rozsah
  kanálů 0–255: sousední snímky **4,21555**, snímky vzdálené osm pozic
  **0,55981**, vzdálené šestnáct pozic **0,59341**. Podobně je průměrný
  rozdíl alfy při odstupu osmi snímků pouze **0,18539**. To podporuje
  vizuálně pozorované opakování fází, nikoli tvrzení o 24 nových pózách.
- Snímek 24 se vrací k póze 00. Rozdíl jejich alfa kanálu je jen
  **0,050583** v průměru; převážná část rozdílu je uvnitř kresby.
  Oba koncové obrázky nesou stejnou fázi kroku, takže přehrání 00–24
  v kruhu navíc podrží tuto fázi na hranici smyčky.

**Doporučený export:** zachovat všech 25 původních PNG jako doklad služby.
Vstupní snímek 00 použít jako referenci či klidový obraz a pro pohybovou smyčku
explicitně zvolit **01–24**. Tím se nevrací hladší vstupní kresba do každého
opakování a nezůstává dvojitá počáteční fáze. Jde o doporučení rozsahu snímků,
nikoli o zde provedený střih či přepis souborů. Tempo kalibrovat na skutečnou
rychlost jednotky; počet dodaných snímků sám neurčuje fps.

## Identita, nástroj a poloha

- Čepice, vousy, olivová tunika, světlé rukávy, pásek, přední zástěra a boty
  zůstávají rozpoznatelně stejnou postavou. Není viditelný obrat kamery,
  přepnutí směru ani záměna osoby.
- Sekera zůstává u **anatomické pravé ruky**, nízko vlevo na obrázku.
  Její hlava ani topůrko nezmizí a nepřibude druhá sekera. Úchop drží během
  sledovaných fází; levá ruka zůstává prázdná. Drobné změny pixelů na hraně
  nástroje a paže nezmizely, ale nevidím zásadní přestavbu nástroje nebo
  přehazování mezi rukama.
- Generované snímky 01–24 mají proti vstupnímu 00 **zrnitější kresbu**.
  To je vidět na tváři, rukávech, zástěře i kalhotách. Uvnitř generovaného
  sledu zůstává drobná proměnlivost textury. Zachování palety a identity není
  důkaz dokonale pevné kresby každého detailu.
- Horní řádek čepice pravidelně kolísá mezi y=46 a y=52: přibližně
  šest zdrojových pixelů svislého pohybu. Krajní x celkové alfy zůstává
  v úzkých pásmech 83–84 vlevo a 169–171 vpravo v inkluzivní souřadnici.
  Pohyb se tedy neposouvá napříč canvasem; svislé zvedání má opakující se
  rytmus kroku, nikoli kumulativní drift.
- Nejnižší pixel bot kolísá podle fáze (y=198 až 214). Nejde automaticky
  o chybnou výšku země a nesmí se z něj odvozovat nová kotva každého snímku.
  Kotva postavy musí zůstat pevná, kontakt s podkladem ověří hra.

## Alfa a stav ověření

Všech 25 souborů má skutečný obsah i průhledné okolí. Alfa obsahuje hodnoty
0 a 255, žádné mezilehlé hodnoty; žádný nenulový alfa pixel nedosahuje okraje
canvasu. Na archu není bílý obdélník, namalovaná šachovnice ani oříznutá bota
či sekera. Mechanické měření nenašlo duplicitní RGBA obrázky. Vstupní soubory
zůstaly po kontrole podle otisků nezměněné.

**Není nutné znovu generovat S kvůli chybějící noze či sekeře:** taková chyba
v tomto sledu není. Zbývá posoudit jemné blikání kresby v herní velikosti,
tempo, pevnou registraci a návaznost mezi směry. Výsledek ostatních sedmi
směrů ani kácení a nesení klády z tohoto pilotu nelze předem odvodit.
