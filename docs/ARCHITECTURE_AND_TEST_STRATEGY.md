# Architektúra és tesztstratégia – TASK-006

Tulajdonosi jóváhagyásra váró tervezet. Alapja a jóváhagyott [domainmodell](requirements/DOMAIN_MODEL.md), a [technológiai irány](TECHNOLOGY_FEASIBILITY.md) és a [licencelési átvilágítás](LICENSING_FEASIBILITY.md).

## Függőségi irány

| Réteg | Felelősség |
|---|---|
| Flutter felület | Kalandtervezés, játékalkalom, szinkronállapot, összefoglaló és jóváhagyás. Felhasználói műveleteket ad át az alkalmazási rétegnek és megjeleníti az eredményt. |
| Dart alkalmazási réteg | A felhasználási esetek végrehajtása. A tároláshoz, távoli szinkronhoz, opcionális összefoglalóhoz és publikációhoz szükséges interfészek itt jelennek meg, az adott fázisban. |
| Dart domain | Kalandterv, állapot, eseménytörténet és üzleti szabályok. A szabályok a platformtól, Fluttertől, fájlformátumtól és külső szolgáltatótól függetlenül futtathatók. |
| Adapterek | Helyi JSON/Markdown tárolás, platformonkénti védett titoktárolás, GitHub REST, később opcionális LLM és Discord. Az alkalmazási réteg interfészeit valósítják meg. A felület belépési pontja köti össze a konkrét megvalósításokat. |

## Mentés és távoli műveletek

- **Helyi mentés.** A mérföldkő változása és az azt rögzítő esemény egy üzleti mentési egység. A helyi adapter csak tartós mentés után jelez sikert. A javasolt próba új változatot készít az előző mellett, majd egyetlen commitponttal teszi olvashatóvá. Kényszerített megszakítással kell ellenőrizni a commitpont előtti és utáni helyreállást mindkét platformon. A fájlséma és a mechanizmus a próba alapján véglegesíthető.
- **Szinkron.** A kliens a letöltött távoli commitból és a helyi mentett állapotból indul. Egyetlen Git-commit tartalmazza az összetartozó fájlváltozásokat. Az írás force nélküli, a kliens által ismert commitból származó commit alapján történik. A kliens egy távoli branchre egyszerre egy írást indít, mert több kaland is ugyanarra a branchre kerülhet. A feltöltés egy konkrét helyi revízióra vonatkozik, így közben keletkező módosítás függőben marad. Elveszett válasz esetén a következő írás előtt ellenőrizni kell, hogy a várt commit a távoli történet része-e. Eltérő módosításoknál mindkét változat megmarad, a feloldás menetét külön kell jóváhagyni.
- **Összefoglaló.** A domain publikálható vetületet képez lezárt alkalom tényleges eseményeiből. A helyi összefoglaló és az opcionális LLM ugyanazt a vetületet kapja. A küldés előtt a jóváhagyott és a küldendő revízió egyezését ellenőrizni kell. Bizonytalan Discord-kimenetelnél a küldési kísérlet megmarad és a mesélő visszajelzést kap. Automatikus újraküldés helyett a feloldási szabály külön döntést igényel.

## Tervezett ellenőrzések

A hivatkozások az elfogadott [funkcionális](requirements/FUNCTIONAL_REQUIREMENTS.md) és [nem funkcionális](requirements/NON_FUNCTIONAL_REQUIREMENTS.md) követelményekre mutatnak. A tesztek szintetikus adatokkal indulnak. A külső szolgáltatási próbák elkülönített tesztkörnyezetben futnak.

| ID | Szint és ellenőrzés | Követelmények |
|---|---|---|
| TST-001 | Domain. Kampány, önálló one-shot és nemlineáris mérföldkő műveletek. Sikertelen, majd sikeres kimenetel és improvizált esemény visszakereshető. | FR-001–FR-009, NFR-003, NFR-009 |
| TST-002 | Helyi integráció. Kaland és játékalkalom újranyitása, lezárás után folytatás, automatikus mentés. Megszakítás a commitpont két oldalán; a látható állapot és történet egyezik. | FR-004, FR-010–FR-011, FR-016, NFR-005–NFR-006, NFR-011 |
| TST-003 | Adatkompatibilitás. Korábbi támogatott séma mintája megnyitható vagy migrálható. Állapot és történet összevetése, hibás bemenetnél az eredeti fájl megmarad. A séma verziózásától kezdve. | NFR-011–NFR-012 |
| TST-004 | Adapter és kétklienses próba. Tárolóbeállítás, könyvtár és betöltés, offline mentés, egy commit több fájlra, eltérő módosítások, feltöltés közbeni szerkesztés, válaszvesztés és két eszköz közti folytatás. | FR-012–FR-019, NFR-005, NFR-010 |
| TST-005 | Platform és felület. Windows és Android telepítés. Windowson kaland előkészítése, Androidon megnyitás, eseményrögzítés és lezárás, majd a szinkronizált állapot betöltése Windowson. Játék közbeni státuszváltás külön mentési művelet nélkül. | NFR-001–NFR-002, NFR-004 |
| TST-006 | Domain és adapter. Publikálható, titkos és elmaradt esemény mintája; a tesztadapter csak a publikálható vetületet kapja. Helyi összefoglaló, szerkesztés, mentés, jóváhagyás és revízióváltás. | FR-020–FR-023, FR-026 |
| TST-007 | Publikációs adapter. Siker, szolgáltatói elutasítás és bizonytalan küldés; csak a jóváhagyott revízió küldhető. | FR-022, FR-024–FR-025 |
| TST-008 | Védett tárolás és modulhatár. Szintetikus titok visszaolvasható a platform védett tárából, naplóban és kampányfájlban nincs jelen. A CORE tesztjei Flutter és hálózat nélkül futnak. | NFR-007–NFR-009 |
| TST-009 | Csomagolás és licenc. Windows- és Android-csomag kibontása, natív komponensek és tartalmak leltára, SBOM-egyeztetés, licencek és notice-ok ellenőrzése. | TASK-005, licencpolitika |

## CI és ellenőrizhető bizonyítékok

- A funkció megjelenésével együtt kerüljön CI-be a formázás, statikus elemzés és a hozzá tartozó automatizált ellenőrzés. A Phase 1 első kapuja a tiszta Dart CORE és a helyi perzisztencia. A platform build, csomagolt smoke teszt és licencellenőrzés az első Windows/Android próbacsomagtól kapcsolódik be.
- A próbacsomag leltára tartalmazza a pontos feloldott függőségeket, csomagolt natív fájlokat és eszközöket, továbbá a szükséges teljes licencszövegeket és notice-okat. Eltérés vagy tisztázatlan tétel esetén az adott csomag ellenőrzése függőben marad. A tényleges terjesztési csatorna feltételeit a csatorna kiválasztásakor kell ellenőrizni.
- A PR kapcsolja össze a feladatot, az érintett követelmény- és tesztazonosítókat, a futtatott ellenőrzéseket és a tényleges eredményeket. A CI és a kézi próbák bizonyítékai az adott commitra és ahol releváns, a csomag hashére hivatkozzanak. AI-val készült változtatásnál a review a követelményekhez, szélső esetekhez, teszteredményekhez és a függőségi változásokhoz igazodik.

A [nyitott kérdések](OPEN_QUESTIONS.md) és a szükséges próbák ütemezése a TASK-007 implementációs terv bemenetei. A fenti ellenőrzések tervezett ellenőrzések.
