# Přirozený pracovní cyklus — první běh před opravou kontaktu

**2026-09-10, Codex. Technický průchod dokončen, kontakt sekery se stromem neprošel.**
Všech 17 skutečných PNG v tomto adresáři bylo otevřeno a prohlédnuto. Tento
běh zachovává první důkaz chyby pracovního postoje; není přejímkou výsledné kresby.

Produkční `game_session.tscn` otevřel běžné menu. Test stiskl **Nová hra →
Osídlené údolí → Spustit mapu**. Původní mapa Relief poskytla dřevorubce 19,
dokončenou chatu 2 a strom 13. Nebyly dosazeny činnosti, souřadnice, klády,
stromy ani jiné simulační stavy. Použity byly pouze ovládání menu, pauza,
rychlost 1× a cílené zaostření kamery. Herní uložené pozice se nenačítaly;
oba sloty session měly izolované dočasné cesty a nevznikl ani jeden save.
Hudba **N/A**: projekt nemá audio přehrávače; Master ani efekty se netlumily.

| Skutečná fáze | Tick | Důkaz |
|---|---:|---|
| Chůze k vlastnímu zdroji, `walk_axe/W` | 2 | [Detail](03-walk_axe-2_4x.png), [1×](03-walk_axe-1x.png) |
| Začátek těžby, `chop/W`, 30 práce zbývá | 8 | [Detail](04-chop-start-2_4x.png) |
| Střed těžby, 16 práce zbývá | 22 | [Detail](05-chop-middle-2_4x.png) |
| Konec rozpracované těžby, 5 práce zbývá | 33 | [Detail](06-chop-end-2_4x.png) |
| Skutečné převzetí klády, strom 5 → 4 | 38 | [Detail](07-picked-log-2_4x.png) |
| Zpáteční chůze `walk_log/E` | 39 | [Detail](08-walk_log-2_4x.png), [1×](08-walk_log-1x.png) |
| Doručení vlastní chatě, výstup 0 → 1, worker uvnitř | 94 | [Detail](09-delivered-2_4x.png), [1×](09-delivered-1x.png) |

[Strojový report](report.json) obsahuje 7 fází, 17 snímků s SHA-256,
pozorované meziticky a **0 neúspěšných technických kontrol**. Pozorované směry
jsou S/W/E/SE/N; ne všechny byly zachyceny samostatným obrázkem. Skutečný
pracovní směr byl W. Pauza u každé fáze zastavila simulační tick i animační
snímek. Nesená kláda přepnula na skutečný logový klip a potlačila obecnou
značku nákladu. Po doručení pracovník správně vypadl z draw listu a na obrázku
zůstává budova, nikoli falešně stojící člověk.

**Viditelná závada:** při sekání jsou strom i pracovník ve stejném poli
`(3, 13)` a jejich fyzická projekce je `(140, 540)` světových px. Postava stojí
uprostřed koruny/kmene a úder míří vlevo mimo vlastní kmen. Chybu potvrzuje
začátek, střed i konec práce, nikoli jen samotný nápřah. Sousední vysoká střecha
navíc překrývá dolní část člověka; kontakt chodidel zde nelze vizuálně přejmout.
Na 1× je rozpoznatelná postava a kláda, jemný úchop je drobný. Na 2.4× je jedna
kláda a pracovní pohyb čitelnější. Překryv střechy omezuje kontrolu nástroje na pásku.

Přirozené světlo je úsvit od 05:00 do 05:22, mlha zůstala zapnutá podle mapy.
Tento běh nedokládá umělé všechny směry, den/noc, svahy, klikání, výkonnost
ani obnovení uložených mezistavů; takové kontroly patří do oddělených sad.

Prostředí: nově spuštěný nativní Godot 4.7.2 `ed1daf0bf`, OpenGL 4.1
Metal Compatibility, Apple M4, výstup 1280 × 800. Balík má SHA-256 manifestu
`7aa01262a49e4e682f87c9a8445f6fc79ec1fd6f18154f34d8a11a320a43fa64`.
Runner i nový proces používaly aktuální produkční view s hloubkovou rezervou
3.5 světových px. Report zachytil hash tehdejšího runneru, nikoli jednotlivých
produkčních skriptů; tyto hashe se doplňují až v následujícím běhu.

Poznámka k měření obrazových souřadnic tohoto prvního běhu: `foot_world`, tick
a stav odpovídají zachycené fázi. `foot_screen` byl zapsán před dvěma čekanými
renderovacími snímky a kvůli smoothingu kamery není přesnou souřadnicí v PNG.
Původní data se nemění. Runner pro příští běh zaostří pomocí
`Camera2D.reset_smoothing()` a metadata přečte až po `frame_post_draw`.
