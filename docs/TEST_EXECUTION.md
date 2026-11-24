# Tesztfuttatási útmutató – TASK-006

Tulajdonos által jóváhagyott útmutató. A [tesztstratégia](ARCHITECTURE_AND_TEST_STRATEGY.md) ellenőrzéseinek végrehajtási menete. A repóparancs, a tesztadatok és a platformcsomagok az érintett fázisban készülnek el.

## Futtatási sorrend

1. Azonosítsd a commitot, SDK-t, tesztprofilt és célplatformot. Használj szintetikus kampányt, futásonként új ideiglenes mentési profilt és elkülönített tesztkörnyezetet. Korábbi sémafájlt csak másolaton migrálj.
2. Fejlesztés közben futtasd az érintett célzott teszteket. Feltöltés előtt futtasd a repó dokumentált parancsával az elérhető releváns teljes csomagot. A CI ugyanazt a parancsot használja. A rutin tesztek külső hálózat nélkül futnak, szimulált adapterekkel. Élő próba külön futásban, elkülönített erőforráson történik.
3. A futtató eredményében ellenőrizd a tesztszámot, hibákat és kihagyásokat. Ugyanaz a commit és tesztprofil szerepeljen a futásban és a jegyzőkönyvben. Hiányzó eredmény esetén jelöld a futást sikertelennek vagy infrastruktúrahibával blokkoltnak. Azonosított átmeneti infrastruktúrahibánál egyszer próbálkozz újra, az első futás eredményének megtartásával.
4. A platformpróbán a tényleges csomagot telepítsd vagy bontsd ki, és a normál belépési ponton indítsd. Rögzítsd a csomag hashét, a rendszerverziót, a kijelzőbeállítást és adott esetben az emulátor vagy eszköz típusát. A csomagolt és az adapterhelyettesítős futás saját eredményt kap.

## Bizonyítás tesztcsoportonként

| Teszt | Előkészítés, művelet és ellenőrzés |
|---|---|
| TST-001 | Adj be kis szintetikus kalandot a publikus Dart alkalmazási műveleteken keresztül. Futtass sikertelen, majd sikeres mérföldkövet kötött sorrend nélkül. Az aktuális státuszt és a két megmaradt eseményt érték szerint ellenőrizd. |
| TST-002 | Valódi ideiglenes könyvtárat és új adapterpéldányt használj minden újranyitásnál. A megszakítást a mentési pont előtt és után idézd elő. Nyisd újra az adatot, hasonlítsd össze az állapotot az eseménytörténettel. A folyamatmegszakítást külön platformpróbán is ellenőrizd. |
| TST-003 | Verzióhoz rögzített, ismert tartalmú mintát olvass be. Hasonlítsd össze a stabil azonosítókat és a történetet migrálás után. Hibás bemenetnél az eredeti másolat hashének egyezése igazolja a megőrzést. |
| TST-004 | Két izolált profillal indulj ugyanabból a commitból. A szimulált adapterrel vezéreld a válaszvesztés és az írás közbeni helyi módosítás sorrendjét. Külön privát tesztrepóban ellenőrizd a tényleges branch fejet, a több fájlt módosító commitot, az ütközésjelzést és mindkét változat megőrzését. |
| TST-005 | A Windows-próbához kövesd az alábbi felületi menetet. Androidon emulátorban vagy teszteszközön a tényleges kezelőszervekkel ismételd a megfelelő lépéseket. Kétplatformos elfogadáshoz az Android módosítását Windowson is olvasd vissza. |
| TST-006 | Adj a lezárt alkalomhoz egy publikálható, egy titkos és egy elmaradt esetet. Ellenőrizd a helyi összefoglalót és a próbaadapterhez átadott bemenetet. Ments, hagyd jóvá, szerkessz és ellenőrizd, hogy az új revízió ismét jóváhagyást kér. |
| TST-007 | Helyettesítő végponttal válts ki sikert, elutasítást és válaszvesztést. Ellenőrizd a kérések számát, a küldött revíziót és a három eltérő állapotot. Élő próbában csak szintetikus szöveg mehet a tesztcsatornára. |
| TST-008 | Próbaértéket ments a platform védett tárolójába, majd újraindítás után olvasd vissza. Keress rá a próbaértékre a kampányfájlban és naplóban. A CORE-t külön futtasd Flutter és hálózat nélkül, és ellenőrizd a függőségi irányt. |
| TST-009 | Bontsd ki ugyanazt a Windows-csomagot és Android APK/AAB-t, amelyet a futási próbán használsz vagy abból telepítesz. Vess össze fájl-, natívkomponens- és függőségi leltárt, SBOM-ot, licencszövegeket és notice-okat. |
| TST-010 | Előre szabályozott helyettesítő futtatóval állíts elő sikert, assertion-hibát, hiányzó vagy korábbi eredményt, érvénytelen konfigurációt és időtúllépést. Ellenőrizd a kilépési állapotot, a naplót és az újrapróbálások számát. |
| TST-011 | Tiszta profillal indítsd ismételten a csomagot. Ellenőrizd a normál belépési pontot, a függő vagy mentett állapot visszaolvasását és a diagnosztikát. A célzott megszakítást elkülönített próbában végezd el. |

## Android E2E GitHub Actionsben

