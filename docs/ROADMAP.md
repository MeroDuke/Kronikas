# Krónikás roadmap

[Funkciók nyomon követése](TRACEABILITY.md)

**Jelenleg** a helyi Dart CORE és a szintetikus platformpróbák a `main` ágon vannak. A GitHub-szinkron alapjai működnek, a Windows és Android meseválasztó előnézete kipróbálható. A teljes mesélői munkafolyamat még nyitott. [Projektállapot és futási előzmények](PROJECT_STATUS.md)

**Következő mérföldkő** a két eszköz eltérő módosításainak mesélői feloldása az IMP-005-ben. A jóváhagyott viselkedés szerint a független módosítások automatikusan egyesülnek, a tényleges ütközéseket a mesélő oldja fel. A CORE egyesítését kétklienses teszt igazolja. A kézi feloldást, az elavult döntés elutasítását és az eredeti változatok visszaállítását CORE-teszt igazolja. A következő fejlesztési lépés a mesélői felület. [Nyitott kérdések](OPEN_QUESTIONS.md) · [TST-004 futtatási menete](TEST_EXECUTION.md)

## Mérföldkövek

| Fázis és csomag | Állapot | Igazolt eredmény vagy lezárási feltétel |
| --- | --- | --- |
| 0 · Projekt- és tervezési alapok (TASK-001–007) | Jóváhagyva | Követelmények, domainmodell, technológiai irány, architektúra, tesztstratégia és ütemezés rögzítve. A technológiai próbák állapota lent követhető. [Backlog](BACKLOG.md) |
| 1 · Helyi CORE (IMP-001–003) | Kész | Rögzített SDK, szintetikus kaland és eseménytörténet, verziózott mentés és megszakítás utáni helyreállás. A merge utáni CORE CI zöld. [CORE útmutató](CORE_DEVELOPMENT.md) · [CI](https://github.com/MeroDuke/Kronikas/actions/runs/45449648322) |
| 1–2 · Platformpróbák (IMP-004) | Részben igazolt | Windows és Android mentés és visszaolvasás igazolva. A támogatott buildcélok Windows x64 és Android ARM64. Az ARM64 Android felületi regressziót a GitHub Actions futtatja. A csomagolt megszakítási próba, a fizikai célmátrix és a teljes kiadási licencleltár nyitott. [Platformpróba](PLATFORM_PROBE.md) · [Android E2E](https://github.com/MeroDuke/Kronikas/actions/runs/45446620447) |
| 2 · GitHub-szinkron (IMP-005) | Részben igazolt | A többfájlos írás, az elveszett válasz kezelése és a két kliens módosításainak megőrzése igazolva. A jóváhagyott konfliktusfeloldás megvalósítása és az élő tokenes felületi próba hátravan. [Projektállapot](PROJECT_STATUS.md) |
| 3 · Windows és Android mesélői felület (IMP-006) | Előnézet | A szintetikus repó- és meseválasztás, valamint az Android játékalkalom-előzmény igazolva. Lezáráshoz kell a kalandelőkészítés, az aktív alkalom és a mentés végigjárása, majd az Androidon szinkronizált módosítás visszaolvasása Windowson. [Tesztfuttatási útmutató](TEST_EXECUTION.md) |
| 4 · Narratív összefoglaló (IMP-007) | Tervezett | Helyi szerkesztés, mentés és revízióhoz kötött jóváhagyás. A publikálható és mesélői adatok kezelését a TST-006 igazolja. Az opcionális LLM külön döntést igényel. [Implementációs terv](IMPLEMENTATION_PLAN.md) |
| 5 · Discord-publikáció (IMP-008) | Tervezett | Az IMP-007 után igazolandó a küldés, a hibajelzés és az ismétlés viselkedése. Az élő próba elkülönített csatornán fut. [Implementációs terv](IMPLEMENTATION_PLAN.md) |
| Első terjeszthető csomag | Döntésre vár | Célverzió, üzleti modell és terjesztési csatorna tulajdonosi döntés. A konkrét csomaghoz kell az SBOM, a licencek és notice-ok ellenőrzése. [Licencelési átvilágítás](LICENSING_FEASIBILITY.md) |

## Karbantartás

Mérföldkő zárásakor frissítsd az érintett sort, és add meg a PR-t, commitot vagy futási bizonyítékot. A részletes eredményt a projektállapotban, a döntésre váró tételeket a nyitott kérdéseknél vezesd. Ha a következő cél változik, frissítsd a fenti rövid összefoglalót is. Kiadási verzió és határidő tulajdonosi döntés után kerül ide.

Az Aldrod gyakorlatából az aktuális munka és az ellenőrzési bizonyíték összekapcsolását, az Akihabarai Score-ból a tömör mérföldkő-áttekintést és a részletes tervek hivatkozását vettük át. [Aldrod roadmap](https://github.com/MeroDuke/Aldrod/blob/HEAD/docs/project/ROADMAP.md) · [Akihabarai Score roadmap](https://github.com/MeroDuke/Akihabarai-Score/blob/HEAD/ROADMAP.md)
