# Funkcionális követelmények – v0.2

[Funkciók nyomon követése](../TRACEABILITY.md)

| ID | Követelmény | Felhasználási eset | Elfogadási kritérium |
|---|---|---|---|
| <a name="fr-001"></a>FR-001<br>[UC-001](../TRACEABILITY.md#uc-001) | Kampány létrehozása és kezelése | UC-001 | A létrehozott kampány mentés és újranyitás után elérhető; a mesélő módosíthatja a nevét. |
| <a name="fr-002"></a>FR-002<br>[UC-001](../TRACEABILITY.md#uc-001) | Kaland létrehozása és kezelése | UC-001 | A kampányhoz létrehozott kaland leírása menthető és újranyitás után szerkeszthető. |
| <a name="fr-003"></a>FR-003<br>[UC-001](../TRACEABILITY.md#uc-001) | One-shot kalandok támogatása | UC-001 | A mesélő kampány kiválasztása nélkül létrehozhat és újranyithat egy one-shotot. |
| <a name="fr-004"></a>FR-004<br>[UC-001](../TRACEABILITY.md#uc-001) · [UC-004](../TRACEABILITY.md#uc-004) | Több játékalkalom egy kalandon belül | UC-001, UC-004 | Egy kalandhoz két egymást követő játékalkalom menthető és külön visszanézhető. |
| <a name="fr-005"></a>FR-005<br>[UC-001](../TRACEABILITY.md#uc-001) | Jelenetek és mérföldkövek definiálása | UC-001 | Egy jelenet, egy mérföldkő és egy tervezett kimenetel mentés után visszaolvasható. |
| <a name="fr-006"></a>FR-006<br>[UC-003](../TRACEABILITY.md#uc-003) | Mérföldkő státusz módosítása | UC-003 | Egy korábban sikertelen mérföldkő állapota később módosítható, a rögzítés sorrendjétől függetlenül. |
| <a name="fr-007"></a>FR-007<br>[UC-003](../TRACEABILITY.md#uc-003) | Narratív kimenetelek rögzítése | UC-003 | A mentett tényleges kimenetel visszaolvasható, miközben a tervezett kimenetel is megmarad. |
| <a name="fr-008"></a>FR-008<br>[UC-001](../TRACEABILITY.md#uc-001) · [UC-003](../TRACEABILITY.md#uc-003) | Mesélői megjegyzések | UC-001, UC-003 | Az előkészítéskor és játék közben felvett mesélői jegyzet mentés után elérhető. |
| <a name="fr-009"></a>FR-009<br>[UC-003](../TRACEABILITY.md#uc-003) | Nem tervezett események | UC-003 | Előre definiált jelenet nélkül felvett esemény visszaolvasható az aktuális játékalkalom történetében. |
| <a name="fr-010"></a>FR-010<br>[UC-003](../TRACEABILITY.md#uc-003) · [UC-004](../TRACEABILITY.md#uc-004) | Aktuális kalandállapot mentése | UC-003, UC-004 | Sikeres mentés után újranyitva az utolsó mentett mérföldkőállapot és eseménytörténet jelenik meg. |
| <a name="fr-011"></a>FR-011<br>[UC-004](../TRACEABILITY.md#uc-004) | Folytatás korábbi állapotból | UC-004 | A játékalkalom lezárása után ugyanahhoz a kalandhoz új alkalom indítható a mentett állapotból. |
| <a name="fr-012"></a>FR-012<br>[UC-002](../TRACEABILITY.md#uc-002) | Git repository konfigurálása | UC-002 | A mesélő érvényes Git-repót állíthat be; a hozzáférési hibát az alkalmazás jelzi. |
| <a name="fr-013"></a>FR-013<br>[UC-002](../TRACEABILITY.md#uc-002) | Repository könyvtár kiválasztása | UC-002 | A kiválasztott könyvtárból jelennek meg a felismert kalandok. |
| <a name="fr-014"></a>FR-014<br>[UC-002](../TRACEABILITY.md#uc-002) | Kalandok beolvasása repositoryból | UC-002 | Egy érvényes kaland megnyitható a beállított tárolóból; a beolvasási hibát az alkalmazás jelzi. |
| <a name="fr-015"></a>FR-015<br>[UC-004](../TRACEABILITY.md#uc-004) · [UC-005](../TRACEABILITY.md#uc-005) | Módosítások visszamentése repositoryba | UC-004, UC-005 | Sikeres feltöltés után a másik eszköz lekérheti a mentett módosítást; sikertelen feltöltéskor a helyi mentés megmarad. |
| <a name="fr-016"></a>FR-016<br>[UC-003](../TRACEABILITY.md#uc-003) · [UC-004](../TRACEABILITY.md#uc-004) · [UC-005](../TRACEABILITY.md#uc-005) | Automatikus lokális mentés | UC-003, UC-004 | A mesélő külön mentési művelete nélkül tartósan mentett változás újraindítás után visszaolvasható; mentési hibánál látható a hiba. |
| <a name="fr-017"></a>FR-017<br>[UC-002](../TRACEABILITY.md#uc-002) · [UC-004](../TRACEABILITY.md#uc-004) · [UC-005](../TRACEABILITY.md#uc-005) | Platformok közötti sync | UC-002, UC-004, UC-005 | Az Androidon mentett és sikeresen szinkronizált állapot Windowson betölthető; a mesélő kézi szinkront is indíthat. |
| <a name="fr-018"></a>FR-018<br>[UC-002](../TRACEABILITY.md#uc-002) · [UC-004](../TRACEABILITY.md#uc-004) · [UC-005](../TRACEABILITY.md#uc-005) | Offline működés | UC-002, UC-004, UC-005 | A korábban letöltött kaland hálózat nélkül megnyitható és módosítható; a helyi változás megmarad, a függő szinkron látható. |
| <a name="fr-019"></a>FR-019<br>[UC-005](../TRACEABILITY.md#uc-005) | Sync konfliktus felismerése | UC-005 | Két eszköz eltérő módosításakor az elavult példány feltöltése ütközést jelez; mindkét változat megmarad. |
| <a name="fr-020"></a>FR-020<br>[UC-006](../TRACEABILITY.md#uc-006) | Narratív összefoglaló generálása | UC-006 | Lezárt alkalomból készíthető összefoglaló LLM nélkül is, a rögzített publikálható események alapján. |
| <a name="fr-021"></a>FR-021<br>[UC-006](../TRACEABILITY.md#uc-006) | Összefoglaló manuális szerkesztése | UC-006 | A mesélő átírhatja a generált szöveget, és az átírt változat menthető. |
| <a name="fr-022"></a>FR-022<br>[UC-006](../TRACEABILITY.md#uc-006) · [UC-007](../TRACEABILITY.md#uc-007) | Összefoglaló jóváhagyása | UC-006, UC-007 | Csak az a változat küldhető, amelyet a mesélő jóváhagyott; utólag szerkesztett változat új jóváhagyást igényel. |
| <a name="fr-023"></a>FR-023<br>[UC-006](../TRACEABILITY.md#uc-006) · [UC-007](../TRACEABILITY.md#uc-007) | Összefoglaló mentése | UC-006, UC-007 | A mentett összefoglaló szövege újranyitás után visszaolvasható. |
| <a name="fr-024"></a>FR-024<br>[UC-007](../TRACEABILITY.md#uc-007) | Discord-csatorna konfigurálása | UC-007 | A mesélő beállíthatja a Discord-célt; a célhoz tartozó titok kezelésére az NFR-007 vonatkozik. |
| <a name="fr-025"></a>FR-025<br>[UC-007](../TRACEABILITY.md#uc-007) | Discord publikáció | UC-007 | Sikeres küldéskor a jóváhagyott szöveg megjelenik a beállított csatornán; sikertelen vagy bizonytalan küldéskor látható az eltérő állapot, és a mentett szöveg megmarad. |
| <a name="fr-026"></a>FR-026<br>[UC-006](../TRACEABILITY.md#uc-006) | Mesélői és publikálható információk elkülönítése | UC-006 | Egy publikálható esemény bekerülhet az összefoglaló bemenetébe; egy titkos esemény és egy kihagyott jelenet kimarad, az opcionális LLM bemenetéből is. |

A felhasználási esetek leírása az [UC-dokumentumban](USE_CASES.md) található. A kritériumokat a tulajdonos jóváhagyta (TASK-003).
