# Krónikás platformpróba

Szintetikus Flutter-próba Windowson és Androidon. A mentés a Dart CORE helyi tárolóját használja, a védett érték Windows alatt DPAPI-val, Androidon az Android Keystore kulcsával titkosítva kerül a próba profiljába.

A mentési próba a **Save test data** művelettel indul. Teljes bezárás és újraindítás után a **Verify saved data** ellenőrzi a kaland állapotát, eseményét és a védett értéket. Windowson a `KRONIKAS_PROBE_HOME` környezeti változóval külön tesztkönyvtár adható meg. A CI ezt a felületi utat a kibontott Windows x64 csomagon futtatja, külön szintetikus profillal.

ARM64 telefonhoz a Platform probe CI-futás `android-arm64-platform-probe` mellékletéből bontsd ki és nyisd meg az `app-arm64-v8a-release.apk` fájlt. A CI ugyanazt az ARM64 APK-t futtatja az x64-es emulátor fordítási rétegével.

## Helyi önálló kaland

A meseválasztó kezdőlapján a **Helyi kalandok** gomb GitHub-hozzáférés nélkül nyitja meg a helyi listát. Az **Új önálló kaland** művelethez cím kell, a leírás opcionális. A **Kaland mentése** után a kaland megnyílik, és az alkalmazás újraindítása után a listából ismét megnyitható. A helyi lista saját mentési könyvtárat használ. A megnyitott kalandban az **Új mérföldkő** címet és opcionális tervezett kimenetelt kér. Az új mérföldkő függő státusszal kerül a listára, és újranyitás után is látható. [UC-001](../docs/TRACEABILITY.md#uc-001)

## Helyi játékalkalom

A megnyitott helyi kalandban a **Játékalkalom indítása** megnyit egy alkalmat. Az egyes mérföldkövek **Kimenetel rögzítése** műveleténél válassz állapotot, és írd le, mi történt. A mentés egyszerre frissíti a mérföldkő állapotát és az alkalom mesélői előzményeit. Aktív alkalomban az **Új improvizált esemény** és az **Új mesélői jegyzet** művelettel gyorsan felvehetsz új bejegyzést. Az improvizált eseményt külön jelölheted publikálhatónak. Az alkalom lezárható, az aktív és lezárt előzmények újranyitás után is olvashatók. [UC-003](../docs/TRACEABILITY.md#uc-003) · [UC-004](../docs/TRACEABILITY.md#uc-004)

## Repó- és meseválasztó előnézet

A **Belépés GitHubbal** megmutat egy egyszeri kódot. A gomb vágólapra másolja a kódot és megnyitja a GitHub jóváhagyási oldalát. Illeszd be a kódot a GitHubon, majd a jóváhagyás után válaszd a **Jóváhagytam** gombot a Krónikásban. Egyetlen elérhető mesetárnál közvetlenül a meselista jelenik meg. A token a kapcsolat idejére memóriában marad.

Élő belépéshez a GitHub Appban egyszer engedélyezni kell a device flow-t, és az appot telepíteni kell a kiválasztott privát mesetárakra. A szinkronhoz **Contents: Read and write** jog szükséges. Az élő build a nyilvános GitHub App kliensazonosítót a `--dart-define=KRONIKAS_GITHUB_CLIENT_ID=<azonosító>` opcióból kapja. [GitHub App device flow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app#using-the-device-flow-to-generate-a-user-access-token)

A Windowsos demó buildhez futtasd a `flutter build windows --release --target tool/story_picker_walkthrough.dart --dart-define=KRONIKAS_LOGIN_DEMO=true` parancsot. A **DEMO-MESE** kód és a jóváhagyás szintetikus, a demó a Teszt mesét nyitja meg.

A `flutter run -d windows --target tool/story_picker_walkthrough.dart` ugyanazt a felületet nyitja szintetikus tárolóval és előre kitöltött tesztbemenettel. Csatlakozás után megjelenik a Teszt mese. A mesében a lezárt játékalkalmat lenyitva látható a rögzített esemény és annak mesélői láthatósága. A szinkron gombbal szintetikus címütközés jelenik meg. A CI rövid emulátoros próbája ellenőrzi a két értéket és az egyedi cím mentését. A teljes `--conflict` mód az elavult döntés elutasítását és az eredeti példányok megnyitását is végigjárja. Ezután vissza lehet lépni a meselistára.

### Fizikai tabletpróba

A Platform probe CI ugyanebből a szintetikus belépési pontból készíti az `android-arm64-story-picker` mellékletet. A meseválasztó próba saját alkalmazásazonosítót kap, ezért a korábbi mentési próbával együtt telepíthető.

Az aktuális commit CI-mellékletének kibontása és a Wi-Fi-s ADB-kapcsolat ellenőrzése után a repó gyökerében futtatható:

```powershell
python tool/tablet-story-picker.py <kibontott-melléklet> --commit <teljes-SHA> --device <IP:PORT> --evidence <új-bizonyítékmappa> --conflict
```

A futtató a commitot, az ARM64-architektúrát és a csomag SHA-256 értékét telepítés előtt ellenőrzi. A telepített APK visszaolvasott hashének is egyeznie kell. A próba a repó csatlakoztatásáról, a meselistáról, a megnyitott meséről és a visszalépésről képernyőképet ment. Eltérő CI-aláírásnál a `--replace-test-app` kapcsolóval engedélyezhető a szintetikus meseválasztó eltávolítása és újratelepítése.

Az Androidos futtatók a képernyőképek és a felületi ellenőrzés után bezárják a tesztalkalmazást. A bezárás hibás futásnál is megtörténik, amíg a készülék ADB-n elérhető.
