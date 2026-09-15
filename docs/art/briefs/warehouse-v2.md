# Skladiště v2 — sjednocení perspektivy s chatou a pilou

Datum **2026-09-13**, ID `warehouse`, výtvarný směr **v0.2**, stav **produkční v2 zapojena a ověřena ve hře**.
Navazuje na [zadání v1](warehouse-v1.md); geometrie a výslovná výjimka
bez vizuálních zásob a postav uvnitř zůstávají platné.

Uživatel nejprve přijal architekturu („super“), požádal o otevřená denní
vrata a zavřená noční vrata, světlo a kouř a autorizoval herní integraci.
Implementace v1 je zachována. Následná kontrola na jeho pokyn odhalila
příliš plochou perspektivu; uživatel proto výslovně požádal **upravit skladiště
tak, aby souhlasilo s ostatními dvěma**.

## Konkrétní oprava

Obě vlastní referenční budovy mají vyvýšený předolevý pohled, dominantní
čelo a menší levý bok. Skladiště v1 mělo plošší čelní i hloubkové hrany.
Obrazový sklon jeho okapu byl přibližně 10°, chaty přibližně 17°; hloubkový
trám skladiště přibližně 35°, chaty kolem 47°. Jde o orientační měření
malovaných čar, **nikoli prostorové úhly kamery**.

V2 přestavuje pohled na tutéž architekturu z vyššího stanoviště. Směry
čela, levého boku, oken, podezdívky a podlahy nyní odpovídají rodině
vlastní chaty a pily. Naměřený obrazový sklon čelní podezdívky je −0,266,
levého boku +0,834 a hřebene −0,274. Jde o změnu kresby celé architektury,
bez nezávislého X/Y roztažení bitmapy či náklonu svislých sloupů.
Valbová střecha, nakládací vikýř, široká brána, kámen/dřevo/omítka,
komín a dvě okna zůstávají identitou skladiště. Dům není kopií pily.

## Geometrie a stavy

Půdorys stále **3 × 3**, maska `###/###/#E#`, 120 × 120 world px;
venkovní vstup `(1,1)` vůči dolní levé kotvě. Skutečný práh, volný přístup
a 33px člověk jsou určující pro první upravenou kresbu.
Nový [technický podklad](../sources/warehouse-v2/ground-guide.png) obsahuje
půdorys a obrazová vodítka. Zemní kontakty a velikost dveří byly změřeny před odvozením denní
varianty: [výsledky](../qa/warehouse-v2/concept-measurements.json).
Při jednotném měřítku 0,095 world px na zdrojový pixel se viditelné
pevné kontakty vejdou do půdorysu. Vstup má šířku přibližně 40 px
a výšku 40,3–40,7 px; pod rohovými vzpěrami zbývá přibližně 37 px
pro skutečnou 33px postavu. Práh je zdrojově `[670,1190]`.

Přes den otevřená vrata, v noci zavřená; světlo v obou oknech a jemný kouř
podle skutečných nocležníků. Existující `WarehouseLife` a práva v mlze
zůstávají, všechny obrazové kotvy byly nově změřeny ve v2. Žádné zásoby,
osoby uvnitř, nová stavební sada, změna simulace, kamery, kolize či save.

## Produkce a ověření

Vestavěný ImageGen: vlastní chata a pila jsou přímé reference kamery,
skladiště v1 pouze identity. Zdrojové obrázky a skutečné prompty v
`docs/art/sources/warehouse-v2/`, produkční RGBA v
`game/art/buildings/warehouse/v2/`. V1 zůstává zachována.
Zkontrolovat první koncept a výsledek ve stejném snímku vedle obou
referencí; neprohlásit pouhou podobnost materiálů za shodu perspektivy.
Ověřit den/noc, oba průchozí stavy vrat, světla, kouř, nativní přiblížení,
rovinu a vyvýšený okraj, mlhu, alfa výběr a stávající běžnou herní cestu.
V1 měla před touto revizí 17/17 cílených a 876/876 úplných headless testů;
to nejsou výsledky nových v2 obrazů.

Podrobný [integrační záznam](warehouse-v2-integration.md),
[QA záznam](../qa/warehouse-v2/README.md) a
[původ a hashe](../sources/warehouse-v2/provenance.json) rozlišují měření,
automatické kontroly a vizuální závěr. Finální v2 ani celá výtvarná sada
tím nejsou prohlášeny za schválené uživatelem.

Výsledek 2026-09-13: **17/17 cílených testů, 66/66 nativních kontrol**,
17 herních snímků. Čerstvá běžná hra načetla přesné finální pixely v2.
Společné snímky při 0,75× / 1× / 2,4× ukazují sjednocený nadhled
a směry hran. Ověřené denní/noční stavy, dvě osvětlená okna, komínový
kouř, pauza, uložená hra a vyvýšený základ; viz odkazované QA.
