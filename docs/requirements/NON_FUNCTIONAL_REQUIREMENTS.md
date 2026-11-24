# Nem funkcionális követelmények – v0.2

| ID | Követelmény | Felhasználási eset | Elfogadási kritérium |
|---|---|---|---|
| NFR-001 | Windows támogatás | UC-001, UC-004 | A támogatottnak kijelölt Windows-verziókon végigfut a kaland előkészítése és a szinkronizált állapot betöltése. |
| NFR-002 | Android támogatás | UC-002–UC-004 | A támogatottnak kijelölt Android-verziókon végigfut a kaland betöltése, egy esemény rögzítése és a játékalkalom lezárása. |
| NFR-003 | Szerepjátékrendszer-függetlenség | UC-001, UC-003 | Két eltérő RPG-rendszerhez készült mintakaland előkészíthető és vezethető kötelező rendszerfüggő mezők nélkül. |
| NFR-004 | Minimális adminisztráció játék közben | UC-003 | Aktív játékalkalomban mérföldkő módosítása és improvizált esemény rögzítése végrehajtható a játékalkalom bezárása és külön mentési művelet nélkül. |
| NFR-005 | Adatvesztés megakadályozása | UC-003–UC-005 | Megszakított mentés, alkalmazás-újraindítás és szinkronütközés után az utolsó sikeres mentés elérhető, a függő helyi változások megmaradnak. |
| NFR-006 | Ember által olvasható adatformátum | UC-001, UC-003 | A mentett mintakaland szövegszerkesztőben megnyitható, és a leírása, valamint a rögzített események azonosíthatók. |
| NFR-007 | Biztonságos hitelesítőadat-kezelés | UC-002, UC-006, UC-007 | A szintetikus hitelesítő adat, API-kulcs és webhook URL nem jelenik meg mentett kampányfájlban, verziókövetésben vagy naplóban; a mentett hitelesítő adatokat a platform védett tárolója vagy azzal egyenértékű megoldás védi. |
| NFR-008 | Moduláris architektúra | UC-001, UC-003, UC-006, UC-007 | A függőségek ellenőrzése igazolja, hogy a CORE futtatása nem igényel UI-t vagy konkrét tároló-, összefoglaló- és publikációs szolgáltatót. |
| NFR-009 | Tesztelhető üzleti logika | UC-001, UC-003, UC-004 | Automatizált ellenőrzés futtatható UI és külső hálózat nélkül a mérföldkő állapotváltására és a játékalkalom lezárására. |
| NFR-010 | Saját backend lehetőség szerinti kerülése | UC-002, UC-004, UC-007 | A technológiai vizsgálat bemutatja, futtatható-e a munkafolyamat saját központi szerver nélkül; az esetleges szerverigény indoka döntési dokumentumba kerül. |
| NFR-011 | Kalandadatok alkalmazástól független hozzáférhetősége | UC-001, UC-004 | A mintakaland és eseménytörténete közvetlenül a fájlokból olvasható az alkalmazás telepítése és futtatása nélkül. |
| NFR-012 | Visszafelé kompatibilis vagy migrálható adatformátum | UC-002, UC-004 | Korábbi támogatott sémájú mintakaland megnyílik vagy migrálható; az ellenőrzés összeveti a migrálás előtti és utáni kalandállapotot és eseménytörténetet. |

A felhasználási esetek leírása az [UC-dokumentumban](USE_CASES.md) található. A kritériumokat a tulajdonos jóváhagyta (TASK-003).
