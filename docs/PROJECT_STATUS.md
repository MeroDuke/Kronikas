# Projektállapot – 2026-11-24

- Termék és kódnév: Krónikás; brand: Akihabarai Könyvespolc.
- Fázis: Phase 0 – tervezés; koncepció v0.1.
- Publikus fejlesztői repository: MeroDuke/Kronikas. A kampányadatok külön tárolandók.
- A Flutter/Dart és a GitHub REST irány jóváhagyva. A pontos SDK-verzió és a platformpróbák függőben vannak. Az implementáció még tervezés alatt áll.
- A magyar fejlesztési dokumentáció a hiteles alap; angol publikus dokumentáció származtatott.
- Saját használat az első cél, későbbi nyilvános termék lehetőségével.

## Következő lépés
A felhasználási esetek, követelmények és a [domainmodell](requirements/DOMAIN_MODEL.md) jóváhagyva (TASK-002–004). A [TASK-005 technológiai iránya](TECHNOLOGY_FEASIBILITY.md) jóváhagyva. A [TASK-006 architektúra- és tesztstratégia](ARCHITECTURE_AND_TEST_STRATEGY.md) tervezete a [tesztfuttatási útmutatóval és a Windowsos Computer Use E2E menettel](TEST_EXECUTION.md) együtt jóváhagyásra vár. Utána a TASK-007 implementációs terv következik. A [licencelési átvilágítás](LICENSING_FEASIBILITY.md) rögzíti az Akihabarai Score auditjának tanulságait és a Windows/Android próbacsomagok ellenőrzési feltételeit. A csomagleltár, a pontos SDK-verzió és a tényleges terjesztési csatorna feltételei függőben vannak.

Dokumentációs ellenőrzés: 26 FR és 12 NFR rendelkezik elfogadási kritériummal és hivatkozott felhasználási esettel. A domainmodell mind a hét felhasználási esetre hivatkozik, hat egyedi üzleti szabályazonosítót tartalmaz, és az érintett Markdown-fájlok relatív dokumentumhivatkozásai feloldhatók. A TASK-005 változásainak 23 relatív dokumentumhivatkozása feloldható; a három taghez kötött licencforrást ellenőriztük. A licencelési kiegészítés 22 relatív dokumentumhivatkozása és a függőségi táblázat szerkezete ellenőrzött. A TASK-006 ellenőrzése 11 egyedi tesztazonosítót, mind a 38 követelmény hivatkozását és az érintett dokumentumok relatív linkjeit igazolta. Mind a 11 ellenőrzéshez tartozik futtatási eljárás az útmutatóban, a dokumentumlinkek ellenőrzöttek. Platformbuild, csomagaudit és Windowsos E2E próba még nem futott.

## Tájékozódás
[Backlog](BACKLOG.md) · [Roadmap](ROADMAP.md) · [Nyitott kérdések](OPEN_QUESTIONS.md) · [Koncepció](concept/PROJECT_CONCEPT.md) · [Döntések](decisions/ADR-0001-project-foundations.md)

## Jóváhagyott kiegészítő célok
A projekt szakmai portfólióként is szolgál; a jövőbeli kereskedelmi hasznosítás szabadsága megőrzendő. A technológiai vizsgálat kötelező része a licenc- és szolgáltatói feltételek ellenőrzése. Saját licenc továbbra sincs kiválasztva.

[AI fejlesztési munkafolyamat](AI_DEVELOPMENT_WORKFLOW.md) · [Licencpolitika](LICENSING_POLICY.md) · [Függőségi nyilvántartás](DEPENDENCY_REGISTER.md)
