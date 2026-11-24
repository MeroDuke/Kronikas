# Krónikás platformpróba

Szintetikus Flutter-próba Windowson és Androidon. A mentés a Dart CORE helyi tárolóját használja, a védett érték Windows alatt DPAPI-val, Androidon az Android Keystore kulcsával titkosítva kerül a próba profiljába.

A mentési próba a **Save test data** művelettel indul. Teljes bezárás és újraindítás után a **Verify saved data** ellenőrzi a kaland állapotát, eseményét és a védett értéket. Windowson a `KRONIKAS_PROBE_HOME` környezeti változóval külön tesztkönyvtár adható meg.

ARM64 telefonhoz a Platform probe CI-futás `android-arm64-platform-probe` mellékletéből bontsd ki és nyisd meg az `app-arm64-v8a-release.apk` fájlt. Az emulátoros CI-próba külön x86_64 APK-val fut.

## Repó- és meseválasztó előnézet

A `flutter run -d windows --target lib/story_picker.dart` az alkalmazás felületén kéri a privát GitHub-repó címét, az opcionális ágat és az adott repóra korlátozott, olvasási jogú fine-grained PAT-ot. A token az aktív kapcsolat memóriájában marad. A kiválasztott történet előnézete csak olvasható. A makettől független platformpróba továbbra is a `lib/main.dart` belépési pontból indul.

A `flutter run -d windows --target tool/story_picker_walkthrough.dart` ugyanazt a felületet nyitja szintetikus tárolóval és előre kitöltött tesztbemenettel. Csatlakozás után megjelenik a Teszt mese. Kiválasztás után a szintetikus leírás látható, majd a meselistára vissza lehet lépni.

### Fizikai tabletpróba

A Platform probe CI ugyanebből a szintetikus belépési pontból készíti az `android-arm64-story-picker` mellékletet. A meseválasztó próba saját alkalmazásazonosítót kap, ezért a korábbi mentési próbával együtt telepíthető.

Az aktuális commit CI-mellékletének kibontása és a Wi-Fi-s ADB-kapcsolat ellenőrzése után a repó gyökerében futtatható:

```powershell
python tool/tablet-story-picker.py <kibontott-melléklet> --commit <teljes-SHA> --device <IP:PORT> --evidence <új-bizonyítékmappa>
```

A futtató a commitot, az ARM64-architektúrát és a csomag SHA-256 értékét telepítés előtt ellenőrzi. A telepített APK visszaolvasott hashének is egyeznie kell. A próba a repó csatlakoztatásáról, a meselistáról, a megnyitott meséről és a visszalépésről képernyőképet ment. Eltérő CI-aláírásnál a `--replace-test-app` kapcsolóval engedélyezhető a szintetikus meseválasztó eltávolítása és újratelepítése.
