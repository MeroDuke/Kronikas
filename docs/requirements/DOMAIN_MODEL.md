# Domain- és adatmodell – v0.1 tervezet

A TASK-004 tervezete az elfogadott [felhasználási esetekből](USE_CASES.md), [funkcionális](FUNCTIONAL_REQUIREMENTS.md) és [nem funkcionális követelményekből](NON_FUNCTIONAL_REQUIREMENTS.md) indul ki. A modell jóváhagyásra vár. Az angol nevek logikai fogalmak; a technológia és a végleges fájlséma későbbi döntés.

## Entitások és kapcsolatok

| Entitás | Kapcsolatok és mentendő adatok | Forrás |
|---|---|---|
| Campaign | Stabil azonosító és név. Egy kampányhoz nulla vagy több kaland tartozik. | UC-001 |
| Adventure | Stabil azonosító, cím, leírás és opcionális kampányazonosító. Kampányhivatkozás nélkül önálló one-shotként kezelhető. | UC-001, UC-002 |
| Scene | Egy kalandhoz tartozó tervezett jelenet, címmel és leírással. | UC-001 |
| Milestone | Egy kalandhoz tartozó cél, opcionális jelenethivatkozással és nulla vagy több tervezett kimenetellel. | UC-001, UC-003 |
| Milestone Outcome | Tervezett kimenetelként a mérföldkőhöz tartozó lehetőség. A tényleges kimenetel a játékalkalom eseményében szöveggel rögzíthető, opcionális hivatkozással a tervezett lehetőségre. | UC-001, UC-003 |
| Adventure State | Kalandhoz tartozó aktuális nézet, benne mérföldkövenként az aktuális státusz, az utolsó kimenetel és az azt rögzítő esemény azonosítója, ha van. | UC-003, UC-004 |
| Session | Egy kalandhoz tartozó játékalkalom stabil azonosítóval, nyitott vagy lezárt állapottal és időpontokkal. Egy kalandhoz több alkalom tartozhat. | UC-003, UC-004 |
| Session Event | Egy játékalkalomhoz tartozó rögzített történés. Stabil azonosító, alkalmankénti sorrend, típus, leírás, láthatóság és opcionális jelenet- vagy mérföldkőhivatkozás. Mérföldkő-frissítéskor a rögzített új státusz és a tényleges kimenetel is az esemény része. | UC-003, UC-006 |
| GM Note | Kalandhoz vagy játékalkalomhoz kapcsolt, szerkeszthető mesélői megjegyzés. Alapértelmezésben mesélői használatra szolgál. | UC-001, UC-003, UC-006 |
| Narrative Summary | Lezárt játékalkalomhoz tartozó szöveg, forrásesemény-azonosítók, szövegrevízió és a jóváhagyott revízió hivatkozása. | UC-006, UC-007 |
| Publication Attempt | Összefoglaló-azonosító, küldött revízió, cél azonosítója, időpont és eredmény. Az eredmény lehet sikeres, sikertelen vagy bizonytalan. | UC-007 |

## Üzleti szabályok

- **DM-001.** A kalandterv, az aktuális állapot és a játékalkalmak története külön logikai egység. Az azonosítók átnevezés, fájlmozgatás és eszközváltás után is megmaradnak. Egy kalandon belüli hivatkozás az adott kaland elemére mutat.
- **DM-002.** A mérföldkövek tetszőleges sorrendben frissíthetők. A javasolt állapotok: függőben, teljesült, részben teljesült, sikertelen és kihagyott. Az új állapot és a tényleges kimenetel mentése új eseménnyel együtt történik. Egy korábbi sikertelen próbálkozás megmarad az eseménytörténetben.
- **DM-003.** A játékalkalom lezárásakor a kaland állapota megmarad. A következő alkalom ugyanezen kaland aktuális állapotából indul. Improvizált esemény jelenet- és mérföldkőhivatkozás nélkül is rögzíthető.
- **DM-004.** Az összefoglaló bemenete a lezárt alkalom ténylegesen megtörtént és publikálhatónak jelölt eseményeinek vetülete. A vetület csak a publikálható leírást tartalmazza. Egy eseményhez kapcsolt jelenet, tervezett kimenetel vagy mesélői jegyzet tartalma közvetve sem kerül a bemenetbe.
- **DM-005.** A jóváhagyás a mentett szöveg pontos revíziójára vonatkozik. Szerkesztés után az új revízióhoz új jóváhagyás kell. Egy küldési kísérlet a ténylegesen elküldeni próbált revízióhoz kötődik, így egy korábbi siker nem jelölhet egy új szövegváltozatot publikáltnak.
- **DM-006.** A tárolókonfiguráció, a szinkronállapot és a hitelesítő adatok az alkalmazás működéséhez tartoznak. A kampányfájlokba csak a kampány és a kaland adatai kerülnek. A publikációs cél hivatkozása nem tartalmazhat webhook URL-t vagy tokent.

## Logikai tárolási egységek

| Egység | Javasolt tartalom |
|---|---|
| Kampányleíró | Kampány metaadatai. Önálló one-shothoz nem szükséges. |
| Kalandleíró | Kalandterv, jelenetek, mérföldkövek, tervezett kimenetelek és kalandszintű mesélői megjegyzések. |
| Aktuális állapot | A mérföldkövek aktuális állapota és az érintett események hivatkozásai. |
| Játékalkalmonkénti történet | Játékalkalom, események és kapcsolódó mesélői megjegyzések. |
| Összefoglaló és publikációs előzmény | Ember által olvasható összefoglaló, források és revíziók metaadatai, küldési eredmények. |
| Helyi szinkronmetaadat | Utolsó ismert távoli revízió, függő helyi módosítás és ütközés állapota. |

A javasolt mentési egység üzletileg konzisztens kalandváltozat. Ha egy művelet egyszerre módosítja az állapotot és a történetet, megszakítás után az utolsó sikeres változat visszaolvasható. Feltöltéskor az alkalmazás az utolsó ismert távoli revízióhoz viszonyít. Ütközéskor a helyi módosítás és a távoli revízió egyaránt megmarad (UC-005). A konkrét tranzakciós, verziózási és migrációs mechanizmus későbbi tervezési feladat.

## Modellpélda

A mesélő előkészít egy fogadói jelenetet és egy folyón való átkelési mérföldkövet. Az első alkalmon az átkelés sikertelen. A következő alkalmon új próbálkozást rögzít, amely sikeres. Az aktuális állapot teljesült, a két kimenetel pedig a saját alkalma történetében visszaolvasható. Ha a második alkalmon egy titkos megfigyelő feltűnik és a fogadói jelenet kimarad, a két tétel közül egyik sem kerül az összefoglaló bemenetébe. A sikeres, publikálhatónak jelölt átkelés bekerülhet.

A végleges fájlséma, a sémafrissítés szabályai, a történeti hivatkozások kezelése tervmódosításkor, valamint a kalandszintű összefoglaló hatóköre a [nyitott kérdések](../OPEN_QUESTIONS.md) között szerepel.
