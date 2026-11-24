# Krónikás – fejlesztési instrukciók

A repository a projekt hiteles információforrása. A ChatGPT WebUI és a Codex egymás chatelőzményei nélkül is folytathassa a munkát.

## Munkakezdés
- Ellenőrizd a legfrissebb main állapotát és a helyi módosításokat; ne írd felül más munkáját.
- Olvasd el ezt a fájlt, a docs/PROJECT_STATUS.md, BACKLOG.md, OPEN_QUESTIONS.md, ROADMAP.md és a feladathoz tartozó követelményeket, döntéseket.
- Csak jóváhagyott feladatot implementálj. A javaslat nem elfogadott döntés. Ellentmondás esetén kérj tisztázást.

## Munkavégzés
- Dokumentáció először; a követelmények, döntések, feladatok és tesztek azonosítói legyenek stabilak és hivatkozhatók.
- Magyar az elsődleges fejlesztési dokumentáció; az angol publikus dokumentáció ebből származik. Angol forráskód, azonosítók, kódkommentek, fájlnevek és commitüzenetek.
- CORE legyen UI- és szolgáltatófüggetlen, tesztelhető. Kerüld a túltervezést.
- Valódi kampányok, játékosadatok, titkok, tokenek, API-kulcsok és webhook URL-ek nem kerülhetnek ide. Csak szintetikus vagy publikálásra jóváhagyott tesztadat.
- Jelentős követelmény- és architektúraváltozás csak tulajdonosi jóváhagyással.
- Fontos változtatásokhoz külön branch és PR; ne merge-elj jóváhagyás nélkül. A tulajdonos által kifejezetten engedélyezett közvetlen módosítás kivétel.

## Munkazárás
- Frissítsd az érintett dokumentumokat, backlogot, projektállapotot és nyitott kérdéseket.
- Rögzítsd a tényleges teszteredményeket, hibákat, blokkoló tényezőket és következő lépést. Nem futtatott tesztet ne jelölj sikeresnek.
- Ellenőrizd a diffet és a titkok hiányát; commitolj és publikálj a jóváhagyott munkafolyamat szerint.
- A chatben született döntés csak repositoryba rögzítve válik tartós projektinformációvá.

## Portfólió és licencelés
- Kövesd a docs/AI_DEVELOPMENT_WORKFLOW.md és docs/LICENSING_POLICY.md előírásait.
- Új függőség vagy verzióváltás előtt ellenőrizd a pontos licencet és feltételeket, dokumentáld a docs/DEPENDENCY_REGISTER.md fájlban; kivételhez tulajdonosi jóváhagyás kell.
- Őrizd meg az AI-támogatott fejlesztés ellenőrizhető szakmai bizonyítékait; ne állíts nem igazolt eredményt.
