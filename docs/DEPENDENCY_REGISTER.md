# Függőségi nyilvántartás

Jelenleg nincs kiválasztott vagy bevezetett termékfüggőség. Az alábbi táblázat a 2026-11-24-i előszűrés jelöltjeit rögzíti. A hivatkozott tag forrásminta, a bevezetendő verziót külön kell rögzíteni.

| Kategória | Név/verzió | Licenc | Kereskedelmi jogok és kötelezettségek | Forrás | Státusz |
|---|---|---|---|---|---|
| Framework | Flutter 3.38.9 licencminta | BSD-3-Clause | Licencszöveg és értesítések megőrzése; engine és tranzitív tételek külön ellenőrzendők | [Licenc](https://github.com/flutter/flutter/blob/3.38.9/LICENSE) | Elsődleges jelölt |
| SDK | Dart, a Flutterrel szállított verzió függőben | BSD-3-Clause előszűrés | Pontos SDK-tag és átvett összetevők külön ellenőrzendők | [Licenc](https://github.com/dart-lang/sdk/blob/main/LICENSE) | Jelölt |
| Framework | .NET MAUI 11.0.10 licencminta | MIT | Licencszöveg megőrzése; workload és Windows App SDK külön tétel | [Licenc](https://github.com/dotnet/maui/blob/11.0.10/LICENSE.txt) | Tartalék |
| Natív runtime | Flutter engine 3.38.9 licencminta | BSD-3-Clause saját kód és külön harmadikfeles feltételek | A tényleges Windows/Android motorcsomag és notice-ok egyeztetése függőben | [Engine](https://github.com/flutter/flutter/blob/3.38.9/engine/src/flutter/LICENSE) | Előszűrt |
| Windows build és runtime | Visual Studio/MSVC kiadás és VC++ runtime, verzió függőben | Eszköz- és újraterjesztési feltételek | Buildhasználat és csomagolt runtime külön ellenőrzendő | [Windows csomagolás](https://docs.flutter.dev/deployment/windows) | Függőben |
| Android build | SDK, JDK és Gradle, verzió függőben | Összetevőnként ellenőrizendő | SDK-feltételek és APK/AAB natív és Maven-leltár | [SDK](https://developer.android.com/studio/terms) | Függőben |
| UI és védett tároló | Natív pluginok, verzió függőben | Összetevőnként ellenőrizendő | Dart és natív tranzitív függőségek, notice-ok | [Átvilágítás](LICENSING_FEASIBILITY.md) | Függőben |
| Tartalom | Ikon, logó, font, egyedi eszköz | Eredet és jogok tételenként | Verzió, forrás, attribúció, módosítás és terjesztési jog | [Átvilágítás](LICENSING_FEASIBILITY.md) | Függőben |
| Git integráció | GitHub REST Git Database API | Szolgáltatási feltételek | Privát repó csomag- és szervezeti szabályai, API-kvóták, felhasználói adatok | [Feltételek](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service) | Elsődleges jelölt |
| Git integráció | libgit2 v1.9.7 | GPLv2 linking exception; összetevők külön | Terjesztési mód és licenckivétel vizsgálata, tulajdonosi jóváhagyás | [Licenc](https://github.com/libgit2/libgit2/blob/v1.9.7/COPYING) | Alternatíva |
| Publikáció | Discord webhook API | Szolgáltatási feltételek | Csatornajogosultság, adatkezelés és felhasználási feltételek | [Feltételek](https://support-dev.discord.com/hc/en-us/articles/8562894815383-Discord-Developer-Terms-of-Service) | Jelölt |
| Teszt framework | TBD | TBD | TBD | TBD | Függőben |
| LLM integráció | TBD | TBD | TBD | TBD | Függőben |

Rögzítendő továbbá: közvetlen/tranzitív jelleg, ellenőrzés dátuma, terjesztési feltételek, díjak, attribúció, kockázat, jóváhagyás. Lásd LICENSING_POLICY.md.
