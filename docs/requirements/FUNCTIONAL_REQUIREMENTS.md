# Funkcionális követelmények – v0.2

| ID | Követelmény | Felhasználási eset | Elfogadási kritérium |
|---|---|---|---|
| FR-001 | Kampány létrehozása és kezelése | UC-001 | A létrehozott kampány mentés és újranyitás után elérhető; a mesélő módosíthatja a nevét. |
| FR-002 | Kaland létrehozása és kezelése | UC-001 | A kampányhoz létrehozott kaland leírása menthető és újranyitás után szerkeszthető. |
| FR-003 | One-shot kalandok támogatása | UC-001 | A mesélő kampány kiválasztása nélkül létrehozhat és újranyithat egy one-shotot. |
| FR-004 | Több játékalkalom egy kalandon belül | UC-001, UC-004 | Egy kalandhoz két egymást követő játékalkalom menthető és külön visszanézhető. |
| FR-005 | Jelenetek és mérföldkövek definiálása | UC-001 | Egy jelenet, egy mérföldkő és egy tervezett kimenetel mentés után visszaolvasható. |
| FR-006 | Mérföldkő státusz módosítása | UC-003 | Egy korábban sikertelen mérföldkő állapota később módosítható, a rögzítés sorrendjétől függetlenül. |
| FR-007 | Narratív kimenetelek rögzítése | UC-003 | A mentett tényleges kimenetel visszaolvasható, miközben a tervezett kimenetel is megmarad. |
| FR-008 | Mesélői megjegyzések | UC-001, UC-003 | Az előkészítéskor és játék közben felvett mesélői jegyzet mentés után elérhető. |
| FR-009 | Nem tervezett események | UC-003 | Előre definiált jelenet nélkül felvett esemény visszaolvasható az aktuális játékalkalom történetében. |
| FR-010 | Aktuális kalandállapot mentése | UC-003, UC-004 | Sikeres mentés után újranyitva az utolsó mentett mérföldkőállapot és eseménytörténet jelenik meg. |
| FR-011 | Folytatás korábbi állapotból | UC-004 | A játékalkalom lezárása után ugyanahhoz a kalandhoz új alkalom indítható a mentett állapotból. |
| FR-012 | Git repository konfigurálása | UC-002 | A mesélő érvényes Git-repót állíthat be; a hozzáférési hibát az alkalmazás jelzi. |
| FR-013 | Repository könyvtár kiválasztása | UC-002 | A kiválasztott könyvtárból jelennek meg a felismert kalandok. |
| FR-014 | Kalandok beolvasása repositoryból | UC-002 | Egy érvényes kaland megnyitható a beállított tárolóból; a beolvasási hibát az alkalmazás jelzi. |
| FR-015 | Módosítások visszamentése repositoryba | UC-004, UC-005 | Sikeres feltöltés után a másik eszköz lekérheti a mentett módosítást; sikertelen feltöltéskor a helyi mentés megmarad. |
| FR-016 | Automatikus lokális mentés | UC-003, UC-004 | A mesélő külön mentési művelete nélkül tartósan mentett változás újraindítás után visszaolvasható; mentési hibánál látható a hiba. |
| FR-017 | Platformok közötti sync | UC-002, UC-004, UC-005 | Az Androidon mentett és sikeresen szinkronizált állapot Windowson betölthető; a mesélő kézi szinkront is indíthat. |
| FR-018 | Offline működés | UC-002, UC-004, UC-005 | A korábban letöltött kaland hálózat nélkül megnyitható és módosítható; a helyi változás megmarad, a függő szinkron látható. |
| FR-019 | Sync konfliktus felismerése | UC-005 | Két eszköz eltérő módosításakor az elavult példány feltöltése ütközést jelez; mindkét változat megmarad. |
| FR-020 | Narratív összefoglaló generálása | UC-006 | Lezárt alkalomból készíthető összefoglaló LLM nélkül is, a rögzített publikálható események alapján. |
| FR-021 | Összefoglaló manuális szerkesztése | UC-006 | A mesélő átírhatja a generált szöveget, és az átírt változat menthető. |
| FR-022 | Összefoglaló jóváhagyása | UC-006, UC-007 | Csak az a változat küldhető, amelyet a mesélő jóváhagyott; utólag szerkesztett változat új jóváhagyást igényel. |
| FR-023 | Összefoglaló mentése | UC-006, UC-007 | A mentett összefoglaló szövege újranyitás után visszaolvasható. |
| FR-024 | Discord-csatorna konfigurálása | UC-007 | A mesélő beállíthatja a Discord-célt; a célhoz tartozó titok kezelésére az NFR-007 vonatkozik. |
| FR-025 | Discord publikáció | UC-007 | Sikeres küldéskor a jóváhagyott szöveg megjelenik a beállított csatornán; sikertelen vagy bizonytalan küldéskor látható az eltérő állapot, és a mentett szöveg megmarad. |
| FR-026 | Mesélői és publikálható információk elkülönítése | UC-006 | Egy publikálható esemény bekerülhet az összefoglaló bemenetébe; egy titkos esemény és egy kihagyott jelenet kimarad, az opcionális LLM bemenetéből is. |

A felhasználási esetek leírása az [UC-dokumentumban](USE_CASES.md) található. A kritériumokat a tulajdonos jóváhagyta (TASK-003).
