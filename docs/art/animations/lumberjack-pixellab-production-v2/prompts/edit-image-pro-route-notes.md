# Pro editor — ověřená cesta a nový návrh nošení

Datum: **2026-09-10**. Plán vznikl lokálně bez odeslání; provedení obou
Pro editací a navazující opětovné použití vlastních výstupů je nyní
**výslovně autorizované**. Uživatel potvrdil:
> Potvrzuji a zadam o zrušení té původní kontroly

Původní početní omezení uploadů je zrušené. Jeden původní vlastní S
master zůstává základem identity, nikoli zákazem posílat odvozené
PixelLab výsledky znovu stejné službě. Aktuální stav jednotlivých
požadavků dokládají skutečné joby; připravená šablona sama není důkaz
odeslání nebo úspěšného výsledku.

Oficiální [Edit image (Pro)](https://www.pixellab.ai/docs/tools/edit-image-pro)
odpovídá API `POST https://api.pixellab.ai/v2/edit-images-v2` podle
[OpenAPI schématu](https://api.pixellab.ai/v2/openapi.json).
Dosavadní pokusy `edits/log-S` a `edits/chop-S` použily `/edit-image`,
což je jiná cesta. `/edit-image-pixen` je další samostatný Pixen editor;
nelze jej pouze přejmenovat na Pro.

Pro je asynchronní: odpověď 202 nese `background_job_id`, dokončení
se čte existujícím `GET /v2/background-jobs/{id}`. Výstupní `last_response`
je nutné zkontrolovat podle skutečné odpovědi. Pouhá volba názvu v
klientu neprokazuje, že byl použit správný endpoint.

## Payload kontrakt

| Pole | Hodnota této zkoušky / limit |
|---|---|
| `method` | `edit_with_text`; alternativa `edit_with_reference` |
| `edit_images` | Jeden wrapper `{image:{type,base64,format},width:256,height:256}` |
| `image_size` | Výstup `{width:256,height:256}` |
| `description` | 1–2000 znaků, pro textovou metodu povinné |
| `reference_image` | Volitelný doplňkový wrapper u textu; pro referenční metodu povinný. V tomto návrhu záměrně vynechán |
| `no_background` | Výslovně `true`; výchozí hodnota Pro je `false` |
| `seed` | Nezáporné číslo; zvolený návrhový seed je uložen v šabloně |

Vstup každého obrázku nejvýše 512 × 512, výstup 32–512 px na rozměr.
Pro výstup 256² se vrací jediný obrázek. Obecný `maxItems:16` proto
neopravňuje zabalit v tomto rozlišení osm referencí do jednoho požadavku.
Veřejná produktová dokumentace uvádí pro jednu Pro editaci do 256 px
**20 generací**; skutečný účet a odečet musí potvrdit zůstatek a odpověď.
Název Pro sám nezaručuje správnou anatomii nebo skutečnou průhlednost.

## Konkrétní připravený návrh

Vstup má být **jediný původní vlastní S derivát**
`inputs/S-reference-256.png`, nikoli chybný příčný nosič z předchozí
editace. Nový prompt:
[edit-log-S-pro-v2.txt](edit-log-S-pro-v2.txt).
[Neodeslaná JSON šablona](edit-log-S-pro-v2-payload-template.json)
obsahuje zástupný řetězec místo obrazových dat; není přímo odeslatelná.

Druhý nezávislý návrh obouručního připraveného úchopu vychází ze stejného
jediného původního S, nikoli z přerámované předchozí chop editace:
[edit-chop-S-pro-v2.txt](edit-chop-S-pro-v2.txt) a
[jeho neodeslaná JSON šablona](edit-chop-S-pro-v2-payload-template.json).
Oba prompty zůstávají pod limitem 2000 znaků a oba požadavky mají právě
jeden úplný vstup 256². U kácení se vyžadují oba správné úchopy na jednom
souvislém topůrku; konkrétní pořadí pravé/levé ruky na topůrku není
vydáváno za uživatelovu podmínku.

Před každým Pro jobem počítat nejméně s **20 generacemi** pro tuto
velikost; klient má pro tento typ požadavku preflight minimum/rezervu
20 podle aktuálního požadavku rootu. Dva návrhy nejsou jedním jobem.
Celkový produkční limit a nulový USD fallback zůstávají v existujícím
rozpočtovém kontraktu, který tento lokální návrh neupravuje.

Návrh výslovně popisuje orientaci klády do obrazové hloubky, jednu pravou
ramenní oporu a pravou ruku pod předním koncem. Levá paže zůstává dole;
sekera se přesouvá do levého závěsu. Zachovává původní body hlavy,
opasku a bot v canvas. Má zabránit známé příčné kládě přes obě ramena,
oběma zvednutým pažím, zmizení sekery a změně velikosti celé postavy.

Po případném provedení porovnat skutečný výstup s původním S: polohu
hlavy/bot a výšku těla, pravou nosnou paži, levou volnou paži, jedinou
viditelnou zavěšenou sekeru, podélnou kládu a alfu v celém pozadí i
otvorech. Zadání není výsledkem kontroly; předchozí bílé neprůhledné
výstupy se nevydávají za RGBA jen podle přípony nebo volby v API.
