# Nezávislá kontrola opravy: chop E forward

2026-09-10 · agent animation_services · **REPAIR — nepovolený efekt v raw 02**.
Prohlédnut [celý arch](contact.png), všech 17 raw fází, a detailně
[02](../images/frame_02.png), [03](../images/frame_03.png),
[12](../images/frame_12.png).

Směr dopadu se opravil: ve fázích 3–14 je hlava sekery před postavou
napravo, ne na opačné západní straně. Současně však **raw 02 obsahuje
velký světlý vějíř/oblouk pohybové stopy**, který nahrazuje čistě čitelnou
sekeru a výrazně přesahuje postavu. Je to přidaný FX, neslučitelný se
zadáním samostatné postavy bez efektů.

- Raw 1 ukazuje krátký nápřah, raw 2 výrazný efekt a raw 3–14 dlouhou
  přibližně statickou koncovou pózu. Raw 15–16 přejdou zpět do držení.
  Smyčka tedy má jeden úder, ale její tempo tvoří velmi krátký útok a
  dlouhá výdrž; samotná oprava správné strany není úplné vizuální přijetí.
- V dopadových pózách zůstává jedna sekera. Ruce se v boční projekci
  překrývají; není tak jasně oddělený úchop jako ve výchozím raw 00.
- Nohy drží postoj, postava nezačne chodit. Žádný strom nebo špalek
  nepřibyl; výslovně nevyhovuje uvedená pohybová stopa.
- [Technická kontrola](statistics.json) prošla pro alfa a zachování zdrojů;
  17 RGBA fází bez varování a přesných duplikátů. Technicky platná alfa
  však nečiní přidaný efekt správným.

Celou sekvenci **1–16 nedoporučuji vybrat jako čistou finální animaci**
v této podobě. Raw 02 jsem sám nevyloučil, žádné pixely, API záznamy,
fps ani runtime balík se neměnily. Původní nevyhovující E job i tento
opravný pokus zůstávají dohledatelné.