A felületi regresszió alapértelmezett futtatási helye a GitHub Actions. Az Ubuntu x64 runner egy Android 35 Google APIs emulátorban egymás után futtatja az x86_64 és arm64-v8a ABI-ra épített APK-kat. Az ARM64 kódot az Android native bridge fordítja. ABI-nként ellenőrzi a mentést és újraindítást, a mese megnyitását, a játékalkalom előzményeit és az app lezárását. A runner ellenőrzi az Android által kiválasztott ABI-t, és külön menti a naplókat és a képernyőképeket. A rutinfuttatásnak nincs Codex- vagy tabletkapcsolat-igénye. [Első sikeres két ABI-s futás](https://github.com/MeroDuke/Kronikas/actions/runs/45446620447)

A fizikai tabletet az olyan célzott próbákhoz használjuk, amelyekhez valódi eszköz vagy két eszköz közötti kapcsolat szükséges.

## Fizikai Android-tablet – ADB Wi-Fi-n

A fizikai tableten minden ADB-műveletet vezeték nélküli hibakereséssel végzünk, beleértve a telepítést, az indítást, a tesztelést és az engedélyezett eltávolítást. A futás előtt az aktuális hálózati végpontot az adb mdns services kimenetéből vagy a tablet Vezeték nélküli hibakeresés képernyőjéről ellenőrizzük. Az adb connect után az adb devices -l listában a hálózati eszköznek device állapotban kell lennie. A parancsokat az adb -s IP:PORT kapcsolóval célozzuk. Ha a kapcsolat offline, megkeressük az új portot és újracsatlakozunk. Az első kábel nélküli kapcsolatot a tablet modelljének lekérdezésével igazoltuk.

Fizikai próba: Wi-Fi-s ADB-n célzott, már telepített ARM64 platformpróbán lefutott a felületi mentés, teljes leállítás, újraindítás és visszaolvasás. A meglévő szintetikus kaland és a védett próbaérték ellenőrzése sikeres volt.

A tabletes regressziót Codex futtatja Wi-Fi-s ADB-n. Minden érintett felületi ellenőrzés az aktuális fejlesztési commit ARM64-próbacsomagjával kezdődik. A [meseválasztó próbafuttató](https://github.com/MeroDuke/Kronikas/blob/feature/dart-core-foundation/platform_probe/README.md#fizikai-tabletpróba) igazolja a CI-melléklet commitját és a tabletbe telepített APK hashét. Ha a rátelepítés aláírás miatt nem lehetséges, a szintetikus próbaalkalmazás cseréje külön engedélyezhető. A felületi lépésekhez a futtató képernyőképet és naplót ment. A feloldás és az esetleges ADB-engedély megadása eszközoldali lépés.

## Windows E2E Codex Computer Use-zal

Az első Windows-próbacsomagtól alkalmazható, a kész felületi folyamatokkal bővül. A Codex a telepített vagy kibontott alkalmazást a Windows felületén kezeli. A szintetikus tesztadat létrehozása lehet előkészítési művelet. Az elfogadási lépéseket a szokásos kezelőszerveken kell végrehajtani. Az infrastruktúra állapota, az automatizált futások és a Computer Use eredménye külön szerepel a jegyzőkönyvben.

1. **Indítás.** Ellenőrizd a célablakot és az izolált profilt. Jegyezd fel az alkalmazás commitját vagy csomaghashét. Készíts induló állapotképet, ha szükséges.
2. **Lépés kezdete.** Minden érdemi bevitel előtt írj bejegyzést a vezérlőtől független jegyzőkönyvbe. Legyen benne a futás és a lépés azonosítója, célablak, művelet, előfeltétel, várt látható jel és függő állapot.
3. **Művelet és megfigyelés.** Küldj egy érdemi műveletet, majd kérj friss képernyőképet vagy ellenőrizhető vizuális állapotot. Írd fel a tényleges visszajelzést és a bizonyíték helyét. Ha a vezérlő válasza elvész, az új megfigyelés előzze meg az esetleges ismétlést. Ez mentésnél, szinkronnál és küldésnél különösen fontos.
4. **Lépés lezárása.** A státusz legyen igazolt, eltérő vagy nem igazolható. Rögzítsd az első eltérést és az esetleges vezérlőhibát akkor is, ha a művelet megtörtént. Bizonytalan lépésnél csak ellenőrzött kiinduló állapotból folytasd. A kötelező, nem igazolt lépés blokkolja az E2E elfogadást.
5. **Futás lezárása.** Zárd le a tesztablakot és a vezérlést. Őrizd meg a kiválasztott képeket, lépésjelentést, eredményt és diagnosztikát az adott futáshoz. Képen, jelentésben és CI-mellékletben kizárólag szintetikus adatok jelenhetnek meg.

### Első végigjárható felületi út

| Művelet a normál felületen | Látható elfogadási jel |
|---|---|
| Nyisd meg a próbacsomagot és hozz létre egy szintetikus one-shotot. | Megjelenik a kaland és a mentett cím. |
| Vegyél fel mérföldkövet, indíts játékalkalmat, és rögzíts egy kimenetelt. | A mérföldkő státusza változik, és az esemény megjelenik a történetben. |
| Zárd be, indítsd újra a programot és nyisd meg ugyanazt a kalandot. | A státusz és az esemény együtt megmarad. |
| Zárd le az alkalmat, majd indíts egy következőt. | A korábbi alkalom visszanézhető, az új alkalom ugyanabból a mentett kalandállapotból indul. |

Az útvonal az elérhető funkciókkal bővül. A szinkron esetén a képernyőn jelzett állapot mellé a másik eszközön történő visszaolvasás ad bizonyítékot. A Discord-publikációhoz a tesztcsatorna visszaigazolása is kell. A Windowsos Computer Use futás a Windows felület eredményét igazolja. Az Androidos felület és a kétplatformos folyamat saját végrehajtást igényel.
