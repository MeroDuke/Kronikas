# Felhasználási esetek – v0.1 tervezet

Állapot: tulajdonosi jóváhagyásra vár (TASK-002).

Elsődleges szereplő: mesélő (GM). A forgatókönyvek a felhasználó számára megfigyelhető eredményt írják le. A tárolási séma, szinkronizációs mechanizmus és szolgáltatók kiválasztása későbbi tervezési feladat.

| ID | Felhasználási eset | Kapcsolódó követelmények |
|---|---|---|
| UC-001 | Kampány és kaland előkészítése | FR-001–005, FR-008 |
| UC-002 | Kalandtár csatlakoztatása és kaland megnyitása | FR-012–014, FR-017–018 |
| UC-003 | Játékalkalom vezetése | FR-006–010, FR-016 |
| UC-004 | Játékalkalom lezárása és a kaland folytatása | FR-004, FR-010–011, FR-015–018 |
| UC-005 | Szinkronütközés kezelése | FR-015–019 |
| UC-006 | Narratív összefoglaló elkészítése | FR-020–023, FR-026 |
| UC-007 | Jóváhagyott összefoglaló közzététele | FR-022–025 |

## UC-001 – Kampány és kaland előkészítése

A mesélő Windowson létrehoz egy kampányt és benne egy kalandot, vagy önálló one-shotot készít. Felveszi a leírást, jeleneteket, mérföldköveket, lehetséges kimeneteleket és mesélői jegyzeteket. Mentés után újra megnyithatja és szerkesztheti a tervet. A tervezett kimenetelek a játék során külön rögzített tényleges kimenetellel együtt is visszakereshetők.

## UC-002 – Kalandtár csatlakoztatása és kaland megnyitása

A mesélő beállítja a Git-repót és a kalandok könyvtárát, szükség esetén hitelesít, majd a felismert kalandok közül kiválaszt egyet. Elérhető kapcsolatnál az alkalmazás lekéri az aktuális állapotot. Kapcsolat nélkül a korábban letöltött kaland megnyitható, és az offline állapot látszik. Ha a kiválasztott kaland még nincs letöltve, a mesélő egyértelmű jelzést kap.

## UC-003 – Játékalkalom vezetése

A mesélő Androidon megnyitja a kalandot és elindít egy játékalkalmat. Játék közben sorrendtől függetlenül frissíti a mérföldkövek állapotát, rögzíti a tényleges kimeneteleket, improvizált eseményeket és megjegyzéseket. Egy korábban sikertelen mérföldkőhöz visszatérhet. Az alkalmazás automatikusan helyben menti a változásokat. Újranyitáskor a mentett állapot és eseménytörténet elérhető. Sikertelen mentéskor a mesélő visszajelzést kap.

## UC-004 – Játékalkalom lezárása és a kaland folytatása

A mesélő lezárja az aznapi játékalkalmat, miközben a kaland folytatható marad. A helyben elmentett változások szinkronizálhatók automatikusan vagy a mesélő kérésére. Sikeres szinkron után Windowson megnyitja a friss állapotot, megnézi az előző alkalom eseményeit és új alkalmat kezd. Kapcsolat hiányában a mentés helyben megmarad, és látható, hogy a szinkron függőben van.

## UC-005 – Szinkronütközés kezelése

A mesélő ugyanabból a letöltött állapotból módosít egy kalandot Androidon és Windowson. A Windows előbb szinkronizál. Amikor az Android megpróbálja feltölteni a saját módosításait, az alkalmazás jelzi az ütközést és megőrzi a helyi változásokat. A távoli állapot változatlanul elérhető. Az MVP-ben a mesélő által használható feloldási út még döntésre vár.

## UC-006 – Narratív összefoglaló elkészítése

A mesélő lezárt játékalkalomhoz összefoglalót készít. Például a csapat átkelt a folyón, a tervezett fogadói jelenet elmaradt, egy titkos megfigyelő pedig követte őket. A publikálható bemenetben az átkelés szerepel. A fogadói jelenet és a titkos megfigyelő kimarad. Opcionális LLM esetén ugyanez a bemeneti korlát érvényes. A mesélő ellenőrzi a tényszerűséget, szerkeszti, menti, majd jóváhagyja a változatot.

## UC-007 – Jóváhagyott összefoglaló közzététele

A mesélő beállítja a Discord-célcsatornát, kiválasztja a jóváhagyott összefoglalót és elindítja a küldést. Az alkalmazás jelzi a publikáció eredményét. Sikertelen vagy bizonytalan kimenetel esetén a mentett összefoglaló elérhető marad, és az állapot jelzi, hogy a közzététel ellenőrzést igényel. Az újraküldés és a duplikáció kezelése külön döntési pont.
