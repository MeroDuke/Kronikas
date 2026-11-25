# ADR-0002 – Helyi mesék és opcionális felhőtárolás

2026-11-25 · Jóváhagyott termékirány

A Krónikás induláskor a helyi meséket nyitja meg. A mesélő felhőtárhelyet külön kapcsolhat hozzá. Az első cél a saját Windows és Android eszközök közötti folytatás, saját kiszolgáló üzemeltetése nélkül. Első szolgáltatójelölt a Google Drive. A GitHub-adapter és a vele készült próbák a korábbi technológiai vizsgálat részei.

Minden mese saját fájlban tárolható, stabil azonosítóval. Induláskor a kliens először a helyi listát mutatja. Bekapcsolt felhőkapcsolat esetén lekéri a távoli verzióadatokat, és csak a hiányzó vagy megváltozott mesék tartalmát tölti le. Jóváhagyott módosításkor helyben ment, majd kezdeményezi az érintett fájl feltöltését. A függő mentés újraindítás után is megmarad. Ütközésnél egyik példány sem íródhat felül észrevétlenül. Távoli hiány önmagában nem törli a helyi mesét.

Az első próba szintetikus tárolóval is futtatható. Az élő Drive-integrációhoz közös Google Cloud projekt, Drive API, Windows és Android OAuth-konfiguráció szükséges. A végleges felhőadapternek igazolnia kell a két eszköz közötti fájlfelderítést, a szűk jogosultságot és a párhuzamos mentés védelmét. A játékosmegosztás külön döntés.

[UC-002 és UC-005](../TRACEABILITY.md) · [IMP-009](../IMPLEMENTATION_PLAN.md#imp-009) · [TST-012](../TEST_EXECUTION.md#tst-012)
