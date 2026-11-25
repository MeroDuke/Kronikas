# Krónikás platformpróba

Szintetikus Flutter-próba Windowson és Androidon. A mentés a Dart CORE helyi tárolóját használja, a védett érték Windows alatt DPAPI-val, Androidon az Android Keystore kulcsával titkosítva kerül a próba profiljába.

A mentési próba a **Save test data** művelettel indul. Teljes bezárás és újraindítás után a **Verify saved data** ellenőrzi a kaland állapotát, eseményét és a védett értéket. Windowson a `KRONIKAS_PROBE_HOME` környezeti változóval külön tesztkönyvtár adható meg. A CI ezt a felületi utat a kibontott Windows x64 csomagon futtatja, külön szintetikus profillal.

ARM64 telefonhoz a Platform probe CI-futás `android-arm64-platform-probe` mellékletéből bontsd ki és nyisd meg az `app-arm64-v8a-release.apk` fájlt. A CI ugyanazt az ARM64 APK-t futtatja az x64-es emulátor fordítási rétegével.

## Helyi önálló kaland

A **Mesék** képernyő közvetlenül a helyi listát mutatja. Az **Új mese** művelethez cím kell, a leírás opcionális. A **Kaland mentése** után a kaland megnyílik, és az alkalmazás újraindítása után a listából ismét megnyitható. A helyi lista saját mentési könyvtárat használ. A megnyitott kalandban az **Új mérföldkő** címet és opcionális tervezett kimenetelt kér. Az új mérföldkő függő státusszal kerül a listára, és újranyitás után is látható. [UC-001](../docs/TRACEABILITY.md#uc-001)

## Helyi játékalkalom

A megnyitott helyi kalandban a **Játékalkalom indítása** megnyit egy alkalmat. Az egyes mérföldkövek **Kimenetel rögzítése** műveleténél válassz állapotot, és írd le, mi történt. A mentés egyszerre frissíti a mérföldkő állapotát és az alkalom mesélői előzményeit. Aktív alkalomban az **Új improvizált esemény** és az **Új mesélői jegyzet** művelettel gyorsan felvehetsz új bejegyzést. Az improvizált eseményt külön jelölheted publikálhatónak. Az alkalom lezárható, az aktív és lezárt előzmények újranyitás után is olvashatók. [UC-003](../docs/TRACEABILITY.md#uc-003) · [UC-004](../docs/TRACEABILITY.md#uc-004)

## Szintetikus meseválasztó

A `tool/story_picker_walkthrough.dart` célpont a Teszt mese megnyitását, a játékalkalom előzményeit és a szinkronütközés feloldását mutatja. A Windows x64 és Android ARM64 felületi próbák ezt a szolgáltatófüggetlen tesztalkalmazást használják. [Tesztmenet](../docs/TEST_EXECUTION.md)

## Mesék és tárolási próba

A `flutter build windows --release --no-pub --target lib/stories.dart` paranccsal a Mesék kezdőképernyő épül. A Windows-build a korábbi helyi kalandok mentési könyvtárát használja. A Mesék felület a Google-tárhely beállítása nélkül is használható.

A fejlesztői tárolási próbához a `KRONIKAS_SYNC_PREVIEW_DIRECTORY` környezeti változót csak szintetikus adatokhoz kijelölt könyvtárra állítsd. A próba elkülönített helyi mentést és fájlos tesztadaptert használ. A Google OAuth és az élő Drive-átvitel külön ellenőrzést igényel. [ADR-0002](../docs/decisions/ADR-0002-local-stories-and-cloud-storage.md) · [TST-012](../docs/TEST_EXECUTION.md#tst-012)
