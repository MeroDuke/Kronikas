# Technológiai megvalósíthatóság – TASK-005

Állapot: dokumentációs vizsgálat és ajánlás, tulajdonosi jóváhagyásra vár. Ellenőrzés dátuma: 2026-11-24. Alap: a jóváhagyott [domainmodell](requirements/DOMAIN_MODEL.md) és [nem funkcionális követelmények](requirements/NON_FUNCTIONAL_REQUIREMENTS.md).

## Windows és Android

| Jelölt | Illeszkedés | Költség, kötöttség és nyitott kockázat |
|---|---|---|
| Flutter + Dart | Mindkét célplatform támogatott. Közös felület és külön, tiszta Dart CORE tervezhető. Helyi fájlok és a platform védett tárolója elérhetők platformintegrációval. | A Flutter projekt BSD-3-Clause licencű. A Windows buildhez szükséges Microsoft-eszközök, az Android toolchain, a Dart SDK és az esetleges pluginek feltételei külön ellenőrzendők. A felület Flutterhez, a CORE Dart környezethez kötődik. [Platformok](https://docs.flutter.dev/reference/supported-platforms) · [Licenc és build](https://docs.flutter.dev/resources/faq) |
| .NET MAUI | Mindkét célplatform támogatott. A C# CORE külön könyvtárban tesztelhető. | A MAUI MIT licencű. A Windows App SDK, a kiválasztott IDE és az Android workload külön leltározandó. A MAUI támogatási ciklusa rendszeres frissítést igényel; a C# CORE más .NET felülettel is használható. [Platformok](https://learn.microsoft.com/en-us/dotnet/maui/supported-platforms) · [Támogatási ciklus](https://dotnet.microsoft.com/en-us/platform/support/policy/maui) |
| PWA | Telepíthető böngészőből, a service worker támogatja az offline betöltést. Saját alkalmazásszerver nélkül is kiszolgálható statikus HTTPS tárhelyről. | A tartós offline állapot böngészőkvótáktól, törléstől és perzisztenciaengedélytől függ. A védett helyi titoktárolást és a külső API-k közvetlen böngészős elérését külön igazolni kellene. Tárhely és esetleges framework díja/licence választásfüggő. [Telepítés](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable) · [Helyi tárolás](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria) |

**Ajánlás:** Flutter a felülethez, tiszta Dart a CORE-hoz. A .NET MAUI maradjon tartalék, ha a Flutter platformintegráció vagy a terjesztési feltételek nem igazolhatók. Az MVP cél-OS-verzióit a konkrét támogatott SDK és a teszteszközök alapján kell kiválasztani.

## Adattárolás és szinkron

- **Helyi tárolás:** verziózott, olvasható JSON a strukturált adatokhoz, Markdown az összefoglaló szövegéhez. Az állapot és az eseménytörténet egy mentési műveletként látszódjon. A több fájlra kiterjedő helyi helyreállítási mechanizmust megszakítási próbával kell igazolni.
- **Első távoli adapter:** GitHub REST Git Database API. A kliens az ismert távoli commitra épít egy új commitot az összes szükséges fájlváltozással, majd force nélkül frissíti a branch referenciáját. Versengő frissítéskor a távoli fej és a helyi mentés megmarad. Elveszett válasz esetén a következő írás előtt vissza kell olvasni a távoli állapotot. A jogosultsági, hálózati és kvótahibákat a szinkronütközéstől külön kell kezelni. [Git fák](https://docs.github.com/en/rest/git/trees) · [Commitok](https://docs.github.com/en/rest/git/commits) · [Referenciák](https://docs.github.com/en/rest/git/refs) · [Kvóták](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
- **Hitelesítés saját backend nélkül:** saját használatú próbához egy szintetikus privát repóra korlátozott, lejáró fine-grained PAT a vizsgálandó kiindulópont, az adott repó tartalmának írási jogával és helyi védett tárolással. Későbbi felhasználói belépéshez külön vizsgálandó a GitHub App device flow, a tokenfrissítés és a szervezeti jóváhagyás. A terjesztett kliensbe nem kerül közös alkalmazástitok. [PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) · [GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- **Natív Git alternatíva:** több Git-szolgáltatóhoz adhat hozzáférést, de a Git CLI telepítése és kezelése Androidon külön integráció. A libgit2 lehetővé tesz natív beágyazást, platformonkénti fordítási és csomagolási munkával. GPLv2 linking exception mellett is tételes licencvizsgálat és tulajdonosi kivétel szükséges a projekt politikája szerint. [libgit2 licenc](https://github.com/libgit2/libgit2/blob/v1.9.7/COPYING)

Az alkalmazás a GitHub API-t tárolóadapteren keresztül éri el. A CORE tárolófüggetlen, és a kampányadat Gitben marad, így az adatok másik szolgáltatóhoz vihetők. Az első adapter a GitHub fiók-, hozzáférés- és API-feltételeitől függ. A GitHub Free privát repót kínál, a szervezeti szabályok és a fizetős csomagfunkciók külön ellenőrzendők. [Csomagok](https://docs.github.com/en/get-started/learning-about-github/githubs-plans) · [API- és privátrepó-feltételek](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service)

## Összefoglaló és publikáció

Az alapfolyamat helyben előállított, szerkeszthető összefoglalóval működhet. Az opcionális LLM külön adapter lehet, szolgáltatóválasztás előtt adatkezelési, kereskedelmi és használatalapú díjvizsgálattal. A Discord webhook közvetlenül hívható a natív kliensből. Csak a jóváhagyott szöveg kerül a Discordhoz. A csatorna és a jogosultság a felhasználó Discord-beállításaitól függ; a válasz elvesztése bizonytalan küldésként kezelendő. [Discord webhook](https://docs.discord.com/developers/resources/webhook) · [Fejlesztői feltételek](https://support-dev.discord.com/hc/en-us/articles/8562894815383-Discord-Developer-Terms-of-Service)

## Igazolandó az implementáció előtt

| Próba | Elfogadható eredmény |
|---|---|
| SDK és csomagolás | A kiválasztott stabil Flutter/Dart verzióval telepíthető próbaalkalmazás készül Windowson és Androidon, és mindkettő védett tárolóból visszaolvassa a szintetikus próbaértéket. |
| Helyi mentés | Offline mentés és kényszerített megszakítás után az utolsó sikeres változat visszaolvasható, állapot és eseménytörténet egyezik. |
| Két kliens, egy privát tesztrepó | Egy feltöltés több fájlt egy commitban módosít. Az elavult kliens nem ír felül, és megtartja saját változásait. Elveszett válasz után az állapot lekérdezhető. |
| Függőségek és terjesztés | A kiválasztott pontos verziók, tranzitív licencek, fejlesztőeszköz-feltételek, alkalmazásaláírás és terjesztési díjak szerepelnek a nyilvántartásban. |

A források alapján a saját backend nélküli út megvalósíthatónak látszik az első, saját használatú változathoz. A fenti futtatási próbák még függőben vannak.
