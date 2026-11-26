# Implementációs terv – TASK-007

[Funkciók nyomon követése](TRACEABILITY.md)

Tulajdonos által jóváhagyott terv. Alapja a [roadmap](ROADMAP.md), az elfogadott [architektúra és tesztstratégia](ARCHITECTURE_AND_TEST_STRATEGY.md), valamint a [tesztfuttatási útmutató](TEST_EXECUTION.md). Az azonosítók a munkacsomagokat jelölik. A fejlesztési vagy kiadási ágstruktúra az adott munka jóváhagyott terjedelméhez igazodik.

| ID | Sorrend és feladat | Elfogadási bizonyíték |
|---|---|---|
| <a name="imp-001"></a>IMP-001 | Phase 1 eleje. Kiválasztani és rögzíteni a stabil Flutter/Dart SDK verziópárt, ellenőrizni a buildeszközöket és frissíteni a függőségi nyilvántartást. Létrehozni a tiszta Dart CORE alapját és a közös helyi/CI tesztparancsot. | Rögzített SDK-val tiszta checkoutból fut a formázás, statikus elemzés és a teszt. A géppel olvasható riport és kilépési eredmény egyezik. A futtató hibás konfigurációra és hiányzó eredményre külön ellenőrzött (TST-008, TST-010). |
| <a name="imp-002"></a>IMP-002<br>[UC-001](TRACEABILITY.md#uc-001) · [UC-003](TRACEABILITY.md#uc-003) · [UC-004](TRACEABILITY.md#uc-004) | Phase 1. Kampány és one-shot előkészítése, nemlineáris mérföldkövek, játékalkalom és eseménytörténet a publikus Dart alkalmazási műveleteken át. IMP-001 után. | A szintetikus kalandban sikertelen és később teljesített mérföldkő mindkét kimenetele visszakereshető. Improvizált esemény rögzíthető, a lezárt alkalmat új követheti (TST-001, TST-008). |
| <a name="imp-003"></a>IMP-003<br>[UC-003](TRACEABILITY.md#uc-003) · [UC-004](TRACEABILITY.md#uc-004) | Phase 1. Verziózott, olvasható helyi mentés, újranyitás és megőrzött történet. Azonosítók, hivatkozások és megszakítható mentés szabályainak tisztázása a formátum rögzítése előtt. IMP-002 után. | Új példányból visszaolvasható a mentés. Megszakítás és újraindítás után a státusz és az eseménytörténet összetartozó változata látszik. A séma első támogatott mintája rögzítve, a migrációs próba az első sémaváltáskor fut (TST-002, TST-003). |
| <a name="imp-004"></a>IMP-004 | Platformpróba, lehetőleg a Phase 2 integráció előtt. Minimális Windows- és Android-próbacsomag az IMP-001-ben ellenőrzött eszközkészlettel. Védett tároló, helyi mentés és tényleges csomagtartalom vizsgálata. | Mindkét platformon fut a csomag és a védett tároló próba. Friss profil, ismételt hidegindítás, megszakítás és visszaolvasás. A Windows-próba Codex Computer Use-zal dokumentálja a látható indítási és elérhető mentési lépéseket. A csomag hashéhez kötött fájl- és licencleltár egyezik a csomag tartalmával, a nyitott tételek rögzítve (TST-002, TST-008, TST-009, TST-011). |
| <a name="imp-005"></a>IMP-005<br>[UC-002](TRACEABILITY.md#uc-002) · [UC-004](TRACEABILITY.md#uc-004) · [UC-005](TRACEABILITY.md#uc-005) | Phase 2. GitHub REST adapter, offline sor, repository beállítás és szinkron. IMP-003 és a platformpróba után. Szintetikus privát tesztrepóban külön futtatni az élő próbát. | Szimulált és élő teszt igazolja a többfájlos commitot, az elveszett válasz kezelését és az elavult kliens változásainak megőrzését. A közös kiinduló állapot alapján egyesítő CORE és a kétklienses teszt igazolja a független változások megőrzését, az ütközésjelzést, a jóváhagyott feloldást és a visszaállítást. A mesélői felület az IMP-006 része. [TST-004](TEST_EXECUTION.md#tst-004), [TST-008](TEST_EXECUTION.md#tst-008). |
| <a name="imp-006"></a>IMP-006<br>[UC-001](TRACEABILITY.md#uc-001) · [UC-002](TRACEABILITY.md#uc-002) · [UC-003](TRACEABILITY.md#uc-003) · [UC-004](TRACEABILITY.md#uc-004) · [UC-005](TRACEABILITY.md#uc-005) | Phase 3. Windows/Android Flutter-felület, normál kalandkezelés és játékalkalom. Előbb a helyi felületi út, utána a kétplatformos szinkronút. | A tényleges Windows-csomagon Codex Computer Use-zal teljesül az útmutató one-shot, mérföldkő, lezárás és újraindítás forgatókönyve. Külön Android-próba igazolja az ottani műveleteket, majd a Windowson történő visszaolvasással a kétplatformos út is teljesül (TST-005, TST-009, TST-011). |
| <a name="imp-007"></a>IMP-007<br>[UC-006](TRACEABILITY.md#uc-006) · [UC-007](TRACEABILITY.md#uc-007) | Phase 4. Helyi narratív összefoglaló, szerkesztés, mentés, revízióhoz kötött jóváhagyás. Opcionális LLM csak külön szolgáltatói döntés után. | Publikálható, titkos és kimaradt eseménnyel fut a vetületteszt. A normál felületi út igazolja a mentést és az új jóváhagyás kérését szövegváltozás után (TST-006). |
| <a name="imp-008"></a>IMP-008<br>[UC-007](TRACEABILITY.md#uc-007) | Phase 5. Discord adapter, publikációs állapotok és jóváhagyott ismétlési szabály. IMP-007 után. | Siker, elutasítás és bizonytalan válasz reprodukálható helyettesítő végponttal. Elkülönített csatornán látható az egyetlen jóváhagyott próbaüzenet, az eredmény a kliensben is ellenőrizhető (TST-007, TST-008). |

## Az első fejlesztési lépés határa

Jóváhagyás után az **IMP-001** az első önálló munkacsomag. A repóba kerüljön az SDK pontos verziója és eredete, a függőségek licencének ellenőrzése, a Dart CORE kiinduló szerkezete és az elérhető ellenőrzések közös belépési pontja. A futási jegyzőkönyv a tényleges eredményt és a commitot rögzíti. Az első helyi mérföldkő az IMP-003 végén a menthető, újranyitható kaland és játékalkalom az alkalmazási belépési ponton.

## Döntések időzítése

- **IMP-001-ben** rögzítendő a pontos toolchain. **IMP-004 előtt** azonosítandó a tesztelhető Windows/Android környezet. A próbacsomag leltára alapján igazolható a választott integráció és licencút. Tisztázatlan összetevőnél a platformos technológiai ellenőrzés függőben marad.
- **IMP-003 előtt** rögzítendő a kezdeti fájlséma, a történeti hivatkozások viselkedése és a mentési commitpont. **IMP-005 előtt** pontosítandó a hozzáférés, a szinkron időzítése és az eredeti változatok megőrzésének tárolási megoldása.
- **IMP-006 előtt** döntendő a támogatott platformok köre, lokalizáció és az esetleges mérhető használhatósági cél. A kézi bizonyítékot csomaghashhez kötött, lépésenkénti jegyzőkönyvben kell megőrizni.
- Kereskedelmi kiadásról, terméklicencről és terjesztési csatornáról külön döntés születik. A fázisok ellenőrzései a [licencelési átvilágítást](LICENSING_FEASIBILITY.md) és a [nyitott kérdéseket](OPEN_QUESTIONS.md) veszik alapul.

## IMP-009

Helyi Mesék kezdőképernyő és opcionális Drive-szinkron. Első lépés a helyi felület és a szinkronlogika szintetikus próbája, majd az élő Windows–Android ellenőrzés. [ADR-0002](decisions/ADR-0002-local-stories-and-cloud-storage.md) · [UC-002](TRACEABILITY.md#uc-002) · [TST-012](TEST_EXECUTION.md#tst-012)

## IMP-010

Word-sablon és mintamese, bővíthető címsorjelölésekkel. A mesélő a saját szerkesztőjében írhat, a Krónikás előnézetet készít, majd jóváhagyáskor létrehozza a mesét. [Importformátum](STORY_IMPORT.md) · [UC-001](TRACEABILITY.md#uc-001) · [TST-013](TEST_EXECUTION.md#tst-013)

### Bevezető megosztása Discordon

Az IMP-008 első lépése az importált mese bevezetőjének elküldése. A mesélő megadja a Discord webhook URL-jét, és a csatorna nevét a megjelenítéshez. A kliens előnézetben mutatja a bevezetőt és a megadott csatornanevet. Kizárólag a Küldés Discordra művelet indít HTTP-kérést. A mesélői jegyzetek és az egyéb szekciók kimaradnak. A webhook URL védett helyi tárolóban marad. A Discord visszaigazolása, az elutasítás és a bizonytalan kézbesítés külön állapot. A kliens bizonytalan küldéskor nem próbálkozik automatikusan. [UC-007](TRACEABILITY.md#uc-007) · [TST-007](TEST_EXECUTION.md#tst-007)

### Narratív kampányértékelő

Az IMP-007 kampányszintű értékelése a mese publikálásra szánt részleteiből és a lezárt játékalkalmak publikálhatónak jelölt, tényleges eseményeiből készül. A tervezett lehetőségek háttérként szerepelhetnek, a megtörtént eseményektől elkülönítve. A belső mesélői jegyzetek kimaradnak az LLM bemenetéből is.

A mesélő írhat saját értékelést, vagy kérhet LLM-től narratív piszkozatot. A helyi narratív összegzés elkészülte után az **AI-alapú összegzés** jelölőnégyzet API-kulcs beállítása esetén választható. Alapból üres. Üres jelölőnégyzettel a helyi változat használható API-hívás nélkül. Bejelölve a mesélő átnézi az átadandó tartalmat, majd külön indítja a generálást. API-kulcs hiányában a helyi út elérhető. Külső szolgáltató esetén a generálás külön felhasználói művelet, és előtte látható az átadandó tartalom. A piszkozat szerkeszthető és menthető. Discordra csak a jóváhagyott változat küldhető. Szerkesztés után új jóváhagyás kell. Szolgáltató, adatkezelés és költség külön döntés. [UC-006](TRACEABILITY.md#uc-006) · [TST-006](TEST_EXECUTION.md#tst-006)

### Kampányértékelő megosztása Discordon

A kampányértékelő elkészülte után az IMP-008 meglévő Discord webhook beállítását és küldési folyamatát használja. A mesélő a célcsatornát és a játékosoknak szánt értékelés pontos szövegét ellenőrzi, majd külön jóváhagyja a küldést. A belső mesélői jegyzetek kimaradnak. [UC-007](TRACEABILITY.md#uc-007) · [TST-007](TEST_EXECUTION.md#tst-007)

Az IMP-007 helyi felülete a megnyitott mese Kampányértékelő gombjáról érhető el. Kampányhoz kötött mesénél a kampány lezárt alkalmait, önálló mesénél annak lezárt alkalmait használja. A helyi piszkozat és annak jóváhagyása eszközön marad. Módosított szöveg mentése visszavonja a korábbi jóváhagyást.
