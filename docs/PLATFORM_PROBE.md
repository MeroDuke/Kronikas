# Windows és Android platformpróba – IMP-004

A `platform_probe` külön telepíthető, szintetikus Flutter alkalmazás a Dart CORE mentési adapterével. A védett próbaérték Windowson DPAPI felhasználói védelemmel, Androidon Android Keystore-ban tartott AES-kulccsal védett. Az alkalmazás a tesztértéket memóriában hasonlítja össze, a felületen csak eredményt mutat. A cél az első platformintegráció igazolása.

## Windows helyi futás

- Flutter 3.50.1, Dart 3.14.0, Visual Studio Community 2026 18.9.12112.369. A release csomag buildje és a Flutter statikus elemzés átment.
- A kibontott ZIP-et friss szintetikus profillal indítottuk. A Codex Computer Use rögzítette a mentés visszajelzését, a teljes bezárást, a hideg újraindítást és a kaland, esemény, valamint a védett érték visszaellenőrzését. Egy elavult vezérlőindex után friss képernyőn ellenőriztük az állapotot, majd sikeresen újra megkíséreltük a mentést.
- A mentés könyvtárában a szintetikus védett érték nyílt szövege nem volt jelen. A CORE hat helyi forgatókönyve átment, köztük a félbemaradt mentés utáni helyreállítás. Ez utóbbi külön folyamatban futó CORE-próba.
- A helyi UI-futás ZIP SHA-256 értéke: `47af2a7d09e3a0d2de634a6785bae430c8844131eaf54cf82defd723b5cf61a2`. Az elkülönített futás jegyzőkönyve és fájlhash-leltára a helyi `build/imp-004-windows` könyvtárban van. A CI saját reprodukált csomagot és leltárt állít elő.

## A próba megismétlése

1. A rögzített Flutterrel a `platform_probe` könyvtárban futtasd a `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub` és `flutter build windows --release --no-pub` parancsot. A Windowsos buildhez a Microsoft C++ asztali eszközkészlet szükséges.
2. A release könyvtárba kerüljön a `LICENSE.flutter`, majd készíts csomagot és számolj SHA-256 hash-t. A kibontott csomagot külön profillal indítsd a [próba README](../platform_probe/README.md) alapján. A felületen a **Save test data**, teljes bezárás, újraindítás és **Verify saved data** műveleteket ellenőrizd.
3. Az Android CI az emulátoron a tényleges APK-t telepíti, a látható UI-n elvégzi a mentést, leállítja az alkalmazást, majd hideg indítás után ellenőrzi a visszaolvasást. Az APK, hash, kibontott fájllista, Flutter-értesítések és futási napló CI-bizonyítékként maradnak meg.

Az Android build és az emulátoros ellenőrzés külön CI-feladat. Az emulátoros feladat a buildtől kapott APK SHA-256 értékét a telepítés előtt ellenőrzi. Az emulátoros feladat megismételhető ugyanabból a CI-futásból, a sikeres APK-build és Gradle-leltár újrafuttatása nélkül.

## Összetevők és licencelés

| Réteg | Fő összetevők és státusz |
|---|---|
| Dart csomaggráf | A `pubspec.lock` szerint Flutter és sky_engine az SDK-ból, helyi CORE, characters 1.4.1, collection 1.19.1, listen 1.0.1, meta 1.19.0, vector_math 2.4.3 (BSD-3-Clause), material_color_utilities 0.13.0 (Apache-2.0). A feloldott csomagok tényleges licencfájljait ellenőriztük. |
| Flutter sablon és motor | A Windows- és Android-sablonok és a kezdeti ikonok a Flutter 3.50.1 sablonjából származnak. A forrás mellett megtalálható a Flutter-licenc. A motor összetett értesítésállományát a csomag `NOTICES.Z` fájlja tartalmazza. A Windows ZIP-ben ellenőriztük a tömörített állomány olvashatóságát, a feloldott csomagneveket és az ICU-bejegyzést. |
| Windows csomag | Az EXE, a Flutter motor DLL, az AOT alkalmazáskód, az ICU adatfájl, a Flutter manifestek és shaderek, a Flutter-licenc és a notice állomány szerepel a fájlleltárban. A PE-függőségek közt a Windows DLL-ek és a Microsoft VC++ runtime szerepelnek. Ezeket a vizsgált ZIP a célkörnyezetből használja. Ha a későbbi terjesztés külön runtime-ot csomagol, a konkrét újraterjesztési feltételeket át kell nézni. [Microsoft feltételek](https://visualstudio.microsoft.com/license-terms/) |
| Android build és csomag | Android SDK és emulátor a CI-környezetből. A sablon rögzített Android Gradle Plugin 9.3.1, Kotlin 2.4.20 és Gradle 9.5.0 verziót használ. Az APK tényleges natív, Java/Kotlin és asset összetételét az elkészült csomag alapján kell egyeztetni az SDK és az attribúciós adatok forrásaival. [Android SDK feltételek](https://developer.android.com/studio/terms) |
| CI-eszköz | Az APK letöltésére használt GitHub Action forrása rögzített, MIT licencű. [Licenc](https://github.com/actions/download-artifact/blob/9000827ccba6bdab643e8b6fd33ac0654aef8333/LICENSE) |

Az x64 APK-ban a tényleges natív fájlok a `libapp.so` és `libflutter.so`. Az AndroidX-verziójelöléseket és a Gradle runtime gráfot a Google Maven és a Maven Central licencadataival vetettük össze. A gráf több ABI Flutter-összetevőit is felsorolhatja, az APK fájlleltára mutatja, melyik került a vizsgált csomagba. A Flutter notice mellett az AndroidX, Kotlin és egyéb Android runtime összetevők teljes terjesztési attribúcióit külön kell összeállítani a végleges termékcsomaghoz.

A platformpróba fájlleltára a későbbi SBOM és kiadási notice-ellenőrzés bemenete. A termék terjesztési csatornája, aláírása és a végleges csomag auditja külön döntéshez tartozik.
