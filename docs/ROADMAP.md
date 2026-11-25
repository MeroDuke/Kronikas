# Krónikás roadmap

A GitHub-tárolási adapter és belépési demó kikerült az aktív kódból. A korábbi próba a [PR #11-ben](https://github.com/MeroDuke/Kronikas/pull/11) visszakereshető. A szolgáltatótól független konfliktuskezelés, a helyi revíziók és a szintetikus platformtesztek megmaradtak.

**Aktuális tárolási irány.** A helyi Mesék felület alapértelmezett. Az opcionális felhőszinkron első jelöltje a Google Drive. A korábbi GitHub-tárolási terv és vizsgálatok történeti állapotot írnak le. [ADR-0002](decisions/ADR-0002-local-stories-and-cloud-storage.md) · [IMP-009](IMPLEMENTATION_PLAN.md#imp-009)

[Funkciók nyomon követése](TRACEABILITY.md)

**Jelenleg** a GitHub-meseválasztó és a szintetikus konfliktusfeloldás a `main` ágon van. A csomagolt Windows x64 és Android ARM64 próbákat a GitHub Actions futtatja. [Projektállapot](PROJECT_STATUS.md) · [Platform-CI](https://github.com/MeroDuke/Kronikas/actions/runs/45563300860)

**Következő mérföldkő** az [IMP-009](IMPLEMENTATION_PLAN.md#imp-009) tárolási próbája. Az IMP-006 helyi mesélői útjának eddigi eredményei alább követhetők. Az önálló kaland már létrehozható és újranyitható. A helyi játékalkalom indítása, a mérföldkő kimenetelének rögzítése és az alkalom lezárása widgetteszttel igazolt. Az aktív alkalomhoz improvizált esemény és mesélői jegyzet adható. A következő nyitott helyi feladat az előkészítő nézet bővítése kampányokkal és jelenetekkel. [UC-001](TRACEABILITY.md#uc-001) · [IMP-006](IMPLEMENTATION_PLAN.md#imp-006)

## Mérföldkövek

| Fázis és csomag | Állapot | Igazolt eredmény vagy lezárási feltétel |
| --- | --- | --- |
| 0 · Projekt- és tervezési alapok (TASK-001–007) | Jóváhagyva | Követelmények, domainmodell, technológiai irány, architektúra, tesztstratégia és ütemezés rögzítve. A technológiai próbák állapota lent követhető. [Backlog](BACKLOG.md) |
| 1 · Helyi CORE (IMP-001–003) | Kész | Rögzített SDK, szintetikus kaland és eseménytörténet, verziózott mentés és megszakítás utáni helyreállás. A merge utáni CORE CI zöld. [CORE útmutató](CORE_DEVELOPMENT.md) · [CI](https://github.com/MeroDuke/Kronikas/actions/runs/45449648322) |
| 1–2 · Platformpróbák (IMP-004) | Részben igazolt | Windows és Android mentés és visszaolvasás igazolva. A támogatott buildcélok Windows x64 és Android ARM64. A csomagolt Windows x64 és ARM64 Android felületi regressziót a GitHub Actions futtatja. A csomagolt megszakítási próba, a fizikai célmátrix és a teljes kiadási licencleltár nyitott. [Platformpróba](PLATFORM_PROBE.md) · [Android E2E](https://github.com/MeroDuke/Kronikas/actions/runs/45446620447) |
| 2 · GitHub-szinkron (IMP-005) | Részben igazolt | A többfájlos írás, az elveszett válasz kezelése és a két kliens módosításainak megőrzése igazolva. A konfliktusfeloldó felület szintetikus Windows- és Android-próbája átment. A böngészős belépés és a repóválasztó szintetikus tesztje elkészült. Az élő próbához device flow-t engedélyező GitHub App kell. [Projektállapot](PROJECT_STATUS.md) |
| 3 · Windows és Android mesélői felület (IMP-006) | Előnézet | A szintetikus repó- és meseválasztás, valamint az Android játékalkalom-előzmény igazolva. A helyi önálló kaland létrehozását és újranyitását Flutter-widgetteszt ellenőrzi. Lezáráshoz kell a kalandelőkészítés, az aktív alkalom és a mentés végigjárása, majd az Androidon szinkronizált módosítás visszaolvasása Windowson. [Tesztfuttatási útmutató](TEST_EXECUTION.md) |
| 4 · Narratív összefoglaló (IMP-007) | Tervezett | Helyi szerkesztés, mentés és revízióhoz kötött jóváhagyás. A publikálható és mesélői adatok kezelését a TST-006 igazolja. Az opcionális LLM külön döntést igényel. [Implementációs terv](IMPLEMENTATION_PLAN.md) |
| 5 · Discord-publikáció (IMP-008) | Tervezett | Az IMP-007 után igazolandó a küldés, a hibajelzés és az ismétlés viselkedése. Az élő próba elkülönített csatornán fut. [Implementációs terv](IMPLEMENTATION_PLAN.md) |
| Első terjeszthető csomag | Döntésre vár | Célverzió, üzleti modell és terjesztési csatorna tulajdonosi döntés. A konkrét csomaghoz kell az SBOM, a licencek és notice-ok ellenőrzése. [Licencelési átvilágítás](LICENSING_FEASIBILITY.md) |

## Karbantartás

Mérföldkő zárásakor frissítsd az érintett sort, és add meg a PR-t, commitot vagy futási bizonyítékot. A részletes eredményt a projektállapotban, a döntésre váró tételeket a nyitott kérdéseknél vezesd. Ha a következő cél változik, frissítsd a fenti rövid összefoglalót is. Kiadási verzió és határidő tulajdonosi döntés után kerül ide.

Az Aldrod gyakorlatából az aktuális munka és az ellenőrzési bizonyíték összekapcsolását, az Akihabarai Score-ból a tömör mérföldkő-áttekintést és a részletes tervek hivatkozását vettük át. [Aldrod roadmap](https://github.com/MeroDuke/Aldrod/blob/HEAD/docs/project/ROADMAP.md) · [Akihabarai Score roadmap](https://github.com/MeroDuke/Akihabarai-Score/blob/HEAD/ROADMAP.md)
