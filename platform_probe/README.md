# Krónikás platformpróba

Szintetikus Flutter-próba Windowson és Androidon. A mentés a Dart CORE helyi tárolóját használja, a védett érték Windows alatt DPAPI-val, Androidon az Android Keystore kulcsával titkosítva kerül a próba profiljába.

A mentési próba a **Save test data** művelettel indul. Teljes bezárás és újraindítás után a **Verify saved data** ellenőrzi a kaland állapotát, eseményét és a védett értéket. Windowson a `KRONIKAS_PROBE_HOME` környezeti változóval külön tesztkönyvtár adható meg. A CI ezt a felületi utat a kibontott Windows x64 csomagon futtatja, külön szintetikus profillal.

ARM64 telefonhoz a Platform probe CI-futás `android-arm64-platform-probe` mellékletéből bontsd ki és nyisd meg az `app-arm64-v8a-release.apk` fájlt. A CI ugyanazt az ARM64 APK-t futtatja az x64-es emulátor fordítási rétegével.

## Helyi önálló kaland

A meseválasztó kezdőlapján a **Helyi kalandok** gomb GitHub-hozzáférés nélkül nyitja meg a helyi listát. Az **Új önálló kaland** művelethez cím kell, a leírás opcionális. A **Kaland mentése** után a kaland megnyílik, és az alkalmazás újraindítása után a listából ismét megnyitható. A helyi lista saját mentési könyvtárat használ. A megnyitott kalandban az **Új mérföldkő** címet és opcionális tervezett kimenetelt kér. Az új mérföldkő függő státusszal kerül a listára, és újranyitás után is látható. [UC-001](../docs/TRACEABILITY.md#uc-001)

## Helyi játékalkalom

A megnyitott helyi kalandban a **Játékalkalom indítása** megnyit egy alkalmat. Az egyes mérföldkövek **Kimenetel rögzítése** műveleténél válassz állapotot, és írd le, mi történt. A mentés egyszerre frissíti a mérföldkő állapotát és az alkalom mesélői előzményeit. Aktív alkalomban az **Új improvizált esemény** és az **Új mesélői jegyzet** művelettel gyorsan felvehetsz új bejegyzést. Az improvizált eseményt külön jelölheted publikálhatónak. Az alkalom lezárható, az aktív és lezárt előzmények újranyitás után is olvashatók. [UC-003](../docs/TRACEABILITY.md#uc-003) · [UC-004](../docs/TRACEABILITY.md#uc-004)

## Repó- és meseválasztó előnézet

A `flutter run -d windows --target lib/story_picker.dart` az alkalmazás felületén kéri a privát GitHub-repó címét, az opcionális ágat és az adott repóra korlátozott, fine-grained PAT-ot. A token az aktív kapcsolat memóriájában marad. A megnyitáshoz olvasási jog, a távoli feloldás mentéséhez tartalomírási jog kell. A **Mese szinkronizálása** művelet mesénként elkülönített helyi mentést használ. Ütközéskor a panel megmutatja az eltérő értékeket, kezeli az elavult döntést, és megnyithatóvá teszi a feloldás előtti példányokat. A makettől független platformpróba továbbra is a `lib/main.dart` belépési pontból indul.

A `flutter run -d windows --target tool/story_picker_walkthrough.dart` ugyanazt a felületet nyitja szintetikus tárolóval és előre kitöltött tesztbemenettel. Csatlakozás után megjelenik a Teszt mese. A mesében a lezárt játékalkalmat lenyitva látható a rögzített esemény és annak mesélői láthatósága. A szinkron gombbal szintetikus címütközés jelenik meg. A CI rövid emulátoros próbája ellenőrzi a két értéket és az egyedi cím mentését. A teljes `--conflict` mód az elavult döntés elutasítását és az eredeti példányok megnyitását is végigjárja. Ezután vissza lehet lépni a meselistára.

### Fizikai tabletpróba

A Platform probe CI ugyanebből a szintetikus belépési pontból készíti az `android-arm64-story-picker` mellékletet. A meseválasztó próba saját alkalmazásazonosítót kap, ezért a korábbi mentési próbával együtt telepíthető.

Az aktuális commit CI-mellékletének kibontása és a Wi-Fi-s ADB-kapcsolat ellenőrzése után a repó gyökerében futtatható:

```powershell
python tool/tablet-story-picker.py <kibontott-melléklet> --commit <teljes-SHA> --device <IP:PORT> --evidence <új-bizonyítékmappa> --conflict
```

A futtató a commitot, az ARM64-architektúrát és a csomag SHA-256 értékét telepítés előtt ellenőrzi. A telepített APK visszaolvasott hashének is egyeznie kell. A próba a repó csatlakoztatásáról, a meselistáról, a megnyitott meséről és a visszalépésről képernyőképet ment. Eltérő CI-aláírásnál a `--replace-test-app` kapcsolóval engedélyezhető a szintetikus meseválasztó eltávolítása és újratelepítése.

Az Androidos futtatók a képernyőképek és a felületi ellenőrzés után bezárják a tesztalkalmazást. A bezárás hibás futásnál is megtörténik, amíg a készülék ADB-n elérhető.

## Mesék és tárolási próba

A `flutter build windows --release --no-pub --target lib/stories.dart` paranccsal a Mesék kezdőképernyő épül. A Windows-build a korábbi helyi kalandok mentési könyvtárát használja. A Mesék felület a Google-tárhely beállítása nélkül is használható.

A fejlesztői tárolási próbához a `KRONIKAS_SYNC_PREVIEW_DIRECTORY` környezeti változót csak szintetikus adatokhoz kijelölt könyvtárra állítsd. A próba elkülönített helyi mentést és fájlos tesztadaptert használ. A Google OAuth és az élő Drive-átvitel külön ellenőrzést igényel. [ADR-0002](../docs/decisions/ADR-0002-local-stories-and-cloud-storage.md) · [TST-012](../docs/TEST_EXECUTION.md#tst-012)
