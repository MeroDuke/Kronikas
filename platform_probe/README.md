# Krónikás platformpróba

Szintetikus Flutter-próba Windowson és Androidon. A mentés a Dart CORE helyi tárolóját használja, a védett érték Windows alatt DPAPI-val, Androidon az Android Keystore kulcsával titkosítva kerül a próba profiljába.

A mentési próba a **Save test data** művelettel indul. Teljes bezárás és újraindítás után a **Verify saved data** ellenőrzi a kaland állapotát, eseményét és a védett értéket. Windowson a `KRONIKAS_PROBE_HOME` környezeti változóval külön tesztkönyvtár adható meg.

ARM64 telefonhoz a Platform probe CI-futás `android-arm64-platform-probe` mellékletéből bontsd ki és nyisd meg az `app-arm64-v8a-release.apk` fájlt. Az emulátoros CI-próba külön x86_64 APK-val fut.
