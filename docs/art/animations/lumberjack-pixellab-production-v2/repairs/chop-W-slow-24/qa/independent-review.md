# Nezávislá kontrola: chop W slow 24

2026-09-10 · agent animation_services · **PASS pro výběr raw 1–24 při 18 fps**.
Prohlédnut [celý arch](contact.png), raw 0–24, a samostatně
[07](../images/frame_07.png), [17](../images/frame_17.png) a
[24](../images/frame_24.png).

| Oblast | Závěr |
|---|---|
| Cyklus | Raw 1–5 zvedají sekeru, 6–7 drží horní nápřah, 8–17 vedou sek dolů před tělo, 18–20 krátce drží dopad a 21–24 se vracejí. Jeden celý úder a návrat. |
| Směr | Dopadová čepel zůstává vlevo na obrazovce, před postavou ve směru W. Při nápřahu je čepel nad hlavou; to není úder za tělo. |
| Úchop | Obě ruce zůstávají na jednom topůrku před tělem, při dopadu přibližně ve výši pasu. Vzdálenější ruka nezůstává za opačným bokem jako v předchozí podmíněné opravě W-forward. |
| Nástroj a efekty | Jedna souvislá sekera, bez druhé zbraně, pohybového vějíře, částic, stromu či špalku. |
| Postoj | Nohy drží polohu, bez posuvu celého spritu. Dolní alfa mez je ve všech fázích y=218 a pravá x=157. Zvýšení horní meze při nápřahu patří sekeře. |
| Smyčka | Raw 24 vrací výchozí šikmé držení, raw 1 začíná další zvednutí. Není potřeba vkládat raw 00 nebo vytvářet mezisnímky. |

Doporučený výběr má **24/18 = 1,333… s**. Několik podobných fází je
čitelné zastavení v nápřahu a při dopadu; pohyb mezi nimi obsahuje skutečné
mezilehlé polohy. Tato verze řeší nejasnou zadní ruku z W-forward a je
vhodná jako vybraný W klip pro společnou nativní kontrolu.

[Technická kontrola](statistics.json) eviduje 25 RGBA souborů 256×256;
všechny obsahují průhledné i viditelné pixely, žádný nemá nenulovou alfu
na kraji plátna. Registrace drží polohu vlastní reference; její dolní mez
y=218 sama o sobě neurčuje správný společný herní kontakt. Čitelnost při
33 světových pixelech a kontakt s terénem/stromem se musí posoudit v příslušné
nativní scéně. Tento posudek neznamená uživatelské přijetí výtvarného stylu.

Zdrojové pixely, API data, fps ani runtime balík se při této kontrole neměnily.
Raw 00 zůstává zdrojovou referencí; `rest_frame` balíku indexuje vybranou
sekvenci, nikoli automaticky tuto nezahrnutou referenci.
